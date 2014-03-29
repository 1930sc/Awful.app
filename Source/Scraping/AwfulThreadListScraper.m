//  AwfulThreadListScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadListScraper.h"
#import "AwfulCompoundDateParser.h"
#import "AwfulErrorDomain.h"
#import "AwfulModels.h"
#import "AwfulScanner.h"
#import "GTMNSString+HTML.h"
#import "HTMLNode+CachedSelector.h"
#import "NSURL+QueryDictionary.h"

@interface AwfulThreadListScraper ()

@property (strong, nonatomic) AwfulForum *forum;

@property (copy, nonatomic) NSArray *threads;

@end

@implementation AwfulThreadListScraper

- (void)scrape
{
    HTMLElement *body = [self.node awful_firstNodeMatchingCachedSelector:@"body"];
    if (body[@"data-forum"]) {
        self.forum = [AwfulForum fetchOrInsertForumInManagedObjectContext:self.managedObjectContext withID:body[@"data-forum"]];
    }
    
    HTMLElement *breadcrumbsDiv = [self.node awful_firstNodeMatchingCachedSelector:@"div.breadcrumbs"];
    
    // The first hierarchy link (if any) is the category. The rest are forums/subforums.
    NSArray *hierarchyLinks = [breadcrumbsDiv awful_nodesMatchingCachedSelector:@"a[href *= 'forumdisplay.php']"];

    HTMLElement *forumLink = hierarchyLinks.lastObject;
    if (forumLink) {
        self.forum.name = [forumLink.textContent gtm_stringByUnescapingFromHTML];
    }
    if (hierarchyLinks.count > 0) {
        HTMLElement *categoryLink = hierarchyLinks.firstObject;
        NSURL *URL = [NSURL URLWithString:categoryLink[@"href"]];
        NSString *categoryID = URL.queryDictionary[@"forumid"];
        AwfulCategory *category = [AwfulCategory firstOrNewCategoryWithCategoryID:categoryID inManagedObjectContext:self.managedObjectContext];
        category.name = [categoryLink.innerHTML gtm_stringByUnescapingFromHTML];
        NSArray *subforumLinks = [hierarchyLinks subarrayWithRange:NSMakeRange(1, hierarchyLinks.count - 1)];
        AwfulForum *currentForum;
        for (HTMLElement *subforumLink in subforumLinks.reverseObjectEnumerator) {
            NSURL *URL = [NSURL URLWithString:subforumLink[@"href"]];
            NSString *subforumID = URL.queryDictionary[@"forumid"];
            AwfulForum *subforum = [AwfulForum fetchOrInsertForumInManagedObjectContext:self.managedObjectContext withID:subforumID];
            subforum.name = [subforumLink.innerHTML gtm_stringByUnescapingFromHTML];
            subforum.category = category;
            currentForum.parentForum = subforum;
            currentForum = subforum;
        }
    }
    
    // TODO parse number of pages so we know whether to enable pull-for-more.
    
    HTMLElement *threadTagsDiv = [self.node awful_firstNodeMatchingCachedSelector:@"div.thread_tags"];
    if (threadTagsDiv) {
        NSMutableOrderedSet *threadTags = [NSMutableOrderedSet new];
        for (HTMLElement *link in [threadTagsDiv awful_nodesMatchingCachedSelector:@"a[href*='posticon']"]) {
            NSURL *URL = [NSURL URLWithString:link[@"href"]];
            NSString *threadTagID = URL.queryDictionary[@"posticon"];
            HTMLElement *image = [link awful_firstNodeMatchingCachedSelector:@"img"];
            NSURL *imageURL = [NSURL URLWithString:image[@"src"]];
            AwfulThreadTag *threadTag = [AwfulThreadTag firstOrNewThreadTagWithThreadTagID:threadTagID
                                                                              threadTagURL:imageURL
                                                                    inManagedObjectContext:self.managedObjectContext];
            [threadTags addObject:threadTag];
        }
        self.forum.threadTags = threadTags;
    }
    
    NSArray *threadLinks = [self.node awful_nodesMatchingCachedSelector:@"tr.thread"];
    NSMutableArray *threads = [NSMutableArray new];
    int32_t stickyIndex = -(int32_t)threadLinks.count;
    for (HTMLElement *row in threadLinks) {
        NSString *threadID;
        {
            AwfulScanner *scanner = [AwfulScanner scannerWithString:row[@"id"]];
            [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
            threadID = [scanner.string substringFromIndex:scanner.scanLocation];
        }
        if (threadID.length == 0) {
            self.error = [NSError errorWithDomain:AwfulErrorDomain
                                             code:AwfulErrorCodes.parseError
                                         userInfo:@{ NSLocalizedDescriptionKey: @"Thread list parsing failed; could not find thread ID" }];
            continue;
        }
        AwfulThread *thread = [AwfulThread firstOrNewThreadWithThreadID:threadID inManagedObjectContext:self.managedObjectContext];
        [threads addObject:thread];
        HTMLElement *stickyCell = [row awful_firstNodeMatchingCachedSelector:@"td.title_sticky"];
        thread.sticky = !!stickyCell;
        if (self.forum) {
            thread.forum = self.forum;
            if (thread.sticky) {
                thread.stickyIndex = stickyIndex;
                stickyIndex++;
            } else {
                thread.stickyIndex = 0;
            }
        }
        HTMLElement *titleLink = [row awful_firstNodeMatchingCachedSelector:@"a.thread_title"];
        if (titleLink) {
            thread.title = [titleLink.innerHTML gtm_stringByUnescapingFromHTML];
        }
        HTMLElement *threadTagImage = [row awful_firstNodeMatchingCachedSelector:@"td.icon img"];
        if (!threadTagImage) {
            threadTagImage = [row awful_firstNodeMatchingCachedSelector:@"td.rating img[src*='/rate/reviews']"];
        }
        if (threadTagImage) {
            NSURL *URL = [NSURL URLWithString:threadTagImage[@"src"]];
            NSString *threadTagID = URL.fragment;
            thread.threadTag = [AwfulThreadTag firstOrNewThreadTagWithThreadTagID:threadTagID
                                                                     threadTagURL:URL
                                                           inManagedObjectContext:self.managedObjectContext];
        }
        HTMLElement *secondaryThreadTagImage = [row awful_firstNodeMatchingCachedSelector:@"td.icon2 img"];
        if (secondaryThreadTagImage) {
            NSURL *URL = [NSURL URLWithString:secondaryThreadTagImage[@"src"]];
            NSString *threadTagID = URL.fragment;
            thread.secondaryThreadTag = [AwfulThreadTag firstOrNewThreadTagWithThreadTagID:threadTagID
                                                                              threadTagURL:URL
                                                                    inManagedObjectContext:self.managedObjectContext];
        }
        HTMLElement *authorProfileLink = [row awful_firstNodeMatchingCachedSelector:@"td.author a"];
        if (authorProfileLink) {
            NSString *authorUsername = [[authorProfileLink innerHTML] gtm_stringByUnescapingFromHTML];
            NSURL *profileURL = [NSURL URLWithString:authorProfileLink[@"href"]];
            NSString *authorUserID = profileURL.queryDictionary[@"userid"];
            AwfulUser *author = [AwfulUser firstOrNewUserWithUserID:authorUserID
                                                           username:authorUsername
                                             inManagedObjectContext:self.managedObjectContext];
            if (author) {
                thread.author = author;
            }
        }
        NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        NSArray *rowClasses = [row[@"class"] componentsSeparatedByCharactersInSet:whitespace];
        thread.closed = [rowClasses containsObject:@"closed"];
        HTMLElement *bookmarkStarCell = [row awful_firstNodeMatchingCachedSelector:@"td.star"];
        if (bookmarkStarCell) {
            NSArray *starClasses = [bookmarkStarCell[@"class"] componentsSeparatedByCharactersInSet:whitespace];
            if ([starClasses containsObject:@"bm0"]) {
                thread.starCategory = AwfulStarCategoryOrange;
            } else if ([starClasses containsObject:@"bm1"]) {
                thread.starCategory = AwfulStarCategoryRed;
            } else if ([starClasses containsObject:@"bm2"]) {
                thread.starCategory = AwfulStarCategoryYellow;
            } else {
                thread.starCategory = AwfulStarCategoryNone;
            }
        }
        HTMLElement *repliesCell = [row awful_firstNodeMatchingCachedSelector:@"td.replies"];
        if (repliesCell) {
            HTMLElement *repliesLink = [repliesCell awful_firstNodeMatchingCachedSelector:@"a"];
            thread.totalReplies = (int32_t)(repliesLink ?: repliesCell).innerHTML.integerValue;
        }
        HTMLElement *unreadLink = [row awful_firstNodeMatchingCachedSelector:@"a.count b"];
        if (unreadLink) {
            thread.seenPosts = (int32_t)(thread.totalReplies + 1 - unreadLink.innerHTML.integerValue);
        } else if ([row awful_firstNodeMatchingCachedSelector:@"a.x"]) {
            thread.seenPosts = thread.totalReplies + 1;
        } else {
            thread.seenPosts = 0;
        }
        HTMLElement *ratingImage = [row awful_firstNodeMatchingCachedSelector:@"td.rating img"];
        if (ratingImage) {
            AwfulScanner *scanner = [AwfulScanner scannerWithString:ratingImage[@"title"]];
            [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
            NSInteger numberOfVotes;
            BOOL ok = [scanner scanInteger:&numberOfVotes];
            if (ok) {
                thread.numberOfVotes = numberOfVotes;
            }
            [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
            NSDecimal average;
            ok = [scanner scanDecimal:&average];
            if (ok) {
                thread.rating = [NSDecimalNumber decimalNumberWithDecimal:average];
            }
        }
        HTMLElement *lastPostDateDiv = [row awful_firstNodeMatchingCachedSelector:@"td.lastpost div.date"];
        if (lastPostDateDiv) {
            NSDate *lastPostDate = [LastPostDateParser() dateFromString:lastPostDateDiv.innerHTML];
            if (lastPostDate) {
                thread.lastPostDate = lastPostDate;
            }
        }
        HTMLElement *lastPostAuthorLink = [row awful_firstNodeMatchingCachedSelector:@"td.lastpost a.author"];
        if (lastPostAuthorLink) {
            thread.lastPostAuthorName = lastPostAuthorLink.innerHTML;
        }
    }
    
    self.threads = threads;
}

static AwfulCompoundDateParser * LastPostDateParser(void)
{
    static AwfulCompoundDateParser *parser;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        parser = [[AwfulCompoundDateParser alloc] initWithFormats:@[ @"h:mm a MMM d, yyyy",
                                                                     @"HH:mm MMM d, yyyy" ]];
    });
    return parser;
}

@end
