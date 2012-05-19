//
//  AwfulThread.h
//  Awful
//
//  Created by Sean Berry on 3/30/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class AwfulForum;

@interface AwfulThread : NSManagedObject

@property (nonatomic, retain) NSString * authorName;
@property (nonatomic, retain) NSNumber * isBookmarked;
@property (nonatomic, retain) NSNumber * isLocked;
@property (nonatomic, retain) NSString * lastPostAuthorName;
@property (nonatomic, retain) NSDate * lastPostDate;
@property (nonatomic, retain) NSNumber * seen;
@property (nonatomic, retain) NSNumber * starCategory;
@property (nonatomic, retain) NSNumber * stickyIndex;
@property (nonatomic, retain) NSURL * threadIconImageURL;
@property (nonatomic, retain) NSURL * threadIconImageURL2;
@property (nonatomic, retain) NSString * threadID;
@property (nonatomic, retain) NSNumber * threadRating;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSNumber * totalReplies;
@property (nonatomic, retain) NSNumber * totalUnreadPosts;
@property (nonatomic, retain) AwfulForum *forum;

@end
