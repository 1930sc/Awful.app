//  AwfulHTTPClient.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulHTTPClient.h"
#import <AFNetworking/AFNetworking.h>
#import "AwfulAppDelegate.h"
#import "AwfulErrorDomain.h"
#import "AwfulFormScraper.h"
#import "AwfulForumHierarchyScraper.h"
#import "AwfulHTMLRequestSerializer.h"
#import "AwfulHTMLResponseSerializer.h"
#import "AwfulLepersColonyPageScraper.h"
#import "AwfulMessageFolderScraper.h"
#import "AwfulModels.h"
#import "AwfulPostsPageScraper.h"
#import "AwfulPrivateMessageScraper.h"
#import "AwfulProfileScraper.h"
#import "AwfulScanner.h"
#import "AwfulSettings.h"
#import "AwfulThreadListScraper.h"
#import "AwfulThreadTag.h"
#import "AwfulUIKitAndFoundationCategories.h"

@interface AwfulHTTPRequestOperationManager : AFHTTPRequestOperationManager

@end

@implementation AwfulHTTPClient
{
    AwfulHTTPRequestOperationManager *_HTTPManager;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)init
{
    if (!(self = [super init])) return nil;
    [self reset];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(settingsDidChange:)
                                                 name:AwfulSettingsDidChangeNotification
                                               object:nil];
    
    // When a user changes their password, subsequent HTTP operations will come back without a login cookie. So any operation might bear the news that we've been logged out.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(networkingOperationDidStart:)
                                                 name:AFNetworkingOperationDidStartNotification
                                               object:nil];
    return self;
}

+ (AwfulHTTPClient *)client
{
    static AwfulHTTPClient *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [AwfulHTTPClient new];
    });
    return instance;
}

- (void)reset
{
    [_HTTPManager.operationQueue cancelAllOperations];
    NSString *urlString = [AwfulSettings settings].customBaseURL;
    if (urlString) {
        NSURL *url = [NSURL URLWithString:urlString];
        if (!url.scheme) {
            urlString = [NSString stringWithFormat:@"http://%@", urlString];
        }
    } else {
        urlString = @"http://forums.somethingawful.com/";
    }
    _HTTPManager = [[AwfulHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:urlString]];
    _HTTPManager.requestSerializer = ({
        AwfulHTMLRequestSerializer *serializer = [AwfulHTMLRequestSerializer new];
        serializer.stringEncoding = NSWindowsCP1252StringEncoding;
        serializer;
    });
    NSArray *serializers = @[
                             [AFJSONResponseSerializer new],
                             ({
                                 AwfulHTMLResponseSerializer *serializer = [AwfulHTMLResponseSerializer new];
                                 serializer.stringEncoding = NSWindowsCP1252StringEncoding;
                                 serializer;
                             }),
                             ];
    _HTTPManager.responseSerializer = [AFCompoundResponseSerializer compoundSerializerWithResponseSerializers:serializers];
}

- (void)settingsDidChange:(NSNotification *)note
{
    NSArray *keys = note.userInfo[AwfulSettingsDidChangeSettingsKey];
    if ([keys containsObject:AwfulSettingsKeys.customBaseURL]) {
        [self reset];
    }
}

- (BOOL)isReachable
{
    return _HTTPManager.reachabilityManager.reachable;
}

- (BOOL)isLoggedIn
{
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:_HTTPManager.baseURL];
    return [[cookies valueForKey:NSHTTPCookieName] containsObject:@"bbuserid"];
}

- (void)networkingOperationDidStart:(NSNotification *)note
{
    // Only subscribe for notifications if we're logged in.
    if (!self.loggedIn) return;
    AFURLConnectionOperation *op = note.object;
    if (![op.request.URL.absoluteString hasPrefix:_HTTPManager.baseURL.absoluteString]) return;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(networkingOperationDidFinish:)
                                                 name:AFNetworkingOperationDidFinishNotification
                                               object:op];
}

- (void)networkingOperationDidFinish:(NSNotification *)note
{
    AFHTTPRequestOperation *op = note.object;
    NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
    [noteCenter removeObserver:self name:AFNetworkingOperationDidFinishNotification object:op];
    if (![op isKindOfClass:[AFHTTPRequestOperation class]]) return;
    
    // We only subscribed for this notification if we were logged in at the time. If we aren't logged in now, the cookies changed, and we need to finish logging out.
    if (!op.error && !self.loggedIn) {
        [[AwfulAppDelegate instance] logOut];
    }
}

