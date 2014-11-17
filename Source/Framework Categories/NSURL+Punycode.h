//  NSURL+Punycode.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;

@interface NSURL (Punycode)

// Replacement for +[NSURL URLWithString:] that handles punycode-encoded hostnames.
+ (instancetype)awful_URLWithString:(NSString *)string;

// Replacement for -[NSURL absoluteString] that decodes punycode-encoded hostnames.
- (NSString *)awful_absoluteUnicodeString;

@end
