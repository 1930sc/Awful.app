//  AwfulBasementViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulBasementViewController.h"
#import "AwfulBasementSidebarViewController.h"

/**
 * An AwfulBasementViewController operates a state machine between three states with the following transitions:
 *
 * Hidden <----> Obscured <----> Visible
 */
typedef NS_ENUM(NSInteger, AwfulBasementSidebarState)
{
    /**
     * When the sidebar is hidden, the selected view controller fills the entire view.
     */
    AwfulBasementSidebarStateHidden,
    
    /**
     * The sidebar is obscured when the selected view controller is being dragged around.
     */
    AwfulBasementSidebarStateObscured,
    
    /**
     * When the sidebar is visible, user interaction is disabled on the selected view controller's view.
     */
    AwfulBasementSidebarStateVisible,
};

@interface AwfulBasementViewController () <AwfulBasementSidebarViewControllerDelegate, UIGestureRecognizerDelegate>

@property (assign, nonatomic) AwfulBasementSidebarState state;
@property (strong, nonatomic) AwfulBasementSidebarViewController *sidebarViewController;
@property (strong, nonatomic) UIView *mainContainerView;
@property (strong, nonatomic) NSLayoutConstraint *revealSidebarConstraint;
@property (copy, nonatomic) NSArray *selectedViewControllerConstraints;
@property (copy, nonatomic) NSArray *visibleSidebarConstraints;
@property (strong, nonatomic) UIPanGestureRecognizer *mainViewPan;
@property (strong, nonatomic) UITapGestureRecognizer *mainViewTap;
@property (strong, nonatomic) UIScreenEdgePanGestureRecognizer *screenEdgePan;

@end

@implementation AwfulBasementViewController

- (id)initWithViewControllers:(NSArray *)viewControllers
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    self.viewControllers = viewControllers;
    return self;
}

- (void)themeDidChange
{
    [self.viewControllers makeObjectsPerformSelector:@selector(themeDidChange)];
}

- (void)setViewControllers:(NSArray *)viewControllers
{
    if (_viewControllers == viewControllers) return;
    _viewControllers = [viewControllers copy];
    self.sidebarViewController.items = [_viewControllers valueForKey:@"tabBarItem"];
    for (UIViewController *viewController in _viewControllers) {
        UINavigationItem *navigationItem = viewController.navigationItem;
        if ([viewController isKindOfClass:[UINavigationController class]]) {
            UIViewController *root = ((UINavigationController *)viewController).viewControllers[0];
            navigationItem = root.navigationItem;
        }
        navigationItem.leftBarButtonItem = [self createShowSidebarItem];
    }
    if (![_viewControllers containsObject:self.selectedViewController]) {
        self.selectedViewController = _viewControllers[0];
    }
}

- (NSUInteger)selectedIndex
{
    return [self.viewControllers indexOfObject:self.selectedViewController];
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex
{
    self.selectedViewController = self.viewControllers[selectedIndex];
}

- (UIBarButtonItem *)createShowSidebarItem
{
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"hamburger-button"]
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(showSidebar)];
    item.imageInsets = UIEdgeInsetsMake(0, -8.5, -2, 0);
    return item;
}

- (void)showSidebar
{
    [self setSidebarVisible:YES animated:YES];
}

- (void)loadView
{
    self.view = [UIView new];
    self.sidebarViewController = [AwfulBasementSidebarViewController new];
    self.sidebarViewController.delegate = self;
    self.sidebarViewController.items = [self.viewControllers valueForKey:@"tabBarItem"];
    self.sidebarViewController.selectedItem = self.selectedViewController.tabBarItem;
    
    self.screenEdgePan = [UIScreenEdgePanGestureRecognizer new];
    self.screenEdgePan.delegate = self;
    self.screenEdgePan.edges = UIRectEdgeLeft;
    [self.screenEdgePan addTarget:self action:@selector(panFromLeftScreenEdge:)];
    [self.view addGestureRecognizer:self.screenEdgePan];
    
    self.mainContainerView = [UIView new];
    self.mainContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.mainContainerView];
    
    [self replaceMainViewController:nil withViewController:self.selectedViewController];
}

- (void)panFromLeftScreenEdge:(UIScreenEdgePanGestureRecognizer *)pan
{
    if (pan.state == UIGestureRecognizerStateBegan) {
        self.state = AwfulBasementSidebarStateObscured;
        self.revealSidebarConstraint.constant = [pan translationInView:self.view].x;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        self.revealSidebarConstraint.constant = [pan translationInView:self.view].x;
    } else if (pan.state == UIGestureRecognizerStateEnded) {
        if ([pan velocityInView:self.view].x > 0) {
            [self setState:AwfulBasementSidebarStateVisible animated:YES];
        } else {
            [self setState:AwfulBasementSidebarStateHidden animated:YES];
        }
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSDictionary *views = @{ @"root": self.view,
                             @"main": self.mainContainerView };
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0@500-[main(==root)]"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[main]|"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:views]];
    if (self.sidebarVisible) {
        [self constrainSidebarToBeVisible];
        [self.view setNeedsLayout];
    }
}

