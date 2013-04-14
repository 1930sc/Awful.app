// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulPost.h instead.

#import <CoreData/CoreData.h>


extern const struct AwfulPostAttributes {
	__unsafe_unretained NSString *attachmentID;
	__unsafe_unretained NSString *editDate;
	__unsafe_unretained NSString *editable;
	__unsafe_unretained NSString *innerHTML;
	__unsafe_unretained NSString *postDate;
	__unsafe_unretained NSString *postID;
	__unsafe_unretained NSString *singleUserIndex;
	__unsafe_unretained NSString *threadIndex;
} AwfulPostAttributes;

extern const struct AwfulPostRelationships {
	__unsafe_unretained NSString *author;
	__unsafe_unretained NSString *editor;
	__unsafe_unretained NSString *thread;
} AwfulPostRelationships;

extern const struct AwfulPostFetchedProperties {
} AwfulPostFetchedProperties;

@class AwfulUser;
@class AwfulUser;
@class AwfulThread;










@interface AwfulPostID : NSManagedObjectID {}
@end

@interface _AwfulPost : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (AwfulPostID*)objectID;





@property (nonatomic, strong) NSString* attachmentID;



//- (BOOL)validateAttachmentID:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSDate* editDate;



//- (BOOL)validateEditDate:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSNumber* editable;



@property BOOL editableValue;
- (BOOL)editableValue;
- (void)setEditableValue:(BOOL)value_;

//- (BOOL)validateEditable:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* innerHTML;



//- (BOOL)validateInnerHTML:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSDate* postDate;



//- (BOOL)validatePostDate:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* postID;



//- (BOOL)validatePostID:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSNumber* singleUserIndex;



@property int32_t singleUserIndexValue;
- (int32_t)singleUserIndexValue;
- (void)setSingleUserIndexValue:(int32_t)value_;

//- (BOOL)validateSingleUserIndex:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSNumber* threadIndex;



@property int32_t threadIndexValue;
- (int32_t)threadIndexValue;
- (void)setThreadIndexValue:(int32_t)value_;

//- (BOOL)validateThreadIndex:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) AwfulUser *author;

//- (BOOL)validateAuthor:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) AwfulUser *editor;

//- (BOOL)validateEditor:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) AwfulThread *thread;

//- (BOOL)validateThread:(id*)value_ error:(NSError**)error_;





@end

@interface _AwfulPost (CoreDataGeneratedAccessors)

@end

@interface _AwfulPost (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveAttachmentID;
- (void)setPrimitiveAttachmentID:(NSString*)value;




- (NSDate*)primitiveEditDate;
- (void)setPrimitiveEditDate:(NSDate*)value;




- (NSNumber*)primitiveEditable;
- (void)setPrimitiveEditable:(NSNumber*)value;

- (BOOL)primitiveEditableValue;
- (void)setPrimitiveEditableValue:(BOOL)value_;




- (NSString*)primitiveInnerHTML;
- (void)setPrimitiveInnerHTML:(NSString*)value;




- (NSDate*)primitivePostDate;
- (void)setPrimitivePostDate:(NSDate*)value;




- (NSString*)primitivePostID;
- (void)setPrimitivePostID:(NSString*)value;




- (NSNumber*)primitiveSingleUserIndex;
- (void)setPrimitiveSingleUserIndex:(NSNumber*)value;

- (int32_t)primitiveSingleUserIndexValue;
- (void)setPrimitiveSingleUserIndexValue:(int32_t)value_;




- (NSNumber*)primitiveThreadIndex;
- (void)setPrimitiveThreadIndex:(NSNumber*)value;

- (int32_t)primitiveThreadIndexValue;
- (void)setPrimitiveThreadIndexValue:(int32_t)value_;





- (AwfulUser*)primitiveAuthor;
- (void)setPrimitiveAuthor:(AwfulUser*)value;



- (AwfulUser*)primitiveEditor;
- (void)setPrimitiveEditor:(AwfulUser*)value;



- (AwfulThread*)primitiveThread;
- (void)setPrimitiveThread:(AwfulThread*)value;


@end
