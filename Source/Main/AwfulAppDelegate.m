//
//  AwfulAppDelegate.m
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright Regular Berry Software LLC 2010. All rights reserved.
//

#import "AwfulAppDelegate.h"
#import "AwfulSplitViewController.h"
#import "AwfulSettings.h"
#import "AwfulLoginController.h"
#import "AwfulCSSTemplate.h"
#import "AwfulForumsListController.h"
#import "AwfulFavoritesViewController.h"
#import "AwfulBookmarksController.h"
#import "AwfulSettingsViewController.h"
#import "GRMustache.h"

@interface AwfulAppDelegate () <UITabBarControllerDelegate, AwfulLoginControllerDelegate>

@end


@implementation AwfulAppDelegate

static AwfulAppDelegate *_instance;

+ (AwfulAppDelegate *)instance
{
    return _instance;
}

#pragma mark - Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    _instance = self;
    [[AwfulSettings settings] registerDefaults];
    [AwfulDataStack sharedDataStack].initFailureAction = AwfulDataStackInitFailureDelete;
    if (DEBUG) [GRMustache preventNSUndefinedKeyExceptionAttack];
    
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    UITabBarController *tabBar = [UITabBarController new];
    tabBar.wantsFullScreenLayout = NO;
    tabBar.viewControllers = @[
        [[UINavigationController alloc] initWithRootViewController:[AwfulForumsListController new]],
        [[UINavigationController alloc] initWithRootViewController:[AwfulFavoritesViewController new]],
        [[UINavigationController alloc] initWithRootViewController:[AwfulBookmarksController new]],
        [[UINavigationController alloc] initWithRootViewController:[AwfulSettingsViewController new]]
    ];
    tabBar.selectedIndex = [[AwfulSettings settings] firstTab];
    tabBar.delegate = self;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        AwfulSplitViewController *splitController = [AwfulSplitViewController new];
        UIViewController *gray = [UIViewController new];
        gray.view.backgroundColor = [UIColor darkGrayColor];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:gray];
        splitController.viewControllers = @[ tabBar, nav ];
        self.window.rootViewController = splitController;
    } else {
        self.window.rootViewController = tabBar;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSFileManager *fileman = [NSFileManager defaultManager];
        NSURL *cssReadme = [[NSBundle mainBundle] URLForResource:@"README"
                                                   withExtension:@"txt"];
        NSURL *documents = [[fileman URLsForDirectory:NSDocumentDirectory
                                            inDomains:NSUserDomainMask] lastObject];
        NSURL *destination = [documents URLByAppendingPathComponent:@"README.txt"];
        NSError *error;
        BOOL ok = [fileman copyItemAtURL:cssReadme
                                   toURL:destination
                                   error:&error];
        if (!ok && [error code] != NSFileWriteFileExistsError) {
            NSLog(@"error copying README.txt to documents: %@", error);
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
    
    if (IsLoggedIn()) {
        AwfulSplitViewController *split = (AwfulSplitViewController *)self.window.rootViewController;
        [split performSelector:@selector(showMasterView) withObject:nil afterDelay:0.1];
    }
    
    return YES;
}

- (BOOL)tabBarController:(UITabBarController *)tabBarController
    shouldSelectViewController:(UIViewController *)viewController
{
    return IsLoggedIn();
}

- (void)showLoginFormAtLaunch
{
    [self showLoginFormIsAtLaunch:YES andThen:nil];
}

- (void)showLoginFormIsAtLaunch:(BOOL)isAtLaunch andThen:(void (^)(void))callback
{
    AwfulLoginController *login = [AwfulLoginController new];
    login.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:login];
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

- (void)configureAppearance
{
    id navBar = [UINavigationBar appearance];
    AwfulCSSTemplate *css = [AwfulCSSTemplate defaultTemplate];
    UIImage *portrait = [css navigationBarImageForMetrics:UIBarMetricsDefault];
    [navBar setBackgroundImage:portrait forBarMetrics:UIBarMetricsDefault];
    UIImage *landscape = [css navigationBarImageForMetrics:UIBarMetricsLandscapePhone];
    [navBar setBackgroundImage:landscape forBarMetrics:UIBarMetricsLandscapePhone];
    [navBar setTitleTextAttributes:@{ UITextAttributeTextColor : [UIColor whiteColor] }];
    id navBarItem = [UIBarButtonItem appearanceWhenContainedIn:[UINavigationBar class], nil];
    [navBarItem setTintColor:[UIColor colorWithRed:46.0/255 green:146.0/255 blue:190.0/255 alpha:1]];
    
    // On iPad, image pickers appear in popovers. And they look awful with the navigation bar and
    // bar item changes above. The obvious answer is to clear the customizations using
    // +appearanceWhenContainedIn:[UIPopoverController class], except the top-level split view
    // controller uses a popover to show the master view in portrait, so now it gets unstyled.
    // No problem, right? Just make a UIPopoverController subclass, clear its custom appearance,
    // and use that for the image picker popover. Except that still clears the appearance in the
    // split view controller's popover, even though it's not an instance of my subclass.
    // Not sure why.
    //
    // This works for now, though if we use popovers for other things we'll need to style them too.
    // (We'll use the default look for the picker on the phone too, it better matches the reply view.)
    id pickerNavBar = [UINavigationBar appearanceWhenContainedIn:[UIImagePickerController class], nil];
    [pickerNavBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
    [pickerNavBar setBackgroundImage:nil forBarMetrics:UIBarMetricsLandscapePhone];
    id pickerNavBarItem = [UIBarButtonItem appearanceWhenContainedIn:[UIImagePickerController class], nil];
    [pickerNavBarItem setTintColor:nil];
}

#pragma mark - AwfulLoginControllerDelegate

- (void)loginControllerDidLogIn:(AwfulLoginController *)login
{
    [self.window.rootViewController dismissViewControllerAnimated:YES completion:^{
        [[AwfulHTTPClient sharedClient] forumsListOnCompletion:nil onError:nil];
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

#pragma mark - Relaying errors

- (void)requestFailed:(NSError *)error
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Network Error"
                                                    message:[error localizedDescription]
                                                   delegate:nil
                                          cancelButtonTitle:@"Drats"
                                          otherButtonTitles:nil];
    [alert show];
}

@end