- (void)constrainSidebarToBeVisible
{
    if (self.visibleSidebarConstraints) return;
    NSDictionary *views = @{ @"sidebar": self.sidebarViewController.view,
                             @"main": self.mainContainerView };
    self.visibleSidebarConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[sidebar][main]"
                                                                             options:0
                                                                             metrics:nil
                                                                               views:views];
    [self.view addConstraints:self.visibleSidebarConstraints];
}

- (void)setSelectedViewController:(UIViewController *)selectedViewController
{
    UIViewController *old = _selectedViewController;
    _selectedViewController = selectedViewController;
    self.sidebarViewController.selectedItem = _selectedViewController.tabBarItem;
    if ([self isViewLoaded] && ![old isEqual:selectedViewController]) {
        [self replaceMainViewController:old withViewController:selectedViewController];
    }
}

- (void)replaceMainViewController:(UIViewController *)oldViewController
               withViewController:(UIViewController *)newViewController
{
    [oldViewController willMoveToParentViewController:nil];
    [self addChildViewController:newViewController];
    if (self.selectedViewControllerConstraints) {
        [self.mainContainerView removeConstraints:self.selectedViewControllerConstraints];
    }
    [oldViewController.view removeFromSuperview];
    newViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.mainContainerView addSubview:newViewController.view];
    NSMutableArray *constraints = [NSMutableArray new];
    NSDictionary *views = @{ @"new": newViewController.view };
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[new]|" options:0 metrics:nil views:views]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[new]|" options:0 metrics:nil views:views]];
    self.selectedViewControllerConstraints = constraints;
    [self.mainContainerView addConstraints:constraints];
    [oldViewController removeFromParentViewController];
    [newViewController didMoveToParentViewController:self];
    [self setNeedsStatusBarAppearanceUpdate];
}

- (UIViewController *)childViewControllerForStatusBarStyle
{
    return self.selectedViewController;
}

- (BOOL)sidebarVisible
{
    return self.state != AwfulBasementSidebarStateHidden;
}

- (void)setSidebarVisible:(BOOL)sidebarVisible
{
    [self setSidebarVisible:sidebarVisible animated:NO];
}

- (void)setSidebarVisible:(BOOL)sidebarVisible animated:(BOOL)animated
{
    if (sidebarVisible) {
        [self setState:AwfulBasementSidebarStateVisible animated:animated];
    } else {
        [self setState:AwfulBasementSidebarStateHidden animated:animated];
    }
}

- (void)setState:(AwfulBasementSidebarState)state
{
    [self setState:state animated:NO];
}

- (void)setState:(AwfulBasementSidebarState)state animated:(BOOL)animated
{
    if (_state == state) return;
    AwfulBasementSidebarState oldState = _state;
    _state = state;
    if (![self isViewLoaded]) return;
    
    BOOL sidebarAlreadyAdded = self.sidebarViewController.parentViewController == self;
    
    if (state == AwfulBasementSidebarStateHidden) {
        if (self.revealSidebarConstraint) {
            [self.view removeConstraint:self.revealSidebarConstraint];
            self.revealSidebarConstraint = nil;
        }
        if (self.visibleSidebarConstraints) {
            [self.view removeConstraints:self.visibleSidebarConstraints];
            self.visibleSidebarConstraints = nil;
        }
        self.mainContainerView.userInteractionEnabled = YES;
    } else {
        [self lazilyAddSidebarViewControllerAsChild];
        self.mainContainerView.userInteractionEnabled = NO;
    }
    
    if (state == AwfulBasementSidebarStateObscured) {
        if (self.visibleSidebarConstraints) {
            [self.view removeConstraints:self.visibleSidebarConstraints];
            self.visibleSidebarConstraints = nil;
        }
        self.revealSidebarConstraint = [NSLayoutConstraint constraintWithItem:self.mainContainerView
                                                                    attribute:NSLayoutAttributeLeft
                                                                    relatedBy:NSLayoutRelationEqual
                                                                       toItem:self.view
                                                                    attribute:NSLayoutAttributeLeft
                                                                   multiplier:1
                                                                     constant:0];
        self.revealSidebarConstraint.priority = 750;
        [self.view addConstraint:self.revealSidebarConstraint];
    } else {
        if (self.mainViewPan) {
            [self.mainViewPan.view removeGestureRecognizer:self.mainViewPan];
            self.mainViewPan = nil;
        }
    }
    
    if (state == AwfulBasementSidebarStateVisible) {
        if (self.revealSidebarConstraint) {
            [self.view removeConstraint:self.revealSidebarConstraint];
            self.revealSidebarConstraint = nil;
        }
        [self constrainSidebarToBeVisible];
        self.mainViewTap = [UITapGestureRecognizer new];
        self.mainViewTap.delegate = self;
        [self.mainViewTap addTarget:self action:@selector(tapMainView:)];
        [self.view addGestureRecognizer:self.mainViewTap];
        self.mainViewPan = [UIPanGestureRecognizer new];
        [self.mainViewPan addTarget:self action:@selector(panMainView:)];
        [self.view addGestureRecognizer:self.mainViewPan];
    } else {
        if (self.mainViewTap) {
            [self.mainViewTap.view removeGestureRecognizer:self.mainViewTap];
            self.mainViewTap = nil;
        }
    }
    
    BOOL appearing = sidebarAlreadyAdded && state != AwfulBasementSidebarStateHidden && oldState == AwfulBasementSidebarStateHidden;
    BOOL disappearing = sidebarAlreadyAdded && state == AwfulBasementSidebarStateHidden && oldState != AwfulBasementSidebarStateHidden;
    
    if (appearing) {
        [self.sidebarViewController viewWillAppear:animated];
    } else if (disappearing) {
        [self.sidebarViewController viewWillDisappear:animated];
    }
    [UIView animateWithDuration:(animated ? 0.2 : 0) animations:^{
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        if (appearing) {
            [self.sidebarViewController viewDidAppear:animated];
        } else if (disappearing) {
            [self.sidebarViewController viewDidDisappear:animated];
        }
    }];
}

