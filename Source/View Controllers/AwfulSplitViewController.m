//  AwfulSplitViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulSplitViewController.h"
#import "AwfulTabBarController.h"

@interface AwfulSplitViewController ()

@property (nonatomic) UIViewController *sidebarViewController;
@property (nonatomic) UIViewController *mainViewController;
@property (nonatomic) UIView *sidebarHolder;
@property (nonatomic) UIView *coverView;
@property (nonatomic) UIPanGestureRecognizer *revealSidebarGesture;

@end


@implementation AwfulSplitViewController

- (instancetype)initWithSidebarViewController:(UIViewController *)sidebarViewController
                           mainViewController:(UIViewController *)mainViewController
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    _sidebarViewController = sidebarViewController;
    _mainViewController = mainViewController;
    return self;
}

- (NSArray *)viewControllers
{
    return @[ self.sidebarViewController, self.mainViewController ];
}

- (void)setSidebarVisible:(BOOL)show
{
    [self setSidebarVisible:show animated:NO];
}

- (void)setSidebarVisible:(BOOL)show animated:(BOOL)animated
{
    if (_sidebarVisible == show) return;
    if (!show && !self.sidebarCanHide) return;
    _sidebarVisible = show;
    if (show) {
        if (self.sidebarCanHide) {
            self.coverView.frame = self.view.bounds;
            [self.view addSubview:self.coverView];
        }
        [self addChildViewController:self.sidebarViewController];
        [self.view addSubview:self.sidebarHolder];
    } else {
        [self.sidebarViewController willMoveToParentViewController:nil];
        [self.coverView removeFromSuperview];
    }
    [UIView animateWithDuration:animated ? 0.25 : 0 animations:^{
        [self layoutViewControllers];
    } completion:^(BOOL finished) {
        if (!finished) return;
        if (show) {
            [self.sidebarViewController didMoveToParentViewController:self];
        } else {
            [self.sidebarHolder removeFromSuperview];
            [self.sidebarViewController removeFromParentViewController];
        }
    }];
}

- (UIView *)coverView
{
    if (_coverView) return _coverView;
    _coverView = [UIView new];
    
    UISwipeGestureRecognizer *hideSidebarGesture = [UISwipeGestureRecognizer new];
    hideSidebarGesture.direction = UISwipeGestureRecognizerDirectionLeft;
    [hideSidebarGesture addTarget:self action:@selector(didTriggerHideSidebarGesture:)];
    [_coverView addGestureRecognizer:hideSidebarGesture];
    
    UITapGestureRecognizer *tap = [UITapGestureRecognizer new];
    [tap addTarget:self action:@selector(didTriggerHideSidebarGesture:)];
    [_coverView addGestureRecognizer:tap];
    
    UISwipeGestureRecognizer *popViewControllerGesture = [UISwipeGestureRecognizer new];
    popViewControllerGesture.direction = UISwipeGestureRecognizerDirectionRight;
    [popViewControllerGesture addTarget:self action:@selector(didTriggerPopViewControllerGesture)];
    [_coverView addGestureRecognizer:popViewControllerGesture];

    
    return _coverView;
}

- (void)didTriggerHideSidebarGesture:(UIGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        [self setSidebarVisible:NO animated:YES];
    }
}

- (void)didTriggerPopViewControllerGesture
{
    UINavigationController *nav = (id)self.sidebarViewController;
    if ([nav isKindOfClass:[AwfulTabBarController class]]) {
        nav = (id)[(UITabBarController *)nav selectedViewController];
    }
    if ([nav isKindOfClass:[UINavigationController class]]) {
        [nav popViewControllerAnimated:YES];
    }
}

- (void)setSidebarCanHide:(BOOL)canHide
{
    _sidebarCanHide = canHide;
    
    self.sidebarHolder.layer.shadowOpacity = canHide ? 0.5 : 0;
    
    if (!canHide) {
        self.sidebarVisible = YES;
        [self.coverView removeFromSuperview];
    }
    
    [self layoutViewControllers];
    
    if (canHide && !self.revealSidebarGesture.view) {
        [self.mainViewController.view addGestureRecognizer:self.revealSidebarGesture];
    } else if (!canHide && self.revealSidebarGesture.view) {
        [self.mainViewController.view removeGestureRecognizer:self.revealSidebarGesture];
    }
}

