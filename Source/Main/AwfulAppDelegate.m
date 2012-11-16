//
//  AwfulAppDelegate.m
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright Regular Berry Software LLC 2010. All rights reserved.
//

#import "AwfulAppDelegate.h"
#import "AwfulBookmarksController.h"
#import "AwfulDataStack.h"
#import "AwfulFavoritesViewController.h"
#import "AwfulForumsListController.h"
#import "AwfulHTTPClient.h"
#import "AwfulLoginController.h"
#import "AwfulModels.h"
#import "AwfulNavigationBar.h"
#import "AwfulSettings.h"
#import "AwfulSettingsViewController.h"
#import "AwfulSplitViewController.h"
#import "AwfulStartViewController.h"
#import "AFNetworking.h"
#import "NSFileManager+UserDirectories.h"
#import "NSManagedObject+Awful.h"
#import "UIViewController+NavigationEnclosure.h"

@interface AwfulAppDelegate () <UITabBarControllerDelegate, AwfulLoginControllerDelegate>

@end


@implementation AwfulAppDelegate

static AwfulAppDelegate *_instance;

+ (AwfulAppDelegate *)instance
{
    return _instance;
}

- (void)showLoginFormAtLaunch
{
    [self showLoginFormIsAtLaunch:YES andThen:nil];
}

- (void)showLoginFormIsAtLaunch:(BOOL)isAtLaunch andThen:(void (^)(void))callback
{
    AwfulLoginController *login = [AwfulLoginController new];
    login.delegate = self;
    UINavigationController *nav = [login enclosingNavigationController];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    BOOL animated = !isAtLaunch || UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
    [self.window.rootViewController presentViewController:nav
                                                 animated:animated
                                               completion:callback];
}

- (void)logOut
{
    NSURL *sa = [NSURL URLWithString:@"http://forums.somethingawful.com"];
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:sa];
    for (NSHTTPCookie *cookie in cookies) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
    }
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    AwfulSettings.settings.currentUser = nil;
    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
    [[AwfulDataStack sharedDataStack] deleteAllDataAndResetStack];
    
    [self showLoginFormIsAtLaunch:NO andThen:^{
        UITabBarController *tabBar;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            AwfulSplitViewController *split = (AwfulSplitViewController *)self.window.rootViewController;
            tabBar = split.viewControllers[0];
        } else if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            tabBar = (UITabBarController *)self.window.rootViewController;
        }
        tabBar.selectedIndex = 0;
    }];
}

- (void)requestFailed:(NSError *)error
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Network Error"
                                                    message:[error localizedDescription]
                                                   delegate:nil
                                          cancelButtonTitle:@"Drats"
                                          otherButtonTitles:nil];
    [alert show];
}

- (void)configureAppearance
{
    // Including a navbar.png (i.e. @1x), or setting a background image for
    // UIBarMetricsLandscapePhone, makes the background come out completely different for some
    // unknown reason on non-retina devices and in landscape on the phone. I'm out of ideas.
    // Simply setting UIBarMetricsDefault and only including navbar@2x.png works great on retina
    // and non-retina devices alike, so that's where I'm leaving it.
    AwfulNavigationBar *navBar = [AwfulNavigationBar appearance];
    UIImage *barImage = [UIImage imageNamed:@"navbar.png"];
    [navBar setBackgroundImage:barImage forBarMetrics:UIBarMetricsDefault];
    [navBar setTitleTextAttributes:@{
        UITextAttributeTextColor : [UIColor whiteColor],
        UITextAttributeTextShadowColor : [UIColor colorWithWhite:0 alpha:0.5]
    }];
    
    UIBarButtonItem *navBarItem = [UIBarButtonItem appearanceWhenContainedIn:
                                   [AwfulNavigationBar class], nil];
    UIImage *navBarButton = [UIImage imageNamed:@"navbar-button.png"];
    [navBarItem setBackgroundImage:navBarButton
                          forState:UIControlStateNormal
                        barMetrics:UIBarMetricsDefault];
    UIImage *navBarLandscapeButton = [[UIImage imageNamed:@"navbar-button-landscape.png"]
                                      resizableImageWithCapInsets:UIEdgeInsetsMake(0, 6, 0, 6)];
    [navBarItem setBackgroundImage:navBarLandscapeButton
                          forState:UIControlStateNormal
                        barMetrics:UIBarMetricsLandscapePhone];
    UIImage *backButton = [[UIImage imageNamed:@"navbar-back.png"]
                           resizableImageWithCapInsets:UIEdgeInsetsMake(0, 13, 0, 6)];
    [navBarItem setBackButtonBackgroundImage:backButton
                                    forState:UIControlStateNormal
                                  barMetrics:UIBarMetricsDefault];
    UIImage *landscapeBackButton = [[UIImage imageNamed:@"navbar-back-landscape.png"]
                                    resizableImageWithCapInsets:UIEdgeInsetsMake(0, 13, 0, 6)];
    [navBarItem setBackButtonBackgroundImage:landscapeBackButton
                                    forState:UIControlStateNormal
                                  barMetrics:UIBarMetricsLandscapePhone];
}

- (UITabBarController *)tabBarController
{
    if ([self.window.rootViewController isKindOfClass:[UITabBarController class]]) {
        return (UITabBarController *)self.window.rootViewController;
    } else if ([self.window.rootViewController isKindOfClass:[UISplitViewController class]]) {
        UISplitViewController *split = (UISplitViewController *)self.window.rootViewController;
        if ([split.viewControllers count] > 0) return split.viewControllers[0];
    }
    return nil;
}

