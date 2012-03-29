//
//  SALR.m
//  Awful
//
//  Created by Scott Ferguson on 9/14/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulConfig.h"
#import "SALR.h"
#import "SBJson.h"
#import "AwfulUser.h"
#import "AwfulUser+AwfulMethods.h"

@implementation SALR

+ (NSString *)config {
    NSMutableDictionary *config = [[NSMutableDictionary alloc] init];
    
    AwfulUser *user = [AwfulUser currentUser];
    if(user.userName != nil) {
        [config setObject:user.userName forKey:@"username"];
    } else {
        return @"";
    }
    [config setObject:[AwfulConfig highlightOwnMentions] forKey:@"highlightUsername"];
    [config setObject:[AwfulConfig highlightOwnQuotes] forKey:@"highlightUserQuote"];
    [config setObject:@"#a2cd5a" forKey:@"userQuote"];
    [config setObject:@"#9933ff" forKey:@"usernameHighlight"];

    SBJsonWriter *jsonWriter = [SBJsonWriter new];
    NSString *result = [jsonWriter stringWithObject:config];
    
    return result;
}

@end
