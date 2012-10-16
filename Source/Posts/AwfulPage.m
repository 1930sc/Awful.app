//
//  AwfulPage.m
//  Awful
//
//  Created by Sean Berry on 7/29/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadListController.h"
#import "AwfulAppDelegate.h"
#import "AwfulPageDataController.h"
#import "AwfulPostActions.h"
#import "AwfulReplyViewController.h"
#import "AwfulSpecificPageViewController.h"
#import "AwfulThreadActions.h"
#import "AwfulThreadTitleView.h"
#import "AwfulVoteActions.h"
#import "AwfulWebViewDelegate.h"
#import "ButtonSegmentedControl.h"
#import "MWPhoto.h"
#import "MWPhotoBrowser.h"
#import "SVProgressHUD.h"

@interface AwfulPage () <AwfulWebViewDelegate, UIGestureRecognizerDelegate, UIScrollViewDelegate>

@property (nonatomic) AwfulWebViewDelegateWrapper *webViewDelegateWrapper;

@property (nonatomic) NSOperation *networkOperation;

@property (nonatomic) UIToolbar *toolbar;

@property (nonatomic) UIBarButtonItem *pagesBarButtonItem;

@property (nonatomic) ButtonSegmentedControl *pagesSegmentedControl;

@property (nonatomic) ButtonSegmentedControl *actionsSegmentedControl;

@property (nonatomic) AwfulSpecificPageViewController *specificPageController;

@property (nonatomic) UIWebView *webView;

@property (copy, nonatomic) NSString *postIDScrollDestination;

@property (nonatomic) AwfulPageDataController *dataController;

@property (nonatomic) BOOL shouldScrollToBottom;

@end


@implementation AwfulPage
{
    AwfulThread *_thread;
}

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (AwfulThread *) thread
{
    if ([_thread isFault])
    {
        NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:[AwfulThread entityName]];
        [request setPredicate:[NSPredicate predicateWithFormat:@"threadID like %@", self.threadID]];
        NSError *error;
        NSArray *results = [[AwfulDataStack sharedDataStack].context executeFetchRequest:request
                                                                                   error:&error];
        if (!results) {
            NSLog(@"error refetching thread: %@", error);
        }
        
        _thread = [results objectAtIndex:0];
    }
    return _thread;
}

- (void)setThread:(AwfulThread *)newThread
{
    if (_thread == newThread) return;

    _thread = newThread;
    self.threadID = _thread.threadID;
    if (_thread.title != nil) {
        self.title = self.thread.title;
    }
    if ([_thread.totalUnreadPosts intValue] == -1) {
        self.destinationType = AwfulPageDestinationTypeFirst;
    } else if ([_thread.totalUnreadPosts intValue] == 0) {
        self.destinationType = AwfulPageDestinationTypeLast;
            // if the last page is full, it won't work if you go for &goto=newpost, that's why I'm setting this to last page
    } else {
        self.destinationType = AwfulPageDestinationTypeNewpost;
    }
}

- (void)setDestinationType:(AwfulPageDestinationType)destinationType
{
    _destinationType = destinationType;
    self.shouldScrollToBottom = _destinationType == AwfulPageDestinationTypeLast;
}

- (void)setDataController:(AwfulPageDataController *)dataController
{
    if (_dataController == dataController) return;

    _dataController = dataController;
    self.currentPage = dataController.currentPage;
    self.numberOfPages = dataController.numberOfPages;
    [self setThreadTitle:dataController.threadTitle];
    
    self.postIDScrollDestination = [dataController calculatePostIDScrollDestination];
    self.shouldScrollToBottom = [dataController shouldScrollToBottom];
    if (self.destinationType != AwfulPageDestinationTypeNewpost) {
        self.shouldScrollToBottom = NO;
    }
    
    int numNewPosts = [_dataController numNewPostsLoaded];
    if (numNewPosts > 0 && (self.destinationType == AwfulPageDestinationTypeNewpost || self.currentPage == self.numberOfPages)) {
        int unreadPosts = [self.thread.totalUnreadPosts intValue];
        if(unreadPosts != -1) {
            unreadPosts -= numNewPosts;
            self.thread.totalUnreadPostsValue = MAX(unreadPosts, 0);
            [[AwfulDataStack sharedDataStack] save];
        }
    } else if (self.destinationType == AwfulPageDestinationTypeLast) {
        self.thread.totalUnreadPostsValue = 0;
        [[AwfulDataStack sharedDataStack] save];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:AwfulThreadDidUpdateNotification
                                                        object:self.thread];
    NSString *html = [dataController constructedPageHTML];
    [self.webView loadHTMLString:html baseURL:[[NSBundle mainBundle] resourceURL]];
    self.webView.tag = self.currentPage;
    [[NSNotificationCenter defaultCenter] postNotificationName:AwfulPageDidLoadNotification
                                                        object:self.thread
                                                      userInfo:@{ @"page" : self }];
}

