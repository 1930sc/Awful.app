//
//  AwfulHTTPClient.m
//  Awful
//
//  Created by Sean Berry on 5/26/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHTTPClient.h"
#import "AwfulDataStack.h"
#import "AwfulModels.h"
#import "AwfulPage.h"
#import "AwfulPageDataController.h"
#import "AwfulPageTemplate.h"
#import "AwfulParsing.h"
#import "AwfulSettings.h"
#import "AwfulStringEncoding.h"

@implementation AwfulHTTPClient

+ (AwfulHTTPClient *)client
{
    static AwfulHTTPClient *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AwfulHTTPClient alloc] initWithBaseURL:
                    [NSURL URLWithString:@"http://forums.somethingawful.com/"]];
    });
    return instance;
}

- (id)initWithBaseURL:(NSURL *)url
{
    self = [super initWithBaseURL:url];
    if (self) {
        self.stringEncoding = NSWindowsCP1252StringEncoding;
    }
    return self;
}

- (NSOperation *)listThreadsInForumWithID:(NSString *)forumID
                                   onPage:(NSInteger)page
                                  andThen:(void (^)(NSError *error, NSArray *threads))callback
{
    NSDictionary *parameters = @{ @"forumid": forumID, @"perpage": @40, @"pagenumber": @(page) };
    NSURLRequest *request = [self requestWithMethod:@"GET"
                                               path:@"forumdisplay.php"
                                         parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id responseObject)
    {
        NSArray *infos = [ThreadParsedInfo threadsWithHTMLData:responseObject];
        NSArray *threads = [AwfulThread threadsCreatedOrUpdatedWithParsedInfo:infos];
        NSInteger stickyIndex = -(NSInteger)[threads count];
        NSArray *forums = [AwfulForum fetchAllMatchingPredicate:@"forumID = %@", forumID];
        for (AwfulThread *thread in threads) {
            if ([forums count] > 0) thread.forum = forums[0];
            thread.stickyIndexValue = thread.isStickyValue ? stickyIndex++ : 0;
        }
        [[AwfulDataStack sharedDataStack] save];
    } failure:^(id _, NSError *error) {
        if (callback) callback(error, nil);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)listBookmarkedThreadsOnPage:(NSInteger)page
                                     andThen:(void (^)(NSError *error, NSArray *threads))callback
{
    NSDictionary *parameters = @{ @"action": @"view", @"perpage": @40, @"pagenumber": @(page) };
    NSURLRequest *request = [self requestWithMethod:@"GET"
                                               path:@"bookmarkthreads.php"
                                         parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id responseData)
    {
        NSArray *threadInfos = [ThreadParsedInfo threadsWithHTMLData:responseData];
        NSArray *threads = [AwfulThread threadsCreatedOrUpdatedWithParsedInfo:threadInfos];
        [threads setValue:@YES forKey:AwfulThreadAttributes.isBookmarked];
        [[AwfulDataStack sharedDataStack] save];
        if (callback) callback(nil, threads);
    } failure:^(id _, NSError *error) {
        if (callback) callback(error, nil);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

-(NSOperation *)pageDataForThread : (AwfulThread *)thread destinationType : (AwfulPageDestinationType)destinationType pageNum : (NSUInteger)pageNum onCompletion:(PageResponseBlock)pageResponseBlock onError:(AwfulErrorBlock)errorBlock
{
    NSString *append = @"";
    switch(destinationType) {
        case AwfulPageDestinationTypeFirst:
            append = @"";
            break;
        case AwfulPageDestinationTypeLast:
            append = @"&goto=lastpost";
            break;
        case AwfulPageDestinationTypeNewpost:
            append = @"&goto=newpost";
            break;
        case AwfulPageDestinationTypeSpecific:
            append = [NSString stringWithFormat:@"&pagenumber=%d", pageNum];
            break;
        default:
            append = @"";
            break;
    }
    
    NSString *path = [[NSString alloc] initWithFormat:@"showthread.php?threadid=%@%@", thread.threadID, append];
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           NSURLResponse *urlResponse = [operation response];
           NSURL *lastURL = [urlResponse URL];
           NSData *data = (NSData *)response;
           AwfulPageDataController *data_controller = [[AwfulPageDataController alloc] initWithResponseData:data pageURL:lastURL];
           thread.isLockedValue = data_controller.isLocked;
           pageResponseBlock(data_controller);
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

- (NSOperation *)learnUserInfoAndThen:(void (^)(NSError *error, NSDictionary *userInfo))callback
{
    NSDictionary *parameters = @{ @"action": @"editprofile" };
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET"
                                                  path:@"member.php"
                                            parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
                                                               success:^(id _, id response)
    {
        UserParsedInfo *parsed = [[UserParsedInfo alloc] initWithHTMLData:(NSData *)response];
        if (callback) callback(nil, @{ @"userID": parsed.userID, @"username": parsed.username });
    } failure:^(id _, NSError *error) {
        if (callback) callback(error, nil);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)bookmarkThreadWithID:(NSString *)threadID
                              andThen:(void (^)(NSError *error))callback
{
    return [self addOrRemove:Add bookmarkWithThreadID:threadID andThen:callback];
}

- (NSOperation *)unbookmarkThreadWithID:(NSString *)threadID
                                andThen:(void (^)(NSError *error))callback
{
    return [self addOrRemove:Remove bookmarkWithThreadID:threadID andThen:callback];
}

typedef enum {
    Add,
    Remove
} AddOrRemove;

static NSString * const AddOrRemoveString[] = { @"add", @"remove" };

- (NSOperation *)addOrRemove:(AddOrRemove)action
        bookmarkWithThreadID:(NSString *)threadID
                     andThen:(void (^)(NSError *error))callback
{
    NSDictionary *parameters = @{ @"json": @"1", @"action": AddOrRemoveString[action], @"threadid": threadID };
    NSURLRequest *request = [self requestWithMethod:@"POST"
                                               path:@"bookmarkthreads.php"
                                         parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id __)
    {
        if (callback) callback(nil);
    } failure:^(id _, NSError *error) {
        if (callback) callback(error);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)listForumsAndThen:(void (^)(NSError *error, NSArray *forums))callback
{
    // Seems like only forumdisplay.php and showthread.php have the <select> with a complete list
    // of forums. We'll use the Comedy Goldmine as it's generally available and hopefully it's not
    // much of a burden since threads rarely get goldmined.
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET"
                                                  path:@"forumdisplay.php"
                                            parameters:@{ @"forumid": @"21" }];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest
                                                               success:^(id _, id response)
    {
        NSData *data = (NSData *)response;
        ForumHierarchyParsedInfo *info = [[ForumHierarchyParsedInfo alloc] initWithHTMLData:data];
        NSArray *forums = [AwfulForum updateCategoriesAndForums:info];
        if (callback) callback(nil, forums);
    } failure:^(id _, NSError *error) {
        if (callback) callback(error, nil);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)replyToThreadWithID:(NSString *)threadID
                                text:(NSString *)text
                             andThen:(void (^)(NSError *error, NSString *postID))callback
{
    NSDictionary *parameters = @{ @"action" : @"newreply", @"threadid" : threadID };
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET"
                                                  path:@"newreply.php"
                                            parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest
                                                               success:^(id _, id data)
    {
        ReplyFormParsedInfo *formInfo = [[ReplyFormParsedInfo alloc] initWithHTMLData:(NSData *)data];
        if (!(formInfo.formkey && formInfo.formCookie)) {
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : @"Thread is closed" };
            NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:-1 userInfo:userInfo];
            if (callback) callback(error, nil);
            return;
        }
        NSMutableDictionary *postParameters = [@{
            @"threadid" : threadID,
            @"formkey" : formInfo.formkey,
            @"form_cookie" : formInfo.formCookie,
            @"action" : @"postreply",
            @"message" : text,
            @"parseurl" : @"yes",
            @"submit" : @"Submit Reply",
        } mutableCopy];
        if (formInfo.bookmark) {
            postParameters[@"bookmark"] = formInfo.bookmark;
        }
        
        NSURLRequest *postRequest = [self requestWithMethod:@"POST"
                                                       path:@"newreply.php"
                                                 parameters:postParameters];
        [self enqueueHTTPRequestOperation:[self HTTPRequestOperationWithRequest:postRequest
                                                                        success:^(id _, id responseData)
        {
            SuccessfulReplyInfo *replyInfo = [[SuccessfulReplyInfo alloc] initWithHTMLData:(NSData *)responseData];
            if (callback) callback(nil, replyInfo.lastPage ? nil : replyInfo.postID);
        } failure:^(id _, NSError *error)
        {
            if (callback) callback(error, nil);
        }]];
    } failure:^(id _, NSError *error)
    {
        if (callback) callback(error, nil);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)getTextOfPostWithID:(NSString *)postID
                             andThen:(void (^)(NSError *error, NSString *text))callback
{
    NSURLRequest *request = [self requestWithMethod:@"GET"
                                               path:@"editpost.php"
                                         parameters:@{ @"action": @"editpost", @"postid": postID }];
    return [self textOfPostWithRequest:request andThen:callback];
}

- (NSOperation *)quoteTextOfPostWithID:(NSString *)postID
                               andThen:(void (^)(NSError *error, NSString *quotedText))callback
{
    NSURLRequest *request = [self requestWithMethod:@"GET"
                                               path:@"newreply.php"
                                         parameters:@{ @"action": @"newreply", @"postid": postID }];
    return [self textOfPostWithRequest:request andThen:callback];
}

- (NSOperation *)textOfPostWithRequest:(NSURLRequest *)request
                               andThen:(void (^)(NSError *, NSString *))callback
{
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id responseData)
    {
        NSString *rawString = [[NSString alloc] initWithData:responseData
                                                    encoding:self.stringEncoding];
        NSData *converted = [rawString dataUsingEncoding:NSUTF8StringEncoding];
        TFHpple *base = [[TFHpple alloc] initWithHTMLData:converted];
        TFHppleElement *textarea = [base searchForSingle:@"//textarea[@name='message']"];
        if (callback) callback(nil, [textarea content]);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error, nil);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)editPostWithID:(NSString *)postID
                           text:(NSString *)text
                        andThen:(void (^)(NSError *error))callback
{
    NSDictionary *parameters = @{ @"action": @"editpost", @"postid": postID };
    NSURLRequest *request = [self requestWithMethod:@"GET"
                                               path:@"editpost.php"
                                         parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id responseData)
    {
        NSMutableDictionary *moreParameters = [@{
                                               @"action": @"updatepost",
                                               @"submit": @"Save Changes",
                                               @"postid": postID,
                                               @"message": text
                                               } mutableCopy];
        NSString *rawString = [[NSString alloc] initWithData:responseData
                                                    encoding:self.stringEncoding];
        NSData *converted = [rawString dataUsingEncoding:NSUTF8StringEncoding];
        TFHpple *pageData = [[TFHpple alloc] initWithHTMLData:converted];
        TFHppleElement *bookmarkElement = [pageData searchForSingle:@"//input[@name='bookmark' and @checked='checked']"];
        if (bookmarkElement) {
            moreParameters[@"bookmark"] = [bookmarkElement objectForKey:@"value"];
        }
        NSURLRequest *anotherRequest = [self requestWithMethod:@"POST"
                                                          path:@"editpost.php"
                                                    parameters:moreParameters];
        AFHTTPRequestOperation *finalOp = [self HTTPRequestOperationWithRequest:anotherRequest
                                                                        success:^(id _, id __)
        {
            if (callback) callback(nil);
        } failure:^(id _, NSError *error) {
            if (callback) callback(error);
        }];
        
        [self enqueueHTTPRequestOperation:finalOp];
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)rateThreadWithID:(NSString *)threadID
                           rating:(NSInteger)rating
                          andThen:(void (^)(NSError *error))callback
{
    NSDictionary *parameters = @{ @"vote": @(MAX(5, MIN(1, rating))), @"threadid": threadID };
    NSURLRequest *request = [self requestWithMethod:@"POST"
                                               path:@"threadrate.php"
                                         parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id __)
    {
        if (callback) callback(nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (callback) callback(error);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

-(NSOperation *)processMarkSeenLink : (NSString *)markSeenLink onCompletion : (CompletionBlock)completionBlock onError:(AwfulErrorBlock)errorBlock
{
    NSString *path = markSeenLink;
    NSURLRequest *urlRequest = [self requestWithMethod:@"GET" path:path parameters:nil];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:urlRequest 
       success:^(AFHTTPRequestOperation *operation, id response) {
           if (completionBlock) completionBlock();
       } 
       failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           if (errorBlock) errorBlock(error);
       }];
    [self enqueueHTTPRequestOperation:op];
    return (NSOperation *)op;
}

- (NSOperation *)forgetReadPostsInThreadWithID:(NSString *)threadID
                                       andThen:(void (^)(NSError *error))callback
{
    NSDictionary *parameters = @{ @"threadid": threadID, @"action": @"resetseen", @"json": @"1" };
    NSURLRequest *request = [self requestWithMethod:@"POST"
                                               path:@"showthread.php"
                                         parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id __)
    {
           if (callback) callback(nil);
    } failure:^(id _, NSError *error) {
           if (callback) callback(error);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)logInAsUsername:(NSString *)username
                    withPassword:(NSString *)password
                         andThen:(void (^)(NSError *error))callback
{
    NSDictionary *parameters = @{
        @"action" : @"login",
        @"username" : username,
        @"password" : password
    };
    NSURLRequest *request = [self requestWithMethod:@"POST"
                                               path:@"account.php"
                                         parameters:parameters];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id responseObject)
    {
        NSString *response = [[NSString alloc] initWithData:responseObject
                                                   encoding:self.stringEncoding];
        if ([response rangeOfString:@"GLLLUUUUUEEEEEE"].location != NSNotFound) {
            if (callback) callback(nil);
        } else {
            if (callback) callback([NSError errorWithDomain:NSCocoaErrorDomain
                                                       code:-1
                                                   userInfo:nil]);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error)
    {
        if (callback) callback(error);
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

- (NSOperation *)locatePostWithID:(NSString *)postID
    andThen:(void (^)(NSError *error, NSString *threadID, NSInteger page))callback
{
    // The SA Forums will direct a certain URL to the thread with a given post. We'll wait for that
    // redirect, then parse out the info we need.
    NSURLRequest *request = [self requestWithMethod:@"GET"
                                               path:@"showthread.php"
                                         parameters:@{ @"goto" : @"post", @"postid" : postID }];
    AFHTTPRequestOperation *op = [self HTTPRequestOperationWithRequest:request
                                                               success:^(id _, id __)
    {
        // Once we have the redirect we want, we cancel the operation. So if this "success" callback
        // gets called, we've actually failed.
        if (callback) callback(nil, nil, 0);
    } failure:^(id _, NSError *error)
    {
        if (callback) callback(error, nil, 0);
    }];
    __weak AFHTTPRequestOperation *blockOp = op;
    [op setRedirectResponseBlock:^NSURLRequest *(id _, NSURLRequest *request, NSURLResponse *response)
    {
        if (!response) return request;
        [blockOp cancel];
        NSDictionary *query = [[request URL] queryDictionary];
        if (callback) {
            dispatch_queue_t queue = blockOp.successCallbackQueue;
            if (!queue) queue = dispatch_get_main_queue();
            dispatch_async(queue, ^{
                callback(nil, query[@"threadid"], [query[@"pagenumber"] integerValue]);
            });
        }
        return nil;
    }];
    [self enqueueHTTPRequestOperation:op];
    return op;
}

@end