- (NSOperation *)listThreadsInForum:(AwfulForum *)forum
                             onPage:(NSInteger)page
                            andThen:(void (^)(NSError *error, NSArray *threads))callback
{
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"forumdisplay.php"
                  parameters:@{ @"forumid": forum.forumID,
                                @"perpage": @40,
                                @"pagenumber": @(page) }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulThreadListScraper *scraper = [AwfulThreadListScraper new];
            NSError *error;
            NSArray *threads = [scraper scrapeDocument:document
                                               fromURL:operation.response.URL
                              intoManagedObjectContext:managedObjectContext
                                                 error:&error];
            if (callback) {
                dispatch_async(operation.completionQueue ?: dispatch_get_main_queue(), ^{
                    callback(error, threads);
                });
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)listBookmarkedThreadsOnPage:(NSInteger)page
                                     andThen:(void (^)(NSError *error, NSArray *threads))callback
{
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"bookmarkthreads.php"
                  parameters:@{ @"action": @"view",
                                @"perpage": @40,
                                @"pagenumber": @(page) }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulThreadListScraper *scraper = [AwfulThreadListScraper new];
            NSError *error;
            NSArray *threads = [scraper scrapeDocument:document
                                               fromURL:operation.response.URL
                              intoManagedObjectContext:managedObjectContext
                                                 error:&error];
            if (callback) {
                dispatch_async(operation.completionQueue ?: dispatch_get_main_queue(), ^{
                    callback(error, threads);
                });
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)listPostsInThread:(AwfulThread *)thread
                         writtenBy:(AwfulUser *)author
                            onPage:(AwfulThreadPage)page
                           andThen:(void (^)(NSError *error, NSArray *posts, NSUInteger firstUnreadPost, NSString *advertisementHTML))callback
{
    NSMutableDictionary *parameters = [@{ @"threadid": thread.threadID,
                                          @"perpage": @40 } mutableCopy];
    if (page == AwfulThreadPageNextUnread) {
        parameters[@"goto"] = @"newpost";
    } else if (page == AwfulThreadPageLast) {
        parameters[@"goto"] = @"lastpost";
    } else {
        parameters[@"pagenumber"] = @(page);
    }
    if (author.userID) {
        parameters[@"userid"] = author.userID;
    }
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"showthread.php"
                  parameters:parameters
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulPostsPageScraper *scraper = [AwfulPostsPageScraper new];
            NSError *error;
            NSArray *posts = [scraper scrapeDocument:document
                                             fromURL:operation.response.URL
                            intoManagedObjectContext:managedObjectContext
                                               error:&error];
            if (callback) {
                NSInteger firstUnreadPostIndex = NSNotFound;
                if (page == AwfulThreadPageNextUnread) {
                    AwfulScanner *scanner = [AwfulScanner scannerWithString:operation.response.URL.fragment];
                    if ([scanner scanString:@"pti" intoString:nil]) {
                        [scanner scanInteger:&firstUnreadPostIndex];
                        if (firstUnreadPostIndex == 0) {
                            firstUnreadPostIndex = NSNotFound;
                        } else {
                            firstUnreadPostIndex--;
                        }
                    }
                }
                callback(nil, posts, firstUnreadPostIndex, nil);
            }
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil, NSNotFound, nil);
    }];
}

- (NSOperation *)learnLoggedInUserInfoAndThen:(void (^)(NSError *error, AwfulUser *user))callback
{
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"member.php"
                  parameters:@{ @"action": @"getinfo" }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulProfileScraper *scraper = [AwfulProfileScraper new];
            NSError *error;
            AwfulUser *user = [scraper scrapeDocument:document
                                              fromURL:operation.response.URL
                             intoManagedObjectContext:managedObjectContext
                                                error:&error];
            if (callback) callback(error, user);
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)setThread:(AwfulThread *)thread
              isBookmarked:(BOOL)isBookmarked
                   andThen:(void (^)(NSError *error))callback
{
    return [_HTTPManager POST:@"bookmarkthreads.php"
                   parameters:@{ @"json": @"1",
                                 @"action": isBookmarked ? @"add" : @"remove",
                                 @"threadid": thread.threadID }
                      success:^(AFHTTPRequestOperation *operation, id responseObject)
    {
        thread.bookmarked = isBookmarked;
        if (callback) callback(nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error);
    }];
}

