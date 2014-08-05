//  AwfulNavigationController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulNavigationController.h"
#import "UIViewController+AwfulTheme.h"

@interface AwfulNavigationController () <UINavigationControllerDelegate, UIViewControllerRestoration>

@property (strong, nonatomic) AwfulUnpoppingViewHandler *unpopHandler;

@property (weak, nonatomic) id <UINavigationControllerDelegate> realDelegate;

@end

@implementation AwfulNavigationController

// We cannot override the designated initializer, -initWithNibName:bundle:, and call -initWithNavigationBarClass:toolbarClass: within. So we override what we can, and handle our own restoration, to ensure our navigation bar and toolbar classes are used.

- (id)init
{
    if ((self = [self initWithNavigationBarClass:[AwfulNavigationBar class] toolbarClass:[AwfulToolbar class]])) {
        self.restorationClass = self.class;
        super.delegate = self;
    }
    return self;
}

- (id)initWithRootViewController:(UIViewController *)rootViewController
{
    if ((self = [self init])) {
        self.viewControllers = @[ rootViewController ];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self themeDidChange];
}

- (void)themeDidChange
{
    [super themeDidChange];
    AwfulTheme *theme = [AwfulTheme currentTheme];
	self.navigationBar.tintColor = theme[@"navigationBarTextColor"];
    self.navigationBar.barTintColor = theme[@"navigationBarTintColor"];
    self.toolbar.tintColor = theme[@"toolbarTextColor"];
    self.toolbar.barTintColor = theme[@"toolbarTintColor"];
}

#pragma mark - UIViewControllerRestoration

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    UINavigationController *nav = [self new];
    nav.restorationIdentifier = identifierComponents.lastObject;
    return nav;
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    self.unpopHandler.viewControllers = [coder decodeObjectForKey:FutureViewControllersKey];
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:self.unpopHandler.viewControllers forKey:FutureViewControllersKey];
}

static NSString * const FutureViewControllersKey = @"AwfulFutureViewControllers";

#pragma mark - Swipe to unpop

- (AwfulUnpoppingViewHandler *)unpopHandler
{
    if (!_unpopHandler && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        _unpopHandler = [[AwfulUnpoppingViewHandler alloc] initWithNavigationController:self];
    }
    return _unpopHandler;
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated
{
    UIViewController *viewController = [super popViewControllerAnimated:animated];
    [self.unpopHandler navigationController:self didPopViewController:viewController];
    return viewController;
}

- (NSArray *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    NSArray *popped = [super popToViewController:viewController animated:animated];
    for (UIViewController *viewController in popped) {
        [self.unpopHandler navigationController:self didPopViewController:viewController];
    }
    return popped;
}

- (NSArray *)popToRootViewControllerAnimated:(BOOL)animated
{
    NSArray *popped = [super popToRootViewControllerAnimated:animated];
    for (UIViewController *viewController in popped) {
        [self.unpopHandler navigationController:self didPopViewController:viewController];
    }
    return popped;
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    // If we don't disable the interactivePopGestureRecognizer, we can get into a weird state where the pushed view doesn't appear and touches get no response.
    self.interactivePopGestureRecognizer.enabled = NO;
    
    [super pushViewController:viewController animated:animated];
    [self.unpopHandler navigationController:self didPushViewController:viewController];
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated
{
    [self setToolbarHidden:(viewController.toolbarItems.count == 0) animated:animated];
    
    if (animated) {
        [self.unpopHandler navigationControllerDidBeginAnimating];
        
        // We need to hook into the transitionCoordinator's notifications as well as -...didShowViewController: because the latter isn't called when the default interactive pop action is cancelled.
        // See http://stackoverflow.com/questions/23484310
        id <UIViewControllerTransitionCoordinator> coordinator = navigationController.transitionCoordinator;
        [coordinator notifyWhenInteractionEndsUsingBlock:^(id <UIViewControllerTransitionCoordinatorContext> context) {
            if ([context isCancelled]) {
                BOOL unpopping = self.unpopHandler.interactiveUnpopIsTakingPlace;
                NSTimeInterval completion = [context transitionDuration] * [context percentComplete];
                NSUInteger viewControllerCount = navigationController.viewControllers.count;
                if (!unpopping) viewControllerCount++;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (uint64_t)completion * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    if (unpopping) {
                        [self.unpopHandler navigationControllerDidCancelInteractiveUnpop];
                    } else {
                        [self.unpopHandler navigationControllerDidCancelInteractivePop];
                    }
                    navigationController.interactivePopGestureRecognizer.enabled = viewControllerCount > 1;
                });
            }
        }];

    }
    
    if ([self.realDelegate respondsToSelector:_cmd]) {
        [self.realDelegate navigationController:navigationController willShowViewController:viewController animated:animated];
    }
}

- (void)navigationController:(UINavigationController *)navigationController
       didShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated
{
    if (animated) [self.unpopHandler navigationControllerDidFinishAnimating];
    self.interactivePopGestureRecognizer.enabled = viewController != self.viewControllers.firstObject;
    
    if ([self.realDelegate respondsToSelector:_cmd]) {
        [self.realDelegate navigationController:navigationController didShowViewController:viewController animated:animated];
    }
}

- (id <UIViewControllerInteractiveTransitioning>)navigationController:(UINavigationController *)navigationController
                          interactionControllerForAnimationController:(id <UIViewControllerAnimatedTransitioning>)animationController
{
    if (self.unpopHandler) {
        return self.unpopHandler;
    } else if ([self.realDelegate respondsToSelector:_cmd]) {
        return [self.realDelegate navigationController:navigationController interactionControllerForAnimationController:animationController];
    } else {
        return nil;
    }
}

- (id <UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
                                   animationControllerForOperation:(UINavigationControllerOperation)operation
                                                fromViewController:(UIViewController *)fromVC
                                                  toViewController:(UIViewController *)toVC
{
    if ([self.unpopHandler shouldHandleAnimatingTransitionForOperation:operation]) {
        return self.unpopHandler;
    } else if ([self.realDelegate respondsToSelector:_cmd]) {
        return [self.realDelegate navigationController:navigationController
                       animationControllerForOperation:operation
                                    fromViewController:fromVC
                                      toViewController:toVC];
    } else {
        return nil;
    }
}

#pragma mark - Delegate delegation

- (void)setDelegate:(id <UINavigationControllerDelegate>)delegate
{
    super.delegate = nil;
    if (delegate == self) {
        self.realDelegate = nil;
    } else {
        self.realDelegate = delegate;
        super.delegate = self;
    }
}

- (BOOL)respondsToSelector:(SEL)selector
{
    return [super respondsToSelector:selector] || [self.realDelegate respondsToSelector:selector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
    return [super methodSignatureForSelector:selector] ?: [(id)self.realDelegate methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    id realDelegate = self.realDelegate;
    if ([realDelegate respondsToSelector:invocation.selector]) {
        [invocation invokeWithTarget:realDelegate];
    }
}

@end
