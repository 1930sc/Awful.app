//  AwfulDateFormatters.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>

// Data-specific date formatters that appear on many screens.
@interface AwfulDateFormatters : NSObject

// Singleton instance.
+ (instancetype)formatters;

@property (readonly, nonatomic) NSDateFormatter *postDateFormatter;
@property (readonly, nonatomic) NSDateFormatter *regDateFormatter;

@end
