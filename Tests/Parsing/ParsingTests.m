//
//  ParsingTests.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-10.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "ParsingTests.h"

@implementation ParsingTests
{
    NSData *_fixture;
}

+ (NSString *)fixtureFilename
{
    [NSException raise:NSInternalInconsistencyException
                format:@"subclasses must override %@", NSStringFromSelector(_cmd)];
    return nil;
}

- (void)setUp
{
    if (!_fixture) {
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSURL *fixtureURL = [bundle URLForResource:[[self class] fixtureFilename]
                                     withExtension:nil];
        _fixture = [NSData dataWithContentsOfURL:fixtureURL];
    }
}

@end


@implementation CoreDataParsingTests
{
    AwfulDataStack *_dataStack;
}

- (AwfulDataStack *)dataStack
{
    if (_dataStack) return _dataStack;
    NSURL *documents = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                               inDomains:NSUserDomainMask] lastObject];
    NSURL *storeURL = [documents URLByAppendingPathComponent:@"TestData.db"];
    _dataStack = [[AwfulDataStack alloc] initWithStoreURL:storeURL];
    return _dataStack;
}

- (void)tearDown
{
    [self.dataStack deleteAllDataAndResetStack];
}

@end
