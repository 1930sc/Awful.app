//  AwfulTheme.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulTheme.h"

@implementation AwfulTheme

- (id)initWithName:(NSString *)name dictionary:(NSDictionary *)dictionary
{
    if (!(self = [super init])) return nil;
    _name = [name copy];
    _dictionary = [dictionary copy];
    return self;
}

- (id)objectForKey:(id)key
{
    return _dictionary[key] ?: [self.parentTheme objectForKey:key];
}

- (id)objectForKeyedSubscript:(NSString *)key
{
    if ([key hasSuffix:@"Color"]) {
        return [self colorForKey:key];
    }
    return [self objectForKey:key];
}

- (UIColor *)colorForKey:(NSString *)key
{
    NSMutableString *hexString = [NSMutableString stringWithString:[self objectForKey:key]];
    [hexString replaceOccurrencesOfString:@"#" withString:@"" options:0 range:NSMakeRange(0, hexString.length)];
    CFStringTrimWhitespace((__bridge CFMutableStringRef)hexString);
    
    unsigned int red, green, blue, alpha = 255;
    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(0, 2)]] scanHexInt:&red];
    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(2, 2)]] scanHexInt:&green];
    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(4, 2)]] scanHexInt:&blue];
    if (hexString.length > 6) {
        [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(6, 2)]] scanHexInt:&alpha];
    }
    return [UIColor colorWithRed:(red / 255.) green:(green / 255.) blue:(blue / 255.) alpha:(alpha / 255.)];
}

@end