- (NSOperation *)taxonomizeForumsAndThen:(void (^)(NSError *error, NSArray *categories))callback
{
    // Seems like only forumdisplay.php and showthread.php have the <select> with a complete list of forums. We'll use the Main "forum" as it's the smallest page with the drop-down list.
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"forumdisplay.php"
                  parameters:@{ @"forumid": @"48" }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulForumHierarchyScraper *scraper = [AwfulForumHierarchyScraper new];
            NSError *error;
            NSArray *categories = [scraper scrapeDocument:document
                                                  fromURL:operation.response.URL
                                 intoManagedObjectContext:managedObjectContext
                                                    error:&error];
            if (callback) callback(error, categories);
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)replyToThread:(AwfulThread *)thread
                    withBBcode:(NSString *)text
                       andThen:(void (^)(NSError *error, AwfulPost *post))callback
{
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"newreply.php"
                  parameters:@{ @"action" : @"newreply",
                                @"threadid" : thread.threadID }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulFormScraper *scraper = [AwfulFormScraper new];
            NSError *error;
            NSArray *forms = [scraper scrapeDocument:document
                                             fromURL:operation.response.URL
                            intoManagedObjectContext:managedObjectContext
                                               error:&error];
            AwfulForm *firstForm = forms.firstObject;
            NSMutableDictionary *parameters = [firstForm recommendedParameters];
            if (!parameters[@"threadid"]) {
                NSString *extra = @"";
                if (thread.closed) {
                    extra = @". The thread may be closed";
                }
                NSString *description = [NSString stringWithFormat:@"Failed to reply; could not find form%@", extra];
                error = [NSError errorWithDomain:AwfulErrorDomain
                                            code:AwfulErrorCodes.parseError
                                        userInfo:@{ NSLocalizedDescriptionKey: description }];
                if (callback) callback(error, nil);
                return;
            }
            parameters[@"message"] = text;
            [_HTTPManager POST:@"newreply.php"
                    parameters:parameters
                       success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
            {
                NSString *postID;
                HTMLElementNode *link = ([document firstNodeMatchingSelector:@"a[href *= 'goto=post']"] ?:
                                         [document firstNodeMatchingSelector:@"a[href *= 'goto=lastpost']"]);
                NSURL *URL = [NSURL URLWithString:link[@"href"]];
                if ([URL.queryDictionary[@"goto"] isEqual:@"post"]) {
                    postID = URL.queryDictionary[@"postid"];
                }
                AwfulPost *post = [AwfulPost firstOrNewPostWithPostID:postID inManagedObjectContext:managedObjectContext];
                if (callback) callback(nil, post);
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                if (callback) callback(error, nil);
            }];
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)findBBcodeContentsWithPost:(AwfulPost *)post
                                    andThen:(void (^)(NSError *error, NSString *text))callback
{
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"editpost.php"
                  parameters:@{ @"action": @"editpost",
                                @"postid": post.postID }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulFormScraper *scraper = [AwfulFormScraper new];
            NSError *error;
            NSArray *forms = [scraper scrapeDocument:document
                                             fromURL:operation.response.URL
                            intoManagedObjectContext:managedObjectContext
                                               error:&error];
            if (forms.count < 1) {
                error = [NSError errorWithDomain:AwfulErrorDomain
                                            code:AwfulErrorCodes.parseError
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Failed getting post text; could not find form" }];
                if (callback) callback(error, nil);
                return;
            }
            AwfulForm *form = forms[0];
            for (AwfulFormItem *text in form.texts) {
                if ([text.name isEqualToString:@"message"]) {
                    if (callback) callback(error, text.value);
                    return;
                }
            }
            error = [NSError errorWithDomain:AwfulErrorDomain
                                        code:AwfulErrorCodes.parseError
                                    userInfo:@{ NSLocalizedDescriptionKey: @"Failed getting post text; could not find text box" }];
            if (callback) callback(error, nil);
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)quoteBBcodeContentsWithPost:(AwfulPost *)post
                                     andThen:(void (^)(NSError *error, NSString *quotedText))callback
{
    return [_HTTPManager GET:@"newreply.php"
                  parameters:@{ @"action": @"newreply",
                                @"postid": post.postID,
                                @"json": @1 }
                     success:^(AFHTTPRequestOperation *operation, NSDictionary *json)
    {
        if (!callback) return;
        // If you quote a post from a thread that's been moved to the Gas Chamber, you don't get a post body. That's an error, even though the HTTP operation succeeded.
        if (json[@"body"]) {
            callback(nil, json[@"body"]);
        } else {
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: @"Missing quoted post body" };
            NSError *error = [NSError errorWithDomain:AwfulErrorDomain
                                                 code:AwfulErrorCodes.parseError
                                             userInfo:userInfo];
            callback(error, nil);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)editPost:(AwfulPost *)post
                setBBcode:(NSString *)text
                  andThen:(void (^)(NSError *error))callback
{
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"editpost.php"
                  parameters:@{ @"action": @"editpost",
                                @"postid": post.postID }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulFormScraper *scraper = [AwfulFormScraper new];
            NSError *error;
            NSArray *forms = [scraper scrapeDocument:document
                                             fromURL:operation.response.URL
                            intoManagedObjectContext:managedObjectContext
                                               error:&error];
            if (forms.count < 1) {
                error = [NSError errorWithDomain:AwfulErrorDomain
                                            code:AwfulErrorCodes.parseError
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Failed to edit post; could not find form" }];
                if (callback) callback(error);
                return;
            }
            AwfulForm *form = forms[0];
            NSMutableDictionary *parameters = [form recommendedParameters];
            parameters[@"message"] = text;
            [parameters removeObjectForKey:@"preview"];
            [_HTTPManager POST:@"editpost.php"
                    parameters:parameters
                       success:^(AFHTTPRequestOperation *operation, id responseObject) {
                           if (callback) callback(nil);
                       } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                           if (callback) callback(error);
                       }];
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error);
    }];
}

