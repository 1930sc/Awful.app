//
//  ImgurHTTPClient.h
//  Awful
//
//  Created by Nolan Waite on 2012-10-06.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AFNetworking.h"

// Client for the Imgur Anonymous API, version 3.
@interface ImgurHTTPClient : AFHTTPClient

// Singleton.
+ (instancetype)client;

// images   - an array of UIImage instances to upload. Uploaded images may be downscaled.
// callback - a block that takes two arguments and returns nothing:
//              error - an NSError instance on failure, or nil if successful.
//              urls  - an array of NSURL instances pointing to the uploaded images if successful,
//                      or nil on failure.
- (void)uploadImages:(NSArray *)images andThen:(void(^)(NSError *error, NSArray *urls))callback;

@end

extern NSString * const ImgurAPIErrorDomain;

enum {
    ImgurAPIErrorUnknown = -1,
    ImgurAPIErrorRateLimitExceeded = -1000,
    ImgurAPIErrorInvalidImage = -1001,
    ImgurAPIErrorActionNotSupported = -1002,
    ImgurAPIErrorUnexpectedRemoteError = -1003,
    ImgurAPIErrorMissingImageURL = -1004,
};