- (void)setCurrentPage:(NSInteger)currentPage
{
    _currentPage = currentPage;
    [self updatePagesLabel];
}

- (void)setNumberOfPages:(NSInteger)numberOfPages
{
    _numberOfPages = numberOfPages;
    [self updatePagesLabel];
}

- (void)setThreadTitle:(NSString *)title
{
    AwfulThread *mythread = self.thread;
    mythread.title = title;
    UILabel *lab = (UILabel *)self.navigationItem.titleView;
    lab.text = title;
    lab.adjustsFontSizeToFitWidth = YES;
}

- (void)editPostWithActions:(AwfulPostActions *)actions
{
    AwfulReplyViewController *editBox = [AwfulReplyViewController new];
    editBox.post = actions.post;
    editBox.startingText = actions.postContents;
    editBox.page = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:editBox];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)quotePostWithActions:(AwfulPostActions *)actions
{
    AwfulReplyViewController *quoteBox = [AwfulReplyViewController new];
    quoteBox.thread = self.thread;
    quoteBox.startingText = actions.postContents;
    quoteBox.page = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:quoteBox];
    [self presentViewController:nav animated:YES completion:nil];
}

- (IBAction)hardRefresh
{
    if ([self.dataController.posts count] == 40) {
        self.destinationType = AwfulPageDestinationTypeSpecific;
        [self refresh];
    } else {
        self.destinationType = AwfulPageDestinationTypeNewpost;
        [self refresh];
    }
}

- (void)refresh
{
    [self loadPageNum:self.currentPage];
}

- (void)loadPageNum:(NSUInteger)pageNum
{
    // I guess the error callback doesn't necessarily get called when a network operation is 
    // cancelled, so clear the HUD when we cancel the network operation.
    [SVProgressHUD dismiss];
    [self.networkOperation cancel];
    
    [self swapToStopButton];
    [self hidePageNavigation];
    AwfulThread *myThread = self.thread;
    AwfulPageDestinationType destType = self.destinationType;
    self.networkOperation = [[AwfulHTTPClient sharedClient] pageDataForThread:myThread
                                                              destinationType:destType
                                                                      pageNum:pageNum
                                                                 onCompletion:^(AwfulPageDataController *dataController)
    {
        self.dataController = dataController;
        if (self.destinationType == AwfulPageDestinationTypeSpecific) {
            self.currentPage = pageNum;
        }
        [self updatePagesLabel];
        [self updateBookmarked];
        [self swapToRefreshButton];
    } onError:^(NSError *error)
    {
        [self swapToRefreshButton];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed"
                                                        message:error.localizedDescription
                                                       delegate:nil
                                              cancelButtonTitle:@"Ok"
                                              otherButtonTitles:nil];
        [alert show];
        [SVProgressHUD dismiss];
    }];
}

- (void)loadLastPage
{
    [self.networkOperation cancel];
    [self swapToStopButton];
    self.networkOperation = [[AwfulHTTPClient sharedClient] pageDataForThread:self.thread
                                                              destinationType:AwfulPageDestinationTypeLast
                                                                      pageNum:0
                                                                 onCompletion:^(AwfulPageDataController *dataController)
    {
        self.dataController = dataController;
        [self updatePagesLabel];
        [self updateBookmarked];
        [self swapToRefreshButton];
    } onError:^(NSError *error)
    {
        [self swapToRefreshButton];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
    }];
}

- (void)stop
{
    [self.networkOperation cancel];
    [self swapToRefreshButton];
    [SVProgressHUD dismiss];
    [self.webView stopLoading];
}

- (void)loadOlderPosts
{
    NSString *html = [self.dataController constructedPageHTMLWithAllPosts];
    [self.webView loadHTMLString:html
                         baseURL:[NSURL URLWithString:@"http://forums.somethingawful.com"]];
}

