//  AwfulNavigationController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulNavigationController.h"
#import "UIViewController+AwfulTheme.h"

@interface AwfulNavigationController () <UIViewControllerRestoration>

@end

@implementation AwfulNavigationController

// We cannot override the designated initializer, -initWithNibName:bundle:, and call -initWithNavigationBarClass:toolbarClass: within. So we override what we can, and handle our own restoration, to ensure our navigation bar and toolbar classes are used.

- (id)init
{
    if (!(self = [self initWithNavigationBarClass:[AwfulNavigationBar class] toolbarClass:[AwfulToolbar class]])) return nil;
    self.restorationClass = self.class;
    return self;
}

- (id)initWithRootViewController:(UIViewController *)rootViewController
{
    if (!(self = [self init])) return nil;
    self.viewControllers = @[ rootViewController ];
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

@end
