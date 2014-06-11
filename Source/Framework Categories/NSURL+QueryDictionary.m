//  NSURL+QueryDictionary.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "NSURL+QueryDictionary.h"

@implementation NSURL (QueryDictionary)

- (NSDictionary *)queryDictionary
{
    NSMutableDictionary *queryDictionary = [NSMutableDictionary new];
    for (NSString *pair in [[self query] componentsSeparatedByString:@"&"]) {
        if (pair.length == 0) continue;
        NSArray *keyAndValue = [pair componentsSeparatedByString:@"="];
        queryDictionary[keyAndValue[0]] = keyAndValue[1];
    }
    return queryDictionary;
}

@end