- (NSOperation *)rateThread:(AwfulThread *)thread
                           :(NSInteger)rating
                    andThen:(void (^)(NSError *error))callback
{
    return [_HTTPManager POST:@"threadrate.php"
                   parameters:@{ @"vote": @(MAX(5, MIN(1, rating))),
                                 @"threadid": thread.threadID }
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          if (callback) callback(nil);
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          if (callback) callback(error);
                      }];
}

- (NSOperation *)markThreadReadUpToPost:(AwfulPost *)post
                                andThen:(void (^)(NSError *error))callback
{
    return [_HTTPManager GET:@"showthread.php"
                  parameters:@{ @"action": @"setseen",
                                @"threadid": post.thread.threadID,
                                @"index": @(post.threadIndex) }
                     success:^(AFHTTPRequestOperation *operation, id responseObject)
    {
        if (callback) callback(nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error);
    }];
}

- (NSOperation *)markThreadUnread:(AwfulThread *)thread
                          andThen:(void (^)(NSError *error))callback
{
    return [_HTTPManager POST:@"showthread.php"
                   parameters:@{ @"threadid": thread.threadID,
                                 @"action": @"resetseen",
                                 @"json": @"1" }
                      success:^(AFHTTPRequestOperation *operation, id responseObject)
    {
        if (callback) callback(nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error);
    }];
}

