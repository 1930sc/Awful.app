//
//  AwfulPage.h
//  Awful
//
//  Created by Sean Berry on 7/29/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulThread.h"
#import "AwfulPost.h"
#import "TFHpple.h"
#import "AwfulPostBoxController.h"
#import "AwfulHistory.h"
#import "PullRefreshTableViewController.h"
#import "AwfulNavigator.h"
#import "JSBridgeWebView.h"

typedef enum {
    AwfulPageDestinationTypeFirst,
    AwfulPageDestinationTypeLast,
    AwfulPageDestinationTypeNewpost,
    AwfulPageDestinationTypeSpecific
} AwfulPageDestinationType;

@class AwfulPageCount;

@interface AwfulPage : UIViewController <AwfulNavigatorContent, UIWebViewDelegate, AwfulHistoryRecorder, UIGestureRecognizerDelegate, JSBridgeWebViewDelegate> {
    AwfulThread *_thread;
    NSString *_url;
    
    NSMutableArray *_allRawPosts;
    
    BOOL _isBookmarked;
    BOOL _shouldScrollToBottom;
    NSString *_scrollToPostID;
    
    AwfulNavigator *_delegate;
    AwfulPageCount *_pages;
    UILabel *_pagesLabel;
    UILabel *_threadTitleLabel;
    UIButton *_forumButton;
    
    //JSBridgeWebView *_webView;
}

@property (nonatomic, retain) AwfulThread *thread;
@property (nonatomic, retain) NSString *url;

@property (nonatomic, retain) NSMutableArray *allRawPosts;

@property BOOL isBookmarked;
@property BOOL shouldScrollToBottom;
@property (nonatomic, retain) NSString *scrollToPostID;

@property (nonatomic, assign) AwfulNavigator *delegate;
@property (nonatomic, retain) AwfulPageCount *pages;
@property (nonatomic, retain) UILabel *pagesLabel;
@property (nonatomic, retain) UILabel *threadTitleLabel;
@property (nonatomic, retain) IBOutlet UIButton *forumButton;

//@property (nonatomic, retain) JSBridgeWebView *webView;

-(id)initWithAwfulThread : (AwfulThread *)thread startAt : (AwfulPageDestinationType)thread_pos;
-(id)initWithAwfulThread : (AwfulThread *)thread pageNum : (int)page_num;
-(id)initWithAwfulThread : (AwfulThread *)thread startAt : (AwfulPageDestinationType)thread_pos pageNum : (int)page_num;
-(void)acceptPosts : (NSMutableArray *)posts;

-(NSString *)getURLSuffix;

-(void)hardRefresh;
-(void)setThreadTitle : (NSString *)in_title;
-(void)tappedTitle : (UITapGestureRecognizer *)tapper;
-(IBAction)tappedForumButton;

-(void)scrollToSpecifiedPost;

-(void)setWebView : (JSBridgeWebView *)webView;
-(void)loadOlderPosts;
-(void)nextPage;
-(void)prevPage;

-(void)heldPost:(UILongPressGestureRecognizer *)gestureRecognizer;
-(void)scrollToPost : (NSString *)post_id;

@end

float getWidth();
