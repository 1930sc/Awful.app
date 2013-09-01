//
//  AwfulForum.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app
//

#import "_AwfulForum.h"
#import "AwfulParsing.h"

@interface AwfulForum : _AwfulForum {}

+ (instancetype)fetchOrInsertForumWithID:(NSString *)forumID;

+ (NSArray *)updateCategoriesAndForums:(ForumHierarchyParsedInfo *)info;

@end