- (NSOperation *)logInWithUsername:(NSString *)username
                          password:(NSString *)password
                           andThen:(void (^)(NSError *error, AwfulUser *user))callback
{
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    return [_HTTPManager POST:@"account.php?json=1"
                   parameters:@{ @"action" : @"login",
                                 @"username" : username,
                                 @"password" : password,
                                 @"next": @"/member.php?action=getinfo" }
                      success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulProfileScraper *scraper = [AwfulProfileScraper new];
            NSError *error;
            AwfulUser *user = [scraper scrapeDocument:document
                                              fromURL:operation.response.URL
                             intoManagedObjectContext:self.managedObjectContext
                                                error:&error];
            if (!user) {
                if (callback) {
                    callback(error, nil);
                }
                return;
            }
            if (callback) callback(error, user);
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (operation.response.statusCode == 401) {
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: @"Invalid username or password",
                                        NSUnderlyingErrorKey: error };
            error = [NSError errorWithDomain:AwfulErrorDomain
                                        code:AwfulErrorCodes.badUsernameOrPassword
                                    userInfo:userInfo];
        }
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)locatePostWithID:(NSString *)postID
                          andThen:(void (^)(NSError *error, AwfulPost *post, AwfulThreadPage page))callback
{
    // The SA Forums will direct a certain URL to the thread with a given post. We'll wait for that
    // redirect, then parse out the info we need.
    NSURL *URL = [NSURL URLWithString:@"showthread.php" relativeToURL:_HTTPManager.baseURL];
    NSURLRequest *request = [_HTTPManager.requestSerializer requestWithMethod:@"GET"
                                                                    URLString:URL.absoluteString
                                                                   parameters:@{ @"goto" : @"post",
                                                                                 @"postid" : postID }];
    __block BOOL didSucceed = NO;
    AFHTTPRequestOperation *op = [_HTTPManager HTTPRequestOperationWithRequest:request success:^(id _, id __) {
        // Once we have the redirect we want, we cancel the operation. So if this "success" callback gets called, we've actually failed.
        if (callback) {
            NSString *message = @"The post could not be found";
            NSError *error = [NSError errorWithDomain:AwfulErrorDomain
                                                 code:AwfulErrorCodes.parseError
                                             userInfo:@{ NSLocalizedDescriptionKey: message }];
            callback(error, nil, 0);
        }
    } failure:^(AFHTTPRequestOperation *op, NSError *error) {
        if (!didSucceed) {
            if (callback) callback(error, nil, 0);
        }
    }];
    __weak AFHTTPRequestOperation *weakOp = op;
    [op setRedirectResponseBlock:^NSURLRequest *(NSURLConnection *connection, NSURLRequest *request, NSURLResponse *response) {
        AFHTTPRequestOperation *op = weakOp;
        didSucceed = YES;
        if (!response) return request;
        [op cancel];
        if (!callback) return nil;
        NSDictionary *query = [request.URL queryDictionary];
        if ([query[@"threadid"] length] > 0 && [query[@"pagenumber"] integerValue] != 0) {
            dispatch_async(op.completionQueue ?: dispatch_get_main_queue(), ^{
                callback(nil, query[@"threadid"], [query[@"pagenumber"] integerValue]);
            });
        } else {
            NSString *missingInfo = query[@"threadid"] ? @"page number" : @"thread ID";
            NSString *message = [NSString stringWithFormat:@"The %@ could not be found",
                                 missingInfo];
            NSError *error = [NSError errorWithDomain:AwfulErrorDomain
                                                 code:AwfulErrorCodes.parseError
                                             userInfo:@{ NSLocalizedDescriptionKey: message }];
            dispatch_async(op.completionQueue ?: dispatch_get_main_queue(), ^{
                callback(error, nil, 0);
            });
        }
        return nil;
    }];
    [_HTTPManager.operationQueue addOperation:op];
    return op;
}

- (NSOperation *)profileUser:(AwfulUser *)user
                     andThen:(void (^)(NSError *error))callback
{
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"member.php"
                  parameters:@{ @"action": @"getinfo",
                                @"userid": user.userID }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulProfileScraper *scraper = [AwfulProfileScraper new];
            NSError *error;
            [scraper scrapeDocument:document
                            fromURL:operation.response.URL
           intoManagedObjectContext:managedObjectContext
                              error:&error];
            if (callback) callback(error);
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error);
    }];
}

- (NSOperation *)listBansOnPage:(NSInteger)page
                        forUser:(AwfulUser *)user
                        andThen:(void (^)(NSError *error, NSArray *bans))callback
{
    NSMutableDictionary *parameters = [@{ @"pagenumber": @(page) } mutableCopy];
    if (user.userID) {
        parameters[@"pagenumber"] = @(page);
    }
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"banlist.php"
                  parameters:parameters
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulLepersColonyPageScraper *scraper = [AwfulLepersColonyPageScraper new];
            NSError *error;
            NSArray *bans = [scraper scrapeDocument:document
                                            fromURL:operation.response.URL
                           intoManagedObjectContext:managedObjectContext
                                              error:&error];
            if (callback) callback(error, bans);
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)listPrivateMessageInboxAndThen:(void (^)(NSError *error, NSArray *messages))callback
{
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"private.php"
                  parameters:nil
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulMessageFolderScraper *scraper = [AwfulMessageFolderScraper new];
            NSError *error;
            NSArray *messages = [scraper scrapeDocument:document
                                                fromURL:operation.response.URL
                               intoManagedObjectContext:managedObjectContext
                                                  error:&error];
            if (callback) callback(error, messages);
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)deletePrivateMessage:(AwfulPrivateMessage *)message
                              andThen:(void (^)(NSError *error))callback
{
    return [_HTTPManager POST:@"private.php"
                   parameters:@{ @"action": @"dodelete",
                                 @"privatemessageid": message.messageID,
                                 @"delete": @"yes" }
                      success:^(AFHTTPRequestOperation *operation, id responseObject)
    {
        if (callback) callback(nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error);
    }];
}

