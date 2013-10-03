//  AwfulBookmarksController.h
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadListController.h"

@interface AwfulBookmarksController : AwfulThreadListController

// Designated initializer.
- (id)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end
