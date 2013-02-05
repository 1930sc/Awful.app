//
//  AwfulPost.m
//  Awful
//
//  Created by Nolan Waite on 12-10-26.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPost.h"
#import "AwfulDataStack.h"
#import "AwfulForum.h"
#import "AwfulParsing.h"
#import "AwfulThread.h"
#import "AwfulUser.h"
#import "GTMNSString+HTML.h"
#import "NSManagedObject+Awful.h"

@implementation AwfulPost

+ (NSArray *)postsCreatedOrUpdatedFromPageInfo:(PageParsedInfo *)pageInfo
{
    if ([pageInfo.forumID length] == 0 || [pageInfo.threadID length] == 0) return nil;
    AwfulForum *forum = [AwfulForum firstMatchingPredicate:@"forumID = %@", pageInfo.forumID];
    if (!forum) {
        forum = [AwfulForum insertNew];
        forum.forumID = pageInfo.forumID;
    }
    forum.name = pageInfo.forumName;
    AwfulThread *thread = [AwfulThread firstMatchingPredicate:@"threadID = %@", pageInfo.threadID];
    if (!thread) {
        thread = [AwfulThread insertNew];
        thread.threadID = pageInfo.threadID;
    }
    thread.forum = forum;
    thread.title = pageInfo.threadTitle;
    thread.isBookmarkedValue = pageInfo.threadBookmarked;
    thread.isLockedValue = pageInfo.threadLocked;
    thread.numberOfPagesValue = pageInfo.pagesInThread;
    
    NSArray *allPosts = [thread.posts allObjects];
    NSArray *allPostIDs = [allPosts valueForKey:@"postID"];
    NSDictionary *existingPosts = [NSDictionary dictionaryWithObjects:allPosts forKeys:allPostIDs];
    NSArray *allAuthorNames = [pageInfo.posts valueForKeyPath:@"author.username"];
    NSMutableDictionary *existingUsers = [NSMutableDictionary new];
    for (AwfulUser *user in [AwfulUser fetchAllMatchingPredicate:@"username IN %@", allAuthorNames]) {
        existingUsers[user.username] = user;
    }
    NSMutableArray *posts = [NSMutableArray new];
    for (NSUInteger i = 0; i < [pageInfo.posts count]; i++) {
        PostParsedInfo *postInfo = pageInfo.posts[i];
        AwfulPost *post = existingPosts[postInfo.postID];
        if (!post) {
            post = [AwfulPost insertNew];
            post.thread = thread;
        }
        [postInfo applyToObject:post];
        if ([postInfo.threadIndex length] > 0) {
            post.threadIndexValue = [postInfo.threadIndex integerValue];
        } else {
            post.threadIndexValue = (pageInfo.pageNumber - 1) * 40 + i + 1;
        }
        if (!post.author) {
            post.author = existingUsers[postInfo.author.username] ?: [AwfulUser insertNew];
        }
        [postInfo.author applyToObject:post.author];
        post.author.avatarURL = [postInfo.author.avatarURL absoluteString];
        existingUsers[post.author.username] = post.author;
        [posts addObject:post];
        if (postInfo.author.originalPoster) {
            thread.author = post.author;
        }
    }
    [posts setValue:@(pageInfo.pageNumber) forKey:AwfulPostAttributes.threadPage];
    if (pageInfo.pageNumber == thread.numberOfPagesValue) {
        thread.lastPostAuthorName = [[posts lastObject] author].username;
        thread.lastPostDate = [[posts lastObject] postDate];
    }
    [[AwfulDataStack sharedDataStack] save];
    return posts;
}

+ (NSArray *)postsCreatedOrUpdatedFromJSON:(NSDictionary *)json
{
    NSString *forumID = [json[@"forumid"] stringValue];
    AwfulForum *forum = [AwfulForum firstMatchingPredicate:@"forumID = %@", forumID];
    if (!forum) {
        forum = [AwfulForum insertNew];
        forum.forumID = forumID;
    }
    NSString *threadID = [json[@"thread_info"][@"threadid"] stringValue];
    AwfulThread *thread = [AwfulThread firstMatchingPredicate:@"threadID = %@", threadID];
    if (!thread) {
        thread = [AwfulThread insertNew];
        thread.threadID = threadID;
    }
    thread.title = [json[@"thread_info"][@"title"] gtm_stringByUnescapingFromHTML];
    thread.archivedValue = [json[@"archived"] boolValue];
    if (![json[@"thread_icon"] isEqual:[NSNull null]]) {
        thread.threadIconImageURL = [NSURL URLWithString:json[@"thread_icon"][@"iconpath"]];
    }
    thread.forum = forum;
    
    NSArray *postIDs = [json[@"posts"] allKeys];
    NSMutableDictionary *existingPosts = [NSMutableDictionary new];
    for (AwfulPost *post in [AwfulPost fetchAllMatchingPredicate:@"postID IN %@", postIDs]) {
        existingPosts[post.postID] = post;
    }
    for (NSString *postID in json[@"posts"]) {
        NSDictionary *info = json[@"posts"][postID];
        AwfulPost *post = existingPosts[postID] ?: [AwfulPost insertNew];
        post.postID = postID;
        post.innerHTML = info[@"message"];
        post.postDate = [NSDate dateWithTimeIntervalSince1970:[info[@"date"] doubleValue]];
        post.thread = thread;
        post.threadIndex = info[@"post_index"];
        post.threadPage = json[@"page"][0];
        // TODO attachments (no longer built into markup)
        // TODO edits (ditto)
        
        NSString *userID = [info[@"userid"] stringValue];
        AwfulUser *author = [AwfulUser firstMatchingPredicate:@"userID = %@", userID];
        if (!author) {
            author = [AwfulUser insertNew];
            author.userID = userID;
        }
        NSDictionary *authorInfo = json[@"userids"][userID];
        author.administratorValue = [authorInfo[@"role"] isEqual:@"A"];
        author.customTitle = authorInfo[@"usertitle"];
        author.moderatorValue = [authorInfo[@"role"] isEqual:@"M"];
        author.regdate = [NSDate dateWithTimeIntervalSince1970:[authorInfo[@"joindate"] doubleValue]];
        author.username = authorInfo[@"username"];
        post.author = author;
        if ([info[@"op"] boolValue]) {
            thread.author = post.author;
        }
        
        existingPosts[post.postID] = post;
    }
    
    [[AwfulDataStack sharedDataStack] save];
    return [existingPosts allValues];
}

@end
