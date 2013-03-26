//
//  AwfulUser.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulUser.h"
#import "AwfulDataStack.h"
#import "AwfulParsing.h"
#import "NSManagedObject+Awful.h"
#import "TFHpple.h"

@implementation AwfulUser

- (NSURL *)avatarURL
{
    if ([self.customTitle length] == 0) return nil;
    NSData *data = [self.customTitle dataUsingEncoding:NSUTF8StringEncoding];
    TFHpple *html = [[TFHpple alloc] initWithHTMLData:data];
    // The avatar is an image that's the first child of its parent, which is either a <div>, an
    // <a>, or the implied <body>.
    TFHppleElement *avatar = [html searchForSingle:@"//img[count(preceding-sibling::*) = 0 and (parent::div or parent::body or parent::a)]"];
    NSString *src = [avatar objectForKey:@"src"];
    if ([src length] == 0) return nil;
    return [NSURL URLWithString:src];
}

+ (NSSet *)keyPathsForValuesAffectingAvatarURL
{
    return [NSSet setWithObject:@"customTitle"];
}

+ (instancetype)userCreatedOrUpdatedFromJSON:(NSDictionary *)json
{
    NSString *userID = [json[@"userid"] stringValue];
    if (!userID) return nil;
    AwfulUser *user = [self firstMatchingPredicate:@"userID = %@", userID];
    if (!user) {
        user = [self insertNew];
        user.userID = userID;
    }
    user.username = Stringify(json[@"username"]);
    
    // Everything else is optional.
    if (json[@"aim"]) user.aimName = StringOrNilIfEmpty(json[@"aim"]);
    if (json[@"biography"]) user.aboutMe = StringOrNilIfEmpty(json[@"biography"]);
    if (json[@"gender"]) {
        if ([json[@"gender"] isEqual:@"F"]) user.gender = @"female";
        else if ([json[@"gender"] isEqual:@"M"]) user.gender = @"male";
        else user.gender = @"porpoise";
    }
    if (json[@"homepage"]) user.homepageURL = StringOrNilIfEmpty(json[@"homepage"]);
    if (json[@"icq"]) user.icqName = StringOrNilIfEmpty(json[@"icq"]);
    if (json[@"interests"]) user.interests = StringOrNilIfEmpty(json[@"interests"]);
    if (json[@"joindate"]) {
        user.regdate = [NSDate dateWithTimeIntervalSince1970:[json[@"joindate"] doubleValue]];
    }
    if (json[@"lastpost"]) {
        user.lastPost = [NSDate dateWithTimeIntervalSince1970:[json[@"lastpost"] doubleValue]];
    }
    if (json[@"location"]) user.location = StringOrNilIfEmpty(json[@"location"]);
    if (json[@"occupation"]) user.occupation = StringOrNilIfEmpty(json[@"occupation"]);
    if (json[@"picture"]) {
        NSString *url = StringOrNilIfEmpty(json[@"picture"]);
        if (![[NSURL URLWithString:url] host]) {
            url = [NSString stringWithFormat:@"http://forums.somethingawful.com%@", url];
        }
        user.profilePictureURL = url;
    }
    if (json[@"posts"]) user.postCount = json[@"posts"];
    if (json[@"postsperday"]) user.postRate = [json[@"postsperday"] stringValue];
    if (json[@"role"]) {
        user.administratorValue = [json[@"role"] isEqual:@"A"];
        user.moderatorValue = [json[@"role"] isEqual:@"M"];
    }
    user.canReceivePrivateMessagesValue = [json[@"receivepm"] boolValue];
    if (json[@"usertitle"]) user.customTitle = json[@"usertitle"];
    if (json[@"yahoo"]) user.yahooName = StringOrNilIfEmpty(json[@"yahoo"]);
    return user;
}

static id StringOrNilIfEmpty(const id obj)
{
    if (!obj || [obj isEqual:[NSNull null]]) return nil;
    if ([obj respondsToSelector:@selector(length)] && [obj length] == 0) return nil;
    return Stringify(obj);
}

static NSString * Stringify(const id obj)
{
    if (!obj || [obj isEqual:[NSNull null]]) return obj;
    if ([obj isKindOfClass:[NSString class]]) return obj;
    if ([obj respondsToSelector:@selector(stringValue)]) return [obj stringValue];
    return [obj description];
}

@end
