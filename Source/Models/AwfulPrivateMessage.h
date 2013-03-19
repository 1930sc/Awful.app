//
//  AwfulPrivateMessage.h
//  Awful
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "_AwfulPrivateMessage.h"
@class PrivateMessageParsedInfo;
@class PrivateMessageFolderParsedInfo;

@interface AwfulPrivateMessage : _AwfulPrivateMessage {}

@property (readonly, nonatomic) NSString *firstIconName;

+ (instancetype)privateMessageWithParsedInfo:(PrivateMessageParsedInfo *)info;

+ (NSArray *)privateMessagesWithFolderParsedInfo:(PrivateMessageFolderParsedInfo *)info;

@end
