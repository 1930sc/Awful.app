//
//  AwfulActions.m
//  Awful
//
//  Created by Regular Berry on 6/23/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulActions.h"
#import "AwfulAppDelegate.h"

@implementation AwfulActions

@synthesize titles = _titles;
@synthesize viewController = _viewController;

-(id)init
{
    if((self=[super init])) {
        _titles = [[NSMutableArray alloc] init];
    }
    return self;
}

-(NSString *)getOverallTitle
{
    return @"Actions";
}

-(void)show
{
    [[self getActionSheet] showFromToolbar:self.viewController.navigationController.toolbar];
}

- (UIActionSheet *) getActionSheet
{
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:[self getOverallTitle] delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    for(NSString *title in self.titles) {
        [sheet addButtonWithTitle:title];
    }
    [sheet addButtonWithTitle:@"Cancel"];
    sheet.cancelButtonIndex = [self.titles count];
    
    return sheet;
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    [self actionSheet:nil clickedButtonAtIndex:buttonIndex-1];
}

-(BOOL)isCancelled : (int)index
{
    return index == [self.titles count] || index == -1;
}

@end
