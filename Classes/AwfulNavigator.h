//
//  AwfulNavigator.h
//  Awful
//
//  Created by Regular Berry on 6/21/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulHistory.h"

@class AwfulContentViewController;
@class ASIHTTPRequest;
@class AwfulRequestHandler;
@class AwfulPageCount;
@class AwfulUser;
@class AwfulNavigator;
@class AwfulActions;
@class AwfulHistoryManager;

@protocol AwfulNavigatorContent <NSObject, AwfulHistoryRecorder>

-(UIView *)getView;
-(void)setDelegate : (AwfulNavigator *)delegate;
-(void)refresh;
-(void)stop;
-(AwfulActions *)getActions;

@end

@interface AwfulNavigator : UIViewController <UINavigationControllerDelegate, UIGestureRecognizerDelegate> {
    UIToolbar *_toolbar;
    id<AwfulNavigatorContent> _contentVC;
    AwfulRequestHandler *_requestHandler;
    AwfulUser *_user;
    AwfulActions *_actions;
    AwfulHistoryManager *_historyManager;
    UIBarButtonItem *_backButton;
    UIBarButtonItem *_forwardButton;
    UIBarButtonItem *_actionButton;
}

@property (nonatomic, retain) IBOutlet UIToolbar *toolbar;
@property (nonatomic, retain) id<AwfulNavigatorContent> contentVC;
@property (nonatomic, retain) AwfulRequestHandler *requestHandler;
@property (nonatomic, retain) AwfulUser *user;
@property (nonatomic, retain) AwfulActions *actions;
@property (nonatomic, retain) AwfulHistoryManager *historyManager;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *backButton;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *forwardButton;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *actionButton;

-(void)loadContentVC : (id<AwfulNavigatorContent>)content;

-(void)refresh;
-(void)stop;
-(void)swapToRefreshButton;
-(void)swapToStopButton;
-(void)updateHistoryButtons;
-(IBAction)tappedBack;
-(IBAction)tappedForward;
-(IBAction)tappedForumsList;
-(IBAction)tappedAction;
-(IBAction)tappedBookmarks;
-(IBAction)tappedMore;

-(void)tappedThreeTimes : (UITapGestureRecognizer *)gesture;

-(void)callBookmarksRefresh;

@end

AwfulNavigator *getNavigator();
void loadContentVC(id<AwfulNavigatorContent> content);
void loadRequest(ASIHTTPRequest *req);
void loadRequestAndWait(ASIHTTPRequest *req);
