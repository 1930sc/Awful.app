//  AwfulPrivateMessageFolderScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPrivateMessageFolderScraper.h"
#import "AwfulCompoundDateParser.h"
#import "AwfulErrorDomain.h"
#import "GTMNSString+HTML.h"
#import "HTMLNode+CachedSelector.h"
#import "NSURL+QueryDictionary.h"

@interface AwfulPrivateMessageFolderScraper ()

@property (copy, nonatomic) NSArray *messages;

@end

@implementation AwfulPrivateMessageFolderScraper

- (void)scrape
{
    NSMutableArray *messages = [NSMutableArray new];
    NSArray *rows = [self.node awful_nodesMatchingCachedSelector:@"table.standard tbody tr"];
    for (HTMLElement *row in rows) {
        HTMLElement *titleLink = [row awful_firstNodeMatchingCachedSelector:@"td.title a"];
        NSString *messageID; {
            NSURL *URL = [NSURL URLWithString:titleLink[@"href"]];
            messageID = URL.queryDictionary[@"privatemessageid"];
        }
        if (messageID.length == 0) {
            NSString *message = @"Failed to parse message in folder; could not find message ID";
            self.error = [NSError errorWithDomain:AwfulErrorDomain code:AwfulErrorCodes.parseError userInfo:@{ NSLocalizedDescriptionKey: message }];
            continue;
        }
        
        AwfulPrivateMessage *message = [AwfulPrivateMessage firstOrNewPrivateMessageWithMessageID:messageID
                                                                           inManagedObjectContext:self.managedObjectContext];
        message.subject = [titleLink.innerHTML gtm_stringByUnescapingFromHTML];
        
        {{
            HTMLElement *seenImage = [row awful_firstNodeMatchingCachedSelector:@"td.status img"];
            NSString *src = seenImage[@"src"];
            message.seen = [src rangeOfString:@"newpm"].location == NSNotFound;
            message.replied = [src rangeOfString:@"replied"].location != NSNotFound;
            message.forwarded = [src rangeOfString:@"forwarded"].location != NSNotFound;
        }}
        
        {{
            HTMLElement *threadTagImage = [row awful_firstNodeMatchingCachedSelector:@"td.icon img"];
            if (threadTagImage) {
                NSURL *URL = [NSURL URLWithString:threadTagImage[@"src"]];
                message.threadTag = [AwfulThreadTag firstOrNewThreadTagWithThreadTagID:nil threadTagURL:URL inManagedObjectContext:self.managedObjectContext];
            } else {
                message.threadTag = nil;
            }
        }}
        
        {{
            HTMLElement *fromCell = [row awful_firstNodeMatchingCachedSelector:@"td.sender"];
            NSString *fromUsername = [fromCell.innerHTML gtm_stringByUnescapingFromHTML];
            if (fromUsername.length > 0) {
                message.from = [AwfulUser firstOrNewUserWithUserID:nil username:fromUsername inManagedObjectContext:self.managedObjectContext];
            }
        }}
        
        {{
            HTMLElement *sentDateCell = [row awful_firstNodeMatchingCachedSelector:@"td.date"];
            NSDate *sentDate = [SentDateParser() dateFromString:sentDateCell.innerHTML];
            if (sentDate) {
                message.sentDate = sentDate;
            }
        }}
        
        [messages addObject:message];
    }
    self.messages = messages;
}

static AwfulCompoundDateParser * SentDateParser(void)
{
    static AwfulCompoundDateParser *parser;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        parser = [[AwfulCompoundDateParser alloc] initWithFormats:@[ @"MMM d, yyyy 'at' h:mm a",
                                                                     @"MMMM d, yyyy 'at' HH:mm" ]];
    });
    return parser;
}

@end
