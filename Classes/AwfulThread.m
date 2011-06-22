//
//  AwfulThread.m
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThread.h"
#import "AwfulForum.h"
#import "TFHpple.h"
#import "XPathQuery.h"

@implementation AwfulThread

@synthesize threadID = _threadID;
@synthesize title = _title;
@synthesize totalUnreadPosts = _totalUnreadPosts;
@synthesize totalReplies = _totalReplies;
@synthesize threadRating = _threadRating;
@synthesize starCategory = _starCategory;
@synthesize iconURL = _iconURL;
@synthesize authorName = _authorName;
@synthesize lastPostAuthorName = _lastPostAuthorName;
@synthesize seen = _seen;
@synthesize isStickied = _isStickied;
@synthesize isLocked = _isLocked;
@synthesize forum = _forum;

-(id)init
{
    _threadRating = NSNotFound;
    _starCategory = AwfulStarCategoryNone;
    _seen = NO;
    _isStickied = NO;
    _isLocked = NO;
    _totalUnreadPosts = -1;
    
    return self;
}

-(void)dealloc
{
    [_threadID release];
    [_title release];
    [_iconURL release];
    [_authorName release];
    [_lastPostAuthorName release];
    [_forum release];
    [super dealloc];
}

- (id)initWithCoder:(NSCoder *)decoder 
{
	if ((self=[super init])) {
		self.threadID = [decoder decodeObjectForKey:@"threadID"];
		self.title = [decoder decodeObjectForKey:@"title"];
		self.iconURL = [decoder decodeObjectForKey:@"iconURL"];
        self.authorName = [decoder decodeObjectForKey:@"authorName"];
        self.lastPostAuthorName = [decoder decodeObjectForKey:@"lastPostAuthorName"];
        
        //NSString *forum_id = [decoder decodeObjectForKey:@"forumID"];
        
        // TODO grab forum from forum_id
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeObject:self.threadID forKey:@"threadID"];
    [encoder encodeObject:self.title forKey:@"title"];
    [encoder encodeObject:self.iconURL forKey:@"iconURL"];
    [encoder encodeObject:self.authorName forKey:@"authorName"];
    [encoder encodeObject:self.lastPostAuthorName forKey:@"lastPostAuthorName"];
    
    // TODO save forum id
}

@end
