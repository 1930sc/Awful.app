//  AwfulScraper.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScraper.h"
#import <AwfulCore/AwfulCore-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@implementation AwfulScraper

+ (instancetype)scrapeNode:(HTMLNode *)node intoManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    AwfulScraper *scraper = [[self alloc] initWithNode:node managedObjectContext:managedObjectContext];
    [scraper scrape];
    return scraper;
}

- (instancetype)initWithNode:(HTMLNode *)node managedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    if ((self = [super init])) {
        _node = node;
        _managedObjectContext = managedObjectContext;
    }
    return self;
}

- (instancetype)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"-init is not a valid initializer for the class AwfulScraper"
                                 userInfo:nil];
    return nil;
}


- (void)scrape
{
    HTMLElement *body = [self.node firstNodeMatchingSelector:@"body.database_error"];
    if (body) {
        NSString *reason = [[body firstNodeMatchingSelector:@"#msg h1"].textContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (reason.length == 0) reason = @"Database unavailable";
        self.error = [NSError errorWithDomain:AwfulCoreError.domain code:AwfulCoreError.databaseUnavailable userInfo:@{ NSLocalizedDescriptionKey: reason }];
    }
}

@end

NS_ASSUME_NONNULL_END
