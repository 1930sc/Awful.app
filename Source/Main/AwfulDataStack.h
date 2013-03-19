//
//  AwfulDataStack.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import <Foundation/Foundation.h>

typedef enum {
    AwfulDataStackInitFailureAbort,
    AwfulDataStackInitFailureDelete
} AwfulDataStackInitFailureAction;


@interface AwfulDataStack : NSObject

- (id)initWithStoreURL:(NSURL *)storeURL;

+ (AwfulDataStack *)sharedDataStack;

@property (readonly, strong, nonatomic) NSManagedObjectContext *context;

@property (readonly, strong, nonatomic) NSManagedObjectModel *model;

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *coordinator;

@property (nonatomic) AwfulDataStackInitFailureAction initFailureAction;

- (void)save;

- (void)deleteAllDataAndResetStack;

+ (NSURL *)defaultStoreURL;

@end


// Sent after -deleteAllDataAndResetStack completes. The notification's object is the data stack.
// This might be a good time to recreate fetched results controllers or anything else that refers
// to a stack's managed object context.
extern NSString * const AwfulDataStackDidResetNotification;