- (UIPanGestureRecognizer *)revealSidebarGesture
{
    if (_revealSidebarGesture) return _revealSidebarGesture;
    _revealSidebarGesture = [UIPanGestureRecognizer new];
    [_revealSidebarGesture addTarget:self action:@selector(didPanRightOnMainView:)];
    return _revealSidebarGesture;
}

- (void)didPanRightOnMainView:(UIPanGestureRecognizer *)pan
{
    CGPoint translation = [pan translationInView:pan.view];
    if (pan.state == UIGestureRecognizerStateBegan) {
        
        // Only consider horizontal pans that start moving right; otherwise cancel the pan.
        if (fabsf(translation.x) < fabs(translation.y) || translation.x <= 0) {
            pan.enabled = NO;
            pan.enabled = YES;
            return;
        }
        
        [self setSidebarVisible:YES animated:YES];
        [pan setTranslation:CGPointZero inView:pan.view];
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        if (fabsf(translation.x) > 10) {
            [self setSidebarVisible:(translation.x > 0) animated:YES];
            [pan setTranslation:CGPointZero inView:pan.view];
        }
    }
}

const CGFloat SidebarWidth = 320;

- (void)layoutViewControllers
{
    if (self.sidebarCanHide) {
        self.mainViewController.view.frame = self.view.bounds;
        CGRect sidebarFrame = CGRectMake(0, 0, SidebarWidth, CGRectGetHeight(self.view.bounds));
        if (!self.sidebarVisible) {
            sidebarFrame = CGRectOffset(sidebarFrame, -CGRectGetWidth(sidebarFrame) - 1, 0);
        }
        self.sidebarHolder.frame = sidebarFrame;
    } else {
        CGRect sidebarFrame, mainFrame;
        CGRectDivide(self.view.bounds, &sidebarFrame, &mainFrame, SidebarWidth, CGRectMinXEdge);
        mainFrame.origin.x += 1;
        mainFrame.size.width -= 1;
        self.sidebarHolder.frame = sidebarFrame;
        self.mainViewController.view.frame = mainFrame;
    }
    CALayer *sidebarLayer = self.sidebarHolder.layer;
    if (sidebarLayer.shadowOpacity > 0) {
        sidebarLayer.shadowPath = [UIBezierPath bezierPathWithRect:sidebarLayer.bounds].CGPath;
    }
}

#pragma mark - UIViewController

- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.backgroundColor = [UIColor blackColor];
    
    const CGFloat cornerRadius = 4;
    
    self.sidebarHolder = [[UIView alloc] initWithFrame:CGRectMake(0, 0, SidebarWidth, 0)];
    self.sidebarHolder.layer.shadowOffset = CGSizeMake(3, 0);
    self.sidebarHolder.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    UIView *sidebarView = self.sidebarViewController.view;
    sidebarView.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                    UIViewAutoresizingFlexibleHeight);
    sidebarView.frame = self.sidebarHolder.bounds;
    sidebarView.layer.cornerRadius = cornerRadius;
    [self.sidebarHolder addSubview:sidebarView];
    
    [self addChildViewController:self.mainViewController];
    self.mainViewController.view.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                                     UIViewAutoresizingFlexibleHeight);
    self.mainViewController.view.layer.cornerRadius = cornerRadius;
    self.mainViewController.view.clipsToBounds = YES;
    [self.view addSubview:self.mainViewController.view];
    [self.mainViewController didMoveToParentViewController:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self setSidebarCanHide:[self shouldHideSidebar]];
    [self.delegate awfulSplitViewController:self willHideSidebar:self.sidebarCanHide];
}

- (BOOL)shouldHideSidebar
{
    return [self.delegate awfulSplitViewController:self
                    shouldHideSidebarInOrientation:self.interfaceOrientation];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    return [self.mainViewController shouldAutorotateToInterfaceOrientation:orientation];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)orientation
                                         duration:(NSTimeInterval)duration
{
    self.sidebarCanHide = [self shouldHideSidebar];
    self.sidebarVisible = NO;
    [self.delegate awfulSplitViewController:self willHideSidebar:self.sidebarCanHide];
}

@end


@implementation UIViewController (AwfulSplitViewController)

- (AwfulSplitViewController *)awfulSplitViewController
{
    UIViewController *vc = self;
    do {
        vc = vc.parentViewController;
    } while (vc && ![vc isKindOfClass:[AwfulSplitViewController class]]);
    return (id)vc;
}

@end
