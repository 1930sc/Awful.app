//
//  AwfulActions.h
//  Awful
//
//  Created by Regular Berry on 6/23/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AwfulActions : NSObject <UIActionSheetDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) NSMutableArray *titles;
@property (nonatomic, weak) UIViewController *viewController;

-(void)show;
- (UIActionSheet *) getActionSheet;
-(NSString *)getOverallTitle;
-(BOOL)isCancelled : (int)index;

@end