- (void)heldPost:(UILongPressGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state != UIGestureRecognizerStateBegan) return;
    CGPoint p = [gestureRecognizer locationInView:self.webView];
    NSString *js = [NSString stringWithFormat:@"imageURLAtPosition(%f, %f)", p.x, p.y];
    NSString *src = [self.webView stringByEvaluatingJavaScriptFromString:js];
    if ([src length]) {
        NSArray *photos = @[[MWPhoto photoWithURL:[NSURL URLWithString:src]]];
        MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithPhotos:photos];
        UIViewController *vc = [AwfulAppDelegate instance].window.rootViewController;
        UINavigationController *navi = [[UINavigationController alloc] initWithRootViewController:browser];
        [vc presentModalViewController:navi animated:YES];
    }
}

#pragma mark - View lifecycle

- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view.backgroundColor = [UIColor underPageBackgroundColor];
    CGRect webFrame, toolbarFrame;
    CGRectDivide(self.view.bounds, &toolbarFrame, &webFrame, 49, CGRectMaxYEdge);
    
    self.toolbar = [[UIToolbar alloc] initWithFrame:toolbarFrame];
    self.toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.toolbar.barStyle = UIBarStyleBlack;
    self.pagesBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Page ? of ?"
                                                               style:UIBarButtonItemStyleBordered
                                                              target:self
                                                              action:@selector(tappedPageNav:)];
    self.pagesSegmentedControl = [[ButtonSegmentedControl alloc] initWithItems:@[
                                  [UIImage imageNamed:@"arrowleft.png"],
                                  [UIImage imageNamed:@"arrowright.png"]]];
    self.pagesSegmentedControl.bounds = CGRectMake(0, 0, 85, 30);
    self.pagesSegmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
    self.pagesSegmentedControl.target = self;
    self.pagesSegmentedControl.action = @selector(tappedPagesSegment:);
    self.actionsSegmentedControl = [[ButtonSegmentedControl alloc] initWithItems:@[
                                    [UIImage imageNamed:@"action.png"],
                                    [UIImage imageNamed:@"compose.png"]]];
    self.actionsSegmentedControl.bounds = CGRectMake(0, 0, 85, 30);
    self.actionsSegmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
    self.actionsSegmentedControl.target = self;
    self.actionsSegmentedControl.action = @selector(tappedActionsSegment:);
    self.toolbar.items = @[
        [[UIBarButtonItem alloc] initWithCustomView:self.pagesSegmentedControl],
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                      target:nil
                                                      action:NULL],
        self.pagesBarButtonItem,
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                      target:nil
                                                      action:NULL],
        [[UIBarButtonItem alloc] initWithCustomView:self.actionsSegmentedControl]
    ];
    [self.view addSubview:self.toolbar];
    
    self.webView = [[UIWebView alloc] initWithFrame:webFrame];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.backgroundColor = [UIColor underPageBackgroundColor];
    self.webViewDelegateWrapper = [AwfulWebViewDelegateWrapper delegateWrappingDelegate:self];
    self.webView.delegate = self.webViewDelegateWrapper;
    [self.view addSubview:self.webView];
}

- (UIWebView *)webView
{
    if (!_webView) [self view];
    return _webView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                        action:@selector(heldPost:)];
    press.delegate = self;
    press.minimumPressDuration = 0.3;
    [self.webView addGestureRecognizer:press];
}

- (void)viewDidDisappear:(BOOL)animated
{
    // Blank the web view if we're leaving for good. Otherwise we get weirdness like videos
    // continuing to play their sound after the user switches to a different thread.
    if (!self.navigationController) {
        NSURL *blank = [NSURL URLWithString:@"about:blank"];
        [self.webView loadRequest:[NSURLRequest requestWithURL:blank]];
    }
    
    [super viewDidDisappear:animated];
}

#pragma mark - BarButtonItem Actions

- (void)updatePagesLabel
{
    self.pagesBarButtonItem.title = [NSString stringWithFormat:@"Page %d of %d", self.currentPage, self.numberOfPages];
    [self.pagesSegmentedControl setEnabled:self.currentPage != self.numberOfPages
                         forSegmentAtIndex:1];
    [self.pagesSegmentedControl setEnabled:self.currentPage != 1
                         forSegmentAtIndex:0];
}

- (void)updateBookmarked
{
    self.thread.isBookmarkedValue = self.dataController.bookmarked;
}

