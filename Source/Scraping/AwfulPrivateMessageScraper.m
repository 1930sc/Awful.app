//  AwfulPrivateMessageScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPrivateMessageScraper.h"
#import "AwfulAuthorScraper.h"
#import "AwfulCompoundDateParser.h"
#import "AwfulErrorDomain.h"
#import "AwfulScanner.h"
#import "HTMLNode+CachedSelector.h"
#import <HTMLReader/HTMLTextNode.h>
#import "NSURL+QueryDictionary.h"

@interface AwfulPrivateMessageScraper ()

@property (strong, nonatomic) AwfulPrivateMessage *privateMessage;

@end

@implementation AwfulPrivateMessageScraper

- (void)scrape
{
    NSString *messageID;
    HTMLElement *replyLink = [self.node awful_firstNodeMatchingCachedSelector:@"div.buttons a"];
    NSURL *replyLinkURL = [NSURL URLWithString:replyLink[@"href"]];
    messageID = replyLinkURL.queryDictionary[@"privatemessageid"];
    if (messageID.length == 0) {
        NSString *message = @"Failed parsing private message; could not find messageID";
        self.error = [NSError errorWithDomain:AwfulErrorDomain code:AwfulErrorCodes.parseError userInfo:@{ NSLocalizedDescriptionKey: message }];
        return;
    }
    
    AwfulPrivateMessage *message = [AwfulPrivateMessage firstOrNewPrivateMessageWithMessageID:messageID inManagedObjectContext:self.managedObjectContext];
    
    HTMLElement *breadcrumbs = [self.node awful_firstNodeMatchingCachedSelector:@"div.breadcrumbs b"];
    HTMLTextNode *subjectText = breadcrumbs.children.lastObject;
    if ([subjectText isKindOfClass:[HTMLTextNode class]]) {
        message.subject = subjectText.data;
    }
    
    HTMLElement *postDateCell = [self.node awful_firstNodeMatchingCachedSelector:@"td.postdate"];
    HTMLElement *iconImage = [postDateCell awful_firstNodeMatchingCachedSelector:@"img"];
    if (iconImage) {
        NSString *src = iconImage[@"src"];
        message.seen = [src rangeOfString:@"newpm"].location == NSNotFound;
        message.replied = [src rangeOfString:@"replied"].location != NSNotFound;
        message.forwarded = [src rangeOfString:@"forwarded"].location != NSNotFound;
    }
    
    NSString *sentDateText = [postDateCell.children.lastObject textContent];
    NSDate *sentDate = [[AwfulCompoundDateParser postDateParser] dateFromString:sentDateText];
    if (sentDate) {
        message.sentDate = sentDate;
    }
    
    HTMLElement *postBodyCell = [self.node awful_firstNodeMatchingCachedSelector:@"td.postbody"];
    if (postBodyCell) {
        message.innerHTML = postBodyCell.innerHTML;
    }
    
    AwfulAuthorScraper *authorScraper = [AwfulAuthorScraper scrapeNode:self.node intoManagedObjectContext:self.managedObjectContext];
    AwfulUser *from = authorScraper.author;
    if (from) {
        message.from = from;
    }
    self.privateMessage = message;
}

@end