- (void)lazilyAddSidebarViewControllerAsChild
{
    if ([self.sidebarViewController.parentViewController isEqual:self]) return;
    [self addChildViewController:self.sidebarViewController];
    self.sidebarViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view insertSubview:self.sidebarViewController.view belowSubview:self.mainContainerView];
    [self.sidebarViewController didMoveToParentViewController:self];
    NSDictionary *views = @{ @"sidebar": self.sidebarViewController.view,
                             @"top": self.topLayoutGuide };
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[sidebar(==280)]"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[sidebar]|"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:views]];
    [self.view layoutIfNeeded];
}

- (void)tapMainView:(UITapGestureRecognizer *)tap
{
    if (CGRectContainsPoint(self.mainContainerView.frame, [tap locationInView:self.view])) {
        [self setSidebarVisible:NO animated:YES];
    }
}

- (void)panMainView:(UIPanGestureRecognizer *)pan
{
    if (pan.state == UIGestureRecognizerStateBegan) {
        if (!(CGRectContainsPoint(self.mainContainerView.frame, [pan locationInView:self.view]))) {
            [pan awful_failImmediately];
            return;
        }
        CGPoint start = CGPointMake(CGRectGetMinX(self.mainContainerView.frame), 0);
        start.x += [pan translationInView:pan.view].x;
        [pan setTranslation:start inView:self.view];
        self.state = AwfulBasementSidebarStateObscured;
        self.revealSidebarConstraint.constant = [pan translationInView:self.view].x;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        self.revealSidebarConstraint.constant = [pan translationInView:self.view].x;
    } else if (pan.state == UIGestureRecognizerStateEnded) {
        if ([pan velocityInView:self.view].x > 0) {
            [self setState:AwfulBasementSidebarStateVisible animated:YES];
        } else {
            [self setState:AwfulBasementSidebarStateHidden animated:YES];
        }
    }
}

#pragma mark AwfulBasementSidebarViewControllerDelegate

- (void)sidebar:(AwfulBasementSidebarViewController *)sidebar didSelectItem:(UITabBarItem *)item
{
    NSUInteger i = [sidebar.items indexOfObject:item];
    self.selectedViewController = self.viewControllers[i];
    [self setSidebarVisible:NO animated:YES];
}

#pragma mark UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if ([gestureRecognizer isEqual:self.mainViewTap]) {
        return CGRectContainsPoint(self.mainContainerView.frame, [touch locationInView:self.view]);
    }
    return YES;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if ([gestureRecognizer isEqual:self.screenEdgePan]) {
        if (![self.selectedViewController isKindOfClass:[UINavigationController class]]) return YES;
        UINavigationController *nav = (UINavigationController *)self.selectedViewController;
        return nav.viewControllers.count < 2;
    }
    return YES;
}

#pragma mark State preservation and restoration

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    
    // Encoding these just so they'll get saved. We won't be restoring them.
    [coder encodeObject:self.viewControllers forKey:ViewControllersKey];
    
    [coder encodeObject:self.selectedViewController forKey:SelectedViewControllerKey];
    [coder encodeBool:self.sidebarVisible forKey:SidebarVisibleKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    self.selectedViewController = [coder decodeObjectForKey:SelectedViewControllerKey];
    // TODO test that restoring a visible sidebar actually works
    self.sidebarVisible = [coder decodeBoolForKey:SidebarVisibleKey];
}

static NSString * const ViewControllersKey = @"AwfulViewControllers";
static NSString * const SelectedViewControllerKey = @"AwfulSelectedViewController";
static NSString * const SidebarVisibleKey = @"AwfulSidebarVisible";

@end