#pragma mark - UIApplicationDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    _instance = self;
    [[AwfulSettings settings] registerDefaults];
    [AwfulDataStack sharedDataStack].initFailureAction = AwfulDataStackInitFailureDelete;
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
    NSUInteger sixtyMB = 1024 * 1024 * 60;
    if ([[NSURLCache sharedURLCache] diskCapacity] < sixtyMB) {
        [[NSURLCache sharedURLCache] setDiskCapacity:sixtyMB];
    }
    
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    UITabBarController *tabBar = [UITabBarController new];
    tabBar.wantsFullScreenLayout = NO;
    tabBar.viewControllers = @[
        [[AwfulForumsListController new] enclosingNavigationController],
        [[AwfulFavoritesViewController new] enclosingNavigationController],
        [[AwfulBookmarksController new] enclosingNavigationController],
        [[AwfulSettingsViewController new] enclosingNavigationController]
    ];
    tabBar.selectedIndex = [[AwfulSettings settings] firstTab];
    tabBar.delegate = self;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        AwfulSplitViewController *splitController = [AwfulSplitViewController new];
        AwfulStartViewController *start = [AwfulStartViewController new];
        splitController.viewControllers = @[ tabBar, [start enclosingNavigationController] ];
        self.window.rootViewController = splitController;
    } else {
        self.window.rootViewController = tabBar;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSFileManager *fileman = [NSFileManager defaultManager];
        NSURL *cssReadme = [[NSBundle mainBundle] URLForResource:@"Custom CSS README"
                                                   withExtension:@"txt"];
        NSURL *documents = [fileman documentDirectory];
        NSURL *readmeDestination = [documents URLByAppendingPathComponent:@"README.txt"];
        NSError *error;
        BOOL ok = [fileman copyItemAtURL:cssReadme
                                   toURL:readmeDestination
                                   error:&error];
        if (!ok && [error code] != NSFileWriteFileExistsError) {
            NSLog(@"error copying README.txt to documents: %@", error);
        }
        NSURL *exampleCSS = [[NSBundle mainBundle] URLForResource:@"posts-view"
                                                    withExtension:@"css"];
        NSURL *cssDestination = [documents URLByAppendingPathComponent:@"example-posts-view.css"];
        ok = [fileman copyItemAtURL:exampleCSS toURL:cssDestination error:&error];
        if (!ok && [error code] != NSFileWriteFileExistsError) {
            NSLog(@"error copying example-posts-view.css to documents: %@", error);
        }
        NSURL *oldData = [documents URLByAppendingPathComponent:@"AwfulData.sqlite"];
        ok = [fileman removeItemAtURL:oldData error:&error];
        if (!ok && [error code] != NSFileNoSuchFileError) {
            NSLog(@"error deleting Documents/AwfulData.sqlite: %@", error);
        }
    });
    
    [self configureAppearance];
    
    [self.window makeKeyAndVisible];
    
    if (!IsLoggedIn()) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self performSelector:@selector(showLoginFormAtLaunch) withObject:nil afterDelay:0];
        } else {
            [self showLoginFormAtLaunch];
        }
    }
    
    if (IsLoggedIn() && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        AwfulSplitViewController *split = (AwfulSplitViewController *)self.window.rootViewController;
        [split performSelector:@selector(showMasterView) withObject:nil afterDelay:0.1];
    }
    
    return YES;
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    if ([[url scheme] compare:@"awful" options:NSCaseInsensitiveSearch] != NSOrderedSame) return NO;
    if (!IsLoggedIn()) return NO;
    
    // Open the forums list: awful://forums
    // Open a specific forum: awful://forums/:forumID
    if ([[url host] isEqualToString:@"forums"]) {
        UINavigationController *nav = self.tabBarController.viewControllers[0];
        [nav popToRootViewControllerAnimated:NO];
        self.tabBarController.selectedViewController = nav;
        // First path component is the /
        if ([[url pathComponents] count] > 1) {
            NSString *forumID = [url pathComponents][1];
            AwfulForum *forum = [AwfulForum firstMatchingPredicate:@"forumID == %@", forumID];
            if (!forum) return NO;
            AwfulForumsListController *list = nav.viewControllers[0];
            [list showForum:forum];
        }
    }
    return YES;
}

#pragma mark - UITabBarControllerDelegate

- (BOOL)tabBarController:(UITabBarController *)tabBarController
    shouldSelectViewController:(UIViewController *)viewController
{
    return IsLoggedIn();
}

#pragma mark - AwfulLoginControllerDelegate

- (void)loginControllerDidLogIn:(AwfulLoginController *)login
{
    [self.window.rootViewController dismissViewControllerAnimated:YES completion:^{
        [[AwfulHTTPClient client] listForumsAndThen:nil];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            AwfulSplitViewController *split = (AwfulSplitViewController *)self.window.rootViewController;
            [split showMasterView];
        }
    }];
}

- (void)loginController:(AwfulLoginController *)login didFailToLogInWithError:(NSError *)error
{
    UIAlertView *alert = [UIAlertView new];
    alert.title = @"Problem Logging In";
    alert.message = @"Double-check your username and password, then try again.";
    [alert addButtonWithTitle:@"Alright"];
    [alert show];
}

@end