- (NSOperation *)readPrivateMessage:(AwfulPrivateMessage *)message
                            andThen:(void (^)(NSError *error))callback
{
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"private.php"
                  parameters:@{ @"action": @"show",
                                @"privatemessageid": message.messageID }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulPrivateMessageScraper *scraper = [AwfulPrivateMessageScraper new];
            NSError *error;
            [scraper scrapeDocument:document
                            fromURL:operation.response.URL
           intoManagedObjectContext:managedObjectContext
                              error:&error];
            if (callback) callback(error);
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error);
    }];
}

- (NSOperation *)quoteBBcodeContentsOfPrivateMessage:(AwfulPrivateMessage *)message
                                             andThen:(void (^)(NSError *error, NSString *BBcode))callback
{
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"private.php"
                  parameters:@{ @"action": @"newmessage",
                                @"privatemessageid": message.messageID }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulFormScraper *scraper = [AwfulFormScraper new];
            NSError *error;
            NSArray *forms = [scraper scrapeDocument:document
                                             fromURL:operation.response.URL
                            intoManagedObjectContext:managedObjectContext
                                               error:&error];
            if (forms.count < 1) {
                error = [NSError errorWithDomain:AwfulErrorDomain
                                            code:AwfulErrorCodes.parseError
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Failed quoting private message; could not find form" }];
                if (callback) callback(error, nil);
                return;
            }
            AwfulForm *form = forms[0];
            for (AwfulFormItem *text in form.texts) {
                if ([text.name isEqualToString:@"message"]) {
                    if (callback) callback(error, text.value);
                    return;
                }
            }
            error = [NSError errorWithDomain:AwfulErrorDomain
                                        code:AwfulErrorCodes.parseError
                                    userInfo:@{ NSLocalizedDescriptionKey: @"Failed quoting private message; could not find text box" }];
            if (callback) callback(error, nil);
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)listAvailablePrivateMessageThreadTagsAndThen:(void (^)(NSError *error, NSArray *threadTags))callback
{
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"private.php"
                  parameters:@{ @"action": @"newmessage" }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulFormScraper *scraper = [AwfulFormScraper new];
            NSError *error;
            NSArray *forms = [scraper scrapeDocument:document
                                             fromURL:operation.response.URL
                            intoManagedObjectContext:managedObjectContext
                                               error:&error];
            if (forms.count < 1) {
                error = [NSError errorWithDomain:AwfulErrorDomain
                                            code:AwfulErrorCodes.parseError
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Failed scraping thread tags from new private message form" }];
                if (callback) callback(error, nil);
                return;
            }
            AwfulForm *form = forms[0];
            if (callback) callback(error, form.threadTags);
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)sendPrivateMessageTo:(NSString *)username
                          withSubject:(NSString *)subject
                            threadTag:(AwfulThreadTag *)threadTag
                               BBcode:(NSString *)text
                     asReplyToMessage:(AwfulPrivateMessage *)regardingMessage
                 forwardedFromMessage:(AwfulPrivateMessage *)forwardedMessage
                              andThen:(void (^)(NSError *error))callback
{
    NSMutableDictionary *parameters = [@{ @"touser": username,
                                           @"title": subject,
                                           @"iconid": threadTag.threadTagID ?: @"0",
                                           @"message": text,
                                           @"action": @"dosend",
                                           @"forward": forwardedMessage.messageID ? @"true" : @"",
                                           @"savecopy": @"yes",
                                           @"submit": @"Send Message" } mutableCopy];
    if (regardingMessage || forwardedMessage) {
        parameters[@"prevmessageid"] = regardingMessage.messageID ?: forwardedMessage.messageID;
    }
    return [_HTTPManager POST:@"private.php"
                   parameters:parameters
                      success:^(AFHTTPRequestOperation *operation, id responseObject) {
                          if (callback) callback(nil);
                      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                          if (callback) callback(error);
                      }];
}

- (NSOperation *)listAvailablePostIconsForForumWithID:(NSString *)forumID
                                              andThen:(void (^)(NSError *error, AwfulForm *form))callback
{
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"newthread.php"
                  parameters:@{ @"action": @"newthread",
                                @"forumid": forumID }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulFormScraper *scraper = [AwfulFormScraper new];
            NSError *error;
            NSArray *forms = [scraper scrapeDocument:document
                                             fromURL:operation.response.URL
                            intoManagedObjectContext:managedObjectContext
                                               error:&error];
            if (forms.count < 1) {
                error = [NSError errorWithDomain:AwfulErrorDomain
                                            code:AwfulErrorCodes.parseError
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Failed parsing new thread form" }];
                if (callback) callback(error, nil);
                return;
            }
            if (callback) callback(error, forms[0]);
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

- (NSOperation *)postThreadInForum:(AwfulForum *)forum
                       withSubject:(NSString *)subject
                         threadTag:(AwfulThreadTag *)threadTag
                      secondaryTag:(AwfulThreadTag *)secondaryTag
               secondaryTagFormKey:(NSString *)secondaryTagFormKey
                            BBcode:(NSString *)text
                           andThen:(void (^)(NSError *error, AwfulThread *thread))callback
{
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    return [_HTTPManager GET:@"newthread.php"
                  parameters:@{ @"action": @"newthread",
                                @"forumid": forum.forumID }
                     success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
    {
        [managedObjectContext performBlock:^{
            AwfulFormScraper *scraper = [AwfulFormScraper new];
            NSError *error;
            NSArray *forms = [scraper scrapeDocument:document
                                             fromURL:operation.response.URL
                            intoManagedObjectContext:managedObjectContext
                                               error:&error];
            if (forms.count < 1) {
                error = [NSError errorWithDomain:AwfulErrorDomain
                                            code:AwfulErrorCodes.parseError
                                        userInfo:@{ NSLocalizedDescriptionKey: @"Failed to scrape new thread form" }];
                if (callback) callback(error, nil);
                return;
            }
            AwfulForm *form = forms[0];
            NSMutableDictionary *parameters = [form recommendedParameters];
            parameters[@"subject"] = [subject copy];
            parameters[form.threadTagName] = threadTag.threadTagID ?: @"0";
            parameters[@"message"] = [text copy];
            if (secondaryTag) {
                parameters[form.secondaryThreadTagName] = secondaryTag.threadTagID;
            }
            [parameters removeObjectForKey:@"preview"];
            [_HTTPManager POST:@"newthread.php"
                    parameters:parameters
                       success:^(AFHTTPRequestOperation *operation, HTMLDocument *document)
            {
                HTMLElementNode *link = [document firstNodeMatchingSelector:@"a[href *= 'showthread']"];
                NSURL *URL = [NSURL URLWithString:link[@"href"]];
                NSString *threadID = URL.queryDictionary[@"threadid"];
                AwfulThread *thread = [AwfulThread firstOrNewThreadWithThreadID:threadID inManagedObjectContext:managedObjectContext];
                if (callback) callback(nil, thread);
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                if (callback) callback(error, nil);
            }];
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
}

@end

@implementation AwfulHTTPRequestOperationManager

#pragma mark -

- (AFHTTPRequestOperation *)HTTPRequestOperationWithRequest:(NSURLRequest *)urlRequest
                                                    success:(void (^)(AFHTTPRequestOperation *, id))success
                                                    failure:(void (^)(AFHTTPRequestOperation *, NSError *))failure
{
    // NSURLConnection will, absent relevant HTTP headers, cache responses for an unknown and unfortunately long time.
    // http://blackpixel.com/blog/2012/05/caching-and-nsurlconnection.html
    // This came up when using Awful from some public wi-fi that redirected to a login page. Six hours and a different network later, the same login page was being served up from the cache.
    AFHTTPRequestOperation *op = [super HTTPRequestOperationWithRequest:urlRequest
                                                                success:success
                                                                failure:failure];
    if ([[urlRequest HTTPMethod] compare:@"GET" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        [op setCacheResponseBlock:^(NSURLConnection *connection, NSCachedURLResponse *cachedResponse) {
            if ([connection currentRequest].cachePolicy == NSURLRequestUseProtocolCachePolicy) {
                NSHTTPURLResponse *response = (id)[cachedResponse response];
                NSDictionary *headers = [response allHeaderFields];
                if (!(headers[@"Cache-Control"] || headers[@"Expires"])) {
                    NSLog(@"refusing to cache response to %@", urlRequest.URL);
                    return (NSCachedURLResponse *)nil;
                }
            }
            return cachedResponse;
        }];
    }
    return op;
}

@end
