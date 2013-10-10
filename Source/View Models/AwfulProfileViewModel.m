//  AwfulProfileViewModel.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulProfileViewModel.h"
#import "AwfulDateFormatters.h"
#import "AwfulSettings.h"

@interface AwfulProfileViewModel ()

@property (nonatomic) AwfulUser *user;

@end

@implementation AwfulProfileViewModel

+ (id)newWithUser:(AwfulUser *)user
{
    AwfulProfileViewModel *viewModel = [self new];
    viewModel.user = user;
    return viewModel;
}

- (NSDateFormatter *)regDateFormat
{
    return AwfulDateFormatters.formatters.regDateFormatter;
}

- (NSDateFormatter *)lastPostDateFormat
{
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = self.regDateFormat.locale;
    formatter.dateFormat = @"MMM d, yyyy HH:mm";
    return formatter;
}

- (NSArray *)contactInfo
{
    NSMutableArray *contactInfo = [NSMutableArray new];
    if (self.user.canReceivePrivateMessages && [AwfulSettings settings].canSendPrivateMessages) {
        [contactInfo addObject:@{ @"service": AwfulServicePrivateMessage,
                                  @"address": self.user.username }];
    }
    if ([self.user.aimName length] > 0) {
        [contactInfo addObject:@{ @"service": @"AIM", @"address": self.user.aimName }];
    }
    if ([self.user.icqName length] > 0) {
        [contactInfo addObject:@{ @"service": @"ICQ", @"address": self.user.icqName }];
    }
    if ([self.user.yahooName length] > 0) {
        [contactInfo addObject:@{ @"service": @"Yahoo!", @"address": self.user.yahooName }];
    }
    if (self.user.homepageURL) {
        [contactInfo addObject:@{ @"service": AwfulServiceHomepage,
                                  @"address": self.user.homepageURL }];
    }
    return contactInfo;
}

- (NSArray *)additionalInfo
{
    NSMutableArray *additionalInfo = [NSMutableArray new];
    if ([self.user.location length] > 0) {
        [additionalInfo addObject:@{ @"kind": @"Location", @"info": self.user.location }];
    }
    if ([self.user.interests length] > 0) {
        [additionalInfo addObject:@{ @"kind": @"Interests", @"info": self.user.interests }];
    }
    if ([self.user.occupation length] > 0) {
        [additionalInfo addObject:@{ @"kind": @"Occupation", @"info": self.user.occupation }];
    }
    return additionalInfo;
}

- (NSString *)customTitle
{
    if ([self.user.customTitleHTML isEqualToString:@"<br/>"]) {
        return nil;
    }
    return self.user.customTitleHTML;
}

- (NSString *)gender
{
    return self.user.gender ?: @"porpoise";
}

- (id)valueForUndefinedKey:(NSString *)key
{
    return [self.user valueForKey:key];
}

@end


NSString * const AwfulServiceHomepage = @"Homepage";
NSString * const AwfulServicePrivateMessage = @"Private Message";