- (IBAction)segmentedGotTapped:(id)sender
{
    if(sender == self.actionsSegmentedControl) {
        [self tappedActionsSegment:nil];
    } else if(sender == self.pagesSegmentedControl) {
        [self tappedPagesSegment:nil];
    }
}

- (IBAction)tappedPagesSegment:(id)sender
{
    if(self.pagesSegmentedControl.selectedSegmentIndex == 0) {
        [self prevPage];
    } else if(self.pagesSegmentedControl.selectedSegmentIndex == 1) {
        [self nextPage];
    }
    self.pagesSegmentedControl.selectedSegmentIndex = -1;
}

- (IBAction)tappedActionsSegment:(id)sender
{
    if (self.actionsSegmentedControl.selectedSegmentIndex == 0) {
        [self tappedActions:nil];
    } else if (self.actionsSegmentedControl.selectedSegmentIndex == 1) {
        [self tappedCompose];
    }
    self.actionsSegmentedControl.selectedSegmentIndex = -1;
}

- (IBAction)tappedNextPage:(id)sender
{
    [self nextPage];
}

- (void)nextPage
{
    if (self.currentPage < self.numberOfPages) {
        self.destinationType = AwfulPageDestinationTypeSpecific;
        [self loadPageNum:self.currentPage + 1];
    }
}

- (void)prevPage
{
    if(self.currentPage > 1) {
        self.destinationType = AwfulPageDestinationTypeSpecific;
        [self loadPageNum:self.currentPage - 1];
    }
}

- (IBAction)tappedActions:(id)sender
{
    self.actions = [[AwfulThreadActions alloc] initWithThread:self.thread];
    self.actions.viewController = self;
    [self.actions showFromToolbar:self.toolbar];
}

- (void)tappedPageNav:(id)sender
{
    if (self.numberOfPages <= 0 || self.currentPage <= 0) {
        return;
    }
    
    UIView *sp_view = self.specificPageController.view;
    
    if (self.specificPageController != nil && !self.specificPageController.hiding) {
        self.specificPageController.hiding = YES;
        [UIView animateWithDuration:0.3
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            sp_view.frame = CGRectOffset(sp_view.frame, 0, sp_view.frame.size.height + self.toolbar.bounds.size.height);
        } completion:^(BOOL finished)
        {
            [sp_view removeFromSuperview];
            self.specificPageController = nil;
        }];
        
    } else if(self.specificPageController == nil) {
        self.specificPageController = [AwfulSpecificPageViewController new];
        self.specificPageController.page = self;
        sp_view = self.specificPageController.view;
        sp_view.frame = CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width, sp_view.frame.size.height);
        
        [self.view addSubview:sp_view];
        [self.view bringSubviewToFront:self.toolbar];
        [UIView animateWithDuration:0.3 animations:^{
            sp_view.frame = CGRectOffset(sp_view.frame, 0, -sp_view.frame.size.height - self.toolbar.bounds.size.height);
        }];
        
        [self.specificPageController.pickerView selectRow:self.currentPage - 1
                                              inComponent:0
                                                 animated:NO];
    }
}
       
- (void)hidePageNavigation
{
    if (self.specificPageController != nil) {
        [self tappedPageNav:nil];
    }
}

- (IBAction)tappedCompose
{
    AwfulReplyViewController *postBox = [AwfulReplyViewController new];
    postBox.thread = self.thread;
    postBox.page = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:postBox];
    [self presentViewController:nav animated:YES completion:nil];
}

#pragma mark - Navigator Content

- (void)scrollToBottom
{
    [self.webView stringByEvaluatingJavaScriptFromString:@"window.scrollTo(0, document.body.scrollHeight);"];
}

- (void)scrollToSpecifiedPost
{
    [self scrollToPost:self.postIDScrollDestination];
}

- (void)scrollToPost:(NSString *)postID
{
    if (postID) {
        NSString *scrolling = [NSString stringWithFormat:@"scrollToID('%@')", postID];
        [self.webView stringByEvaluatingJavaScriptFromString:scrolling];
    }
}

- (void)showActions:(NSString *)postID fromRect:(CGRect)rect
{
    self.actions = nil;
    if (!postID || postID.length == 0)
        return;
    for (AwfulPost *post in self.dataController.posts) {
        if ([post.postID isEqualToString:postID]) {
            self.actions = [[AwfulPostActions alloc] initWithAwfulPost:post
                                                                  page:self];
            break;
        }
    }
    self.actions.viewController = self;
    [self.actions showFromRect:rect inView:[self.view superview] animated:YES];
}

