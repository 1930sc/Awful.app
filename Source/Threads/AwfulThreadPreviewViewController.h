//  AwfulThreadPreviewViewController.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPostPreviewViewController.h"
@class ThreadTag;

@interface AwfulThreadPreviewViewController : AwfulPostPreviewViewController

- (instancetype)initWithForum:(AwfulForum *)forum
                      subject:(NSString *)subject
                    threadTag:(ThreadTag *)threadTag
           secondaryThreadTag:(ThreadTag *)secondaryThreadTag
                       BBcode:(NSAttributedString *)BBcode NS_DESIGNATED_INITIALIZER;

@property (readonly, strong, nonatomic) AwfulForum *forum;
@property (readonly, copy, nonatomic) NSString *subject;
@property (readonly, strong, nonatomic) ThreadTag *threadTag;
@property (readonly, strong, nonatomic) ThreadTag *secondaryThreadTag;
@property (readonly, copy, nonatomic) NSAttributedString *BBcode;

@end
