//  ThreadComposeViewController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "ComposeTextViewController.h"
@class Forum;
@class Thread;

/**
 * A ThreadComposeViewController is for writing the OP of a new thread.
 */
@interface ThreadComposeViewController : ComposeTextViewController

/**
 * Returns an initialized AwfulNewThreadViewController. This is the designated initializer.
 *
 * @param forum The forum in which the new forum is posted.
 */
- (instancetype)initWithForum:(Forum *)forum;

@property (readonly, strong, nonatomic) Forum *forum;

/**
 * Returns the newly-posted thread.
 */
@property (readonly, strong, nonatomic) Thread *thread;

@end