- (void)showActions
{
    self.actions.viewController = self;
    [self.actions showFromToolbar:self.toolbar];
}

#pragma mark - AwfulWebViewDelegate

- (void)webView:(UIWebView *)webView
    pageDidRequestAction:(NSString *)action
    infoDictionary:(NSDictionary *)infoDictionary
{
    if ([action isEqualToString:@"nextPage"]) {
        [self nextPage];
        return;
    }
    if ([action isEqualToString:@"loadOlderPosts"]) {
        [self loadOlderPosts];
        return;
    }
    if ([action isEqualToString:@"postOptions"]) {
        NSString *postID = [infoDictionary objectForKey:@"postID"];
        CGRect rect = CGRectZero;
        if ([infoDictionary objectForKey:@"rect"])
            rect = CGRectFromString([infoDictionary objectForKey:@"rect"]);
        [self showActions:postID fromRect:rect];
        return;
    }
}

#pragma mark - Gesture recognizer delegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other
{
    return YES;
}

#pragma mark - Web view delegate

- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
    navigationType:(UIWebViewNavigationType)navigationType
{
    if (navigationType != UIWebViewNavigationTypeLinkClicked) {
        return YES;
    }
    NSURL *url = request.URL;
    if ([[url host] isEqualToString:@"forums.somethingawful.com"] &&
        [[url lastPathComponent] isEqualToString:@"showthread.php"]) {
        NSString *threadID;
        NSString *pageNumber;
        NSArray *queryElements = [[request.URL query] componentsSeparatedByString:@"&"];
        for (NSString *element in queryElements) {
            NSArray *keyAndVal = [element componentsSeparatedByString:@"="];
            if ([keyAndVal[0] isEqualToString:@"threadid"]) {
                threadID = [keyAndVal lastObject];
            } else if ([keyAndVal[0] isEqualToString:@"pagenumber"]) {
                pageNumber = [keyAndVal lastObject];
            }
        }
        
        // TODO (nolan) idgi, why a throwaway context?
        if (threadID) {
            NSManagedObjectModel *model = [NSManagedObjectModel mergedModelFromBundles:nil];
            NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
            NSManagedObjectContext *moc = [NSManagedObjectContext new];
            [moc setPersistentStoreCoordinator:coordinator];
            [moc setUndoManager:nil];
            AwfulThread *intra = [AwfulThread insertInManagedObjectContext:moc];
            intra.threadID = threadID;
            AwfulPage *page = [AwfulPage new];
            page.thread = intra;
            [self.navigationController pushViewController:page animated:YES];
            if (pageNumber != nil) {
                page.destinationType = AwfulPageDestinationTypeSpecific;
                [page loadPageNum:[pageNumber integerValue]];
            } else {
                page.destinationType = AwfulPageDestinationTypeFirst;
                [page refresh];
            }
            return NO;
        }
    } else if (![url host] && [[url lastPathComponent] isEqualToString:@"showthread.php"]) {
        // TODO when does this happen?
        url = [NSURL URLWithString:[NSString stringWithFormat:@"http://forums.somethingawful.com/%@",
                                    request.URL]];
    }
    [[UIApplication sharedApplication] openURL:url];
    return NO;
}

- (void)webViewDidFinishLoad:(UIWebView *)sender
{
    [self swapToRefreshButton];
    if (self.postIDScrollDestination != nil) {
        [self scrollToSpecifiedPost];
    } else if(self.shouldScrollToBottom) {
        [self scrollToBottom];
    }
}

- (void)swapToRefreshButton
{
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(hardRefresh)];
    refresh.style = UIBarButtonItemStyleBordered;
    self.navigationItem.rightBarButtonItem = refresh;
}

- (void)swapToStopButton
{
    UIBarButtonItem *stop = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(stop)];
    stop.style = UIBarButtonItemStyleBordered;
    self.navigationItem.rightBarButtonItem = stop;
}

- (void)showCompletionMessage:(NSString *)message
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [SVProgressHUD showSuccessWithStatus:message];
    });
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (BOOL)isOnLastPage
{
    return self.currentPage == self.numberOfPages;
}

@end


NSString * const AwfulPageWillLoadNotification = @"com.awfulapp.Awful.PageWillLoadNotification";
NSString * const AwfulPageDidLoadNotification = @"com.awfulapp.Awful.PageDidLoadNotification";


@interface AwfulPageIpad ()

@property (nonatomic, strong) UIPopoverController *popController;

@end


@implementation AwfulPageIpad
{
    CGPoint _lastTouch;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(handleTap:)];
    tap.delegate = self;
    [self.webView addGestureRecognizer:tap];
    CGRect frame = self.toolbar.frame;
    frame.size.height = 49;
    self.toolbar.frame = frame;
}

- (IBAction)tappedPageNav:(id)sender
{
    if (self.popController)
    {
        [self.popController dismissPopoverAnimated:YES];
        self.popController = nil;
    }
    
    if (self.numberOfPages <= 0 || self.currentPage <= 0)
    {
        return;
    }
    
    UIView *sp_view = self.specificPageController.view;
        
    if (!self.specificPageController)
    {
        self.specificPageController = [AwfulSpecificPageViewController new];
        self.specificPageController.page = self;
        [self.specificPageController loadView];
        sp_view = self.specificPageController.view;
        
        [self.specificPageController.pickerView selectRow:self.currentPage - 1
                                              inComponent:0
                                                 animated:NO];
    }

    UIViewController *vc = self.specificPageController;

    self.popController = [[UIPopoverController alloc] initWithContentViewController:vc];
    
    [self.popController setPopoverContentSize:CGSizeMake(260,sp_view.frame.size.height) animated:YES];
    [self.popController presentPopoverFromBarButtonItem:self.pagesBarButtonItem
                               permittedArrowDirections:UIPopoverArrowDirectionAny
                                               animated:YES];
}


- (void)showRootPopoverButtonItem:(UIBarButtonItem *)barButtonItem
{
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
}

- (void)invalidateRootPopoverButtonItem:(UIBarButtonItem *)barButtonItem
{    
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
}

- (void)handleTap:(UITapGestureRecognizer *)sender 
{     
    if (sender.state == UIGestureRecognizerStateEnded) {
        _lastTouch = [sender locationInView:self.view];
    }
}

// hack for embedded youtube controls to work
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
       shouldReceiveTouch:(UITouch *)touch
{
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        CGPoint loc = [touch locationInView:self.view];
        _lastTouch = loc;
        return NO;
    }
    return YES;
}

- (IBAction)tappedActions:(id)sender
{
    self.actions = [[AwfulThreadActions alloc] initWithThread:self.thread];
    [self showActions];
}

- (void)showActions
{    
    self.actions.viewController = self;
    if (!([self.actions isKindOfClass:[AwfulThreadActions class]]
            || [self.actions isKindOfClass:[AwfulVoteActions class]])) {
        NSLog(@"only thread actions and vote actions are supported by this 'showActions' method");
        return;
    }
    CGRect rect = self.actionsSegmentedControl.frame;
    rect.size.width /= 2;
    [self.actions.actionSheet showFromRect:rect
                                    inView:self.actionsSegmentedControl.superview
                                  animated:YES];
}

- (void)showActions:(NSString *)post_id fromRect:(CGRect)rect
{
    self.actions = nil;
    if (!post_id || post_id.length == 0) return;
    for (AwfulPost *post in self.dataController.posts) {
        if ([post.postID isEqualToString:post_id]) {
            self.actions = [[AwfulPostActions alloc] initWithAwfulPost:post
                                                                  page:self];
            break;
        }
    }
    if (self.popController) {
        [self.popController dismissPopoverAnimated:YES];
        self.popController = nil;
    }
    if (!self.actions) return;
    self.actions.viewController = self;
    UIActionSheet *sheet = self.actions.actionSheet;
    CGRect buttonRect = rect;
    if ([self.actions isKindOfClass:[AwfulThreadActions class]]
        || [self.actions isKindOfClass:[AwfulVoteActions class]]) {
        buttonRect = self.actionsSegmentedControl.frame;
        buttonRect.size.width /= 2;
    }
    [sheet showFromRect:buttonRect inView:self.view animated:YES];
}

- (IBAction)tappedCompose
{
    if (self.popController)
    {
        [self.popController dismissPopoverAnimated:YES];
        self.popController = nil;
    }
    
    [super tappedCompose];
}

- (void)hidePageNavigation
{
    if (self.popController) {
        [self.popController dismissPopoverAnimated:YES];
        self.popController = nil;
    }
}

@end
