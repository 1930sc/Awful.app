//  AwfulAppDelegate.m
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulAppDelegate.h"
#import <AFNetworking/AFNetworkActivityIndicatorManager.h>
#import "AwfulAlertView.h"
#import "AwfulBasementViewController.h"
#import "AwfulBookmarkedThreadTableViewController.h"
#import "AwfulCrashlytics.h"
#import "AwfulDataStack.h"
#import "AwfulExpandingSplitViewController.h"
#import "AwfulForumsListController.h"
#import "AwfulHTTPClient.h"
#import "AwfulLaunchImageViewController.h"
#import "AwfulLoginController.h"
#import "AwfulMinusFixURLProtocol.h"
#import "AwfulModels.h"
#import "AwfulNewPMNotifierAgent.h"
#import "AwfulPrivateMessageTableViewController.h"
#import "AwfulRapSheetViewController.h"
#import "AwfulSettings.h"
#import "AwfulSettingsViewController.h"
#import "AwfulThemeLoader.h"
#import "AwfulUIKitAndFoundationCategories.h"
#import "AwfulURLRouter.h"
#import "AwfulVerticalTabBarController.h"
#import <AVFoundation/AVFoundation.h>
#import <Crashlytics/Crashlytics.h>
#import <PocketAPI/PocketAPI.h>

@interface AwfulAppDelegate () <AwfulLoginControllerDelegate, UINavigationControllerDelegate>

@property (strong, nonatomic) AwfulBasementViewController *basementViewController;
@property (strong, nonatomic) AwfulVerticalTabBarController *verticalTabBarController;

@end

@implementation AwfulAppDelegate
{
    AwfulDataStack *_dataStack;
    AwfulURLRouter *_awfulURLRouter;
}

static id _instance;

+ (instancetype)instance
{
    return _instance;
}

- (void)logOut
{
    // Destroy root view controller before deleting data store so there's no lingering references to persistent objects or their controllers.
    [self destroyRootViewControllerStack];
    
    // Reset the HTTP client so it gets remade (if necessary) with the default URL.
    [[AwfulHTTPClient client] reset];
    
    // Logging out doubles as an "empty cache" button.
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
        [cookieStorage deleteCookie:cookie];
    }
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    [[AwfulSettings settings] reset];
    [[PocketAPI sharedAPI] logout];
    [_dataStack deleteStoreAndResetStack];
    
    [UIView transitionWithView:self.window
                      duration:0.3
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        [UIView performWithoutAnimation:^{
                            self.window.rootViewController = [AwfulLaunchImageViewController new];
                        }];
                    } completion:^(BOOL finished) {
                        AwfulLoginController *loginController = [AwfulLoginController new];
                        loginController.delegate = self;
                        [self.window.rootViewController presentViewController:[loginController enclosingNavigationController] animated:YES completion:nil];
                    }];
}

- (NSManagedObjectContext *)managedObjectContext
{
    return _dataStack.managedObjectContext;
}

#pragma mark - UIApplicationDelegate

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    StartCrashlytics();
    _instance = self;
    [[AwfulSettings settings] registerDefaults];
    [[AwfulSettings settings] migrateOldSettings];
    
    NSURL *storeURL = [NSFileManager.defaultManager.documentDirectory URLByAppendingPathComponent:@"AwfulData.sqlite"];
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Awful" withExtension:@"momd"];
    _dataStack = [[AwfulDataStack alloc] initWithStoreURL:storeURL modelURL:modelURL];
    
    [AwfulHTTPClient client].managedObjectContext = _dataStack.managedObjectContext;
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
    [NSURLCache setSharedURLCache:[[NSURLCache alloc] initWithMemoryCapacity:5 * 1024 * 1024
                                                                diskCapacity:50 * 1024 * 1024
                                                                    diskPath:nil]];
    [NSURLProtocol registerClass:[AwfulMinusFixURLProtocol class]];
    
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    if ([AwfulHTTPClient client].loggedIn) {
        self.window.rootViewController = [self createRootViewControllerStack];
        [self themeDidChange];
    } else {
        self.window.rootViewController = [AwfulLaunchImageViewController new];
    }
    [self.window makeKeyAndVisible];
    return YES;
}

#define CRASHLYTICS_ENABLED defined(CRASHLYTICS_API_KEY) && !DEBUG

static inline void StartCrashlytics(void)
{
    #if CRASHLYTICS_ENABLED
        [Crashlytics startWithAPIKey:CRASHLYTICS_API_KEY];
        SetCrashlyticsUsername();
    #endif
}

static inline void SetCrashlyticsUsername(void)
{
    #if CRASHLYTICS_ENABLED && AWFUL_BETA
        [Crashlytics setUserName:[AwfulSettings settings].username];
    #endif
}

- (UIViewController *)createRootViewControllerStack
{
    NSMutableArray *viewControllers = [NSMutableArray new];
    UINavigationController *nav;
    UIViewController *vc;
    
    vc = [[AwfulForumsListController alloc] initWithManagedObjectContext:_dataStack.managedObjectContext];
    vc.restorationIdentifier = ForumListControllerIdentifier;
    nav = [vc enclosingNavigationController];
    nav.restorationIdentifier = ForumNavigationControllerIdentifier;
    [viewControllers addObject:nav];
    
    vc = [[AwfulBookmarkedThreadTableViewController alloc] initWithManagedObjectContext:_dataStack.managedObjectContext];
    vc.restorationIdentifier = BookmarksControllerIdentifier;
    nav = [vc enclosingNavigationController];
    nav.restorationIdentifier = BookmarksNavigationControllerIdentifier;
    [viewControllers addObject:nav];
    
    if ([AwfulSettings settings].canSendPrivateMessages) {
        vc = [[AwfulPrivateMessageTableViewController alloc] initWithManagedObjectContext:_dataStack.managedObjectContext];
        vc.restorationIdentifier = MessagesListControllerIdentifier;
        nav = [vc enclosingNavigationController];
        nav.restorationIdentifier = MessagesNavigationControllerIdentifier;
        [viewControllers addObject:nav];
    }

    vc = [AwfulRapSheetViewController new];
    vc.restorationIdentifier = LepersColonyViewControllerIdentifier;
    nav = [vc enclosingNavigationController];
    nav.restorationIdentifier = LepersColonyNavigationControllerIdentifier;
    [viewControllers addObject:nav];
    
    vc = [[AwfulSettingsViewController alloc] initWithManagedObjectContext:_dataStack.managedObjectContext];
    vc.restorationIdentifier = SettingsViewControllerIdentifier;
    nav = [vc enclosingNavigationController];
    nav.restorationIdentifier = SettingsNavigationControllerIdentifier;
    [viewControllers addObject:nav];
    
    [viewControllers makeObjectsPerformSelector:@selector(setDelegate:) withObject:self];
    [viewControllers makeObjectsPerformSelector:@selector(setRestorationClass:) withObject:nil];
    
    UIViewController *rootViewController;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.basementViewController = [[AwfulBasementViewController alloc] initWithViewControllers:viewControllers];
        self.basementViewController.restorationIdentifier = RootViewControllerIdentifier;
        rootViewController = self.basementViewController;
    } else {
        self.verticalTabBarController = [[AwfulVerticalTabBarController alloc] initWithViewControllers:viewControllers];
        self.verticalTabBarController.restorationIdentifier = RootViewControllerIdentifier;
        AwfulExpandingSplitViewController *splitViewController = [[AwfulExpandingSplitViewController alloc] initWithViewControllers:@[ self.verticalTabBarController ]];
        splitViewController.restorationIdentifier = RootExpandingSplitViewControllerIdentifier;
        rootViewController = splitViewController;
    }
    
    _awfulURLRouter = [[AwfulURLRouter alloc] initWithRootViewController:rootViewController
                                                    managedObjectContext:_dataStack.managedObjectContext];
    return rootViewController;
}

- (void)destroyRootViewControllerStack
{
    self.basementViewController = nil;
    self.verticalTabBarController = nil;
    self.window.rootViewController = nil;
    _awfulURLRouter = nil;
}

static NSString * const RootViewControllerIdentifier = @"AwfulRootViewController";
static NSString * const RootExpandingSplitViewControllerIdentifier = @"AwfulRootExpandingSplitViewController";

static NSString * const ForumListControllerIdentifier = @"AwfulForumListController";
static NSString * const BookmarksControllerIdentifier = @"AwfulBookmarksController";
static NSString * const MessagesListControllerIdentifier = @"AwfulPrivateMessagesListController";
static NSString * const LepersColonyViewControllerIdentifier = @"AwfulLepersColonyViewController";
static NSString * const SettingsViewControllerIdentifier = @"AwfulSettingsViewController";

static NSString * const ForumNavigationControllerIdentifier = @"AwfulForumNavigationController";
static NSString * const BookmarksNavigationControllerIdentifier = @"AwfulBookmarksNavigationController";
static NSString * const MessagesNavigationControllerIdentifier = @"AwfulMessagesNavigationController";
static NSString * const LepersColonyNavigationControllerIdentifier = @"AwfulLepersColonyNavigationController";
static NSString * const SettingsNavigationControllerIdentifier = @"AwfulSettingsNavigationController";

- (void)themeDidChange
{
    self.window.tintColor = AwfulTheme.currentTheme[@"tintColor"];
	[self.window.rootViewController themeDidChange];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    if (![AwfulHTTPClient client].loggedIn) {
        AwfulLoginController *login = [AwfulLoginController new];
        login.delegate = self;
        [self.window.rootViewController presentViewController:[login enclosingNavigationController] animated:NO completion:nil];
    }
    
    [self ignoreSilentSwitchWhenPlayingEmbeddedVideo];
    
    [[AwfulNewPMNotifierAgent agent] checkForNewMessages];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(settingsDidChange:)
                                                 name:AwfulSettingsDidChangeNotification
                                               object:nil];
    
    [[PocketAPI sharedAPI] setURLScheme:@"awful-pocket-login"];
    [[PocketAPI sharedAPI] setConsumerKey:@"13890-9e69d4d40af58edc2ef13ca0"];
    
    return YES;
}

- (void)settingsDidChange:(NSNotification *)note
{
    NSArray *changes = note.userInfo[AwfulSettingsDidChangeSettingsKey];
    if ([changes containsObject:AwfulSettingsKeys.canSendPrivateMessages]) {
        
        // Add the private message list if it's needed, or remove it if it isn't.
        NSMutableArray *roots = [(self.basementViewController ?: self.verticalTabBarController) mutableArrayValueForKey:@"viewControllers"];
        NSUInteger i = [roots indexOfObjectPassingTest:^(UINavigationController *nav, NSUInteger i, BOOL *stop) {
            return [nav.viewControllers.firstObject isKindOfClass:[AwfulPrivateMessageTableViewController class]];
        }];
        if ([AwfulSettings settings].canSendPrivateMessages) {
            if (i == NSNotFound) {
                UINavigationController *nav = [[[AwfulPrivateMessageTableViewController alloc] initWithManagedObjectContext:_dataStack.managedObjectContext] enclosingNavigationController];
                [roots insertObject:nav atIndex:2];
            }
        } else {
            if (i != NSNotFound) {
                [roots removeObjectAtIndex:i];
            }
        }
    }
    
    if ([changes containsObject:AwfulSettingsKeys.username]) {
        SetCrashlyticsUsername();
    }
    
	for (NSString *change in changes) {
		if ([change isEqualToString:AwfulSettingsKeys.darkTheme] || [change hasPrefix:@"theme"]) {
			
			// When the user initiates a theme change, transition from one theme to the other with a full-screen screenshot fading into the reconfigured interface.
			UIView *snapshot = [self.window snapshotViewAfterScreenUpdates:NO];
			[self.window addSubview:snapshot];
			[self themeDidChange];
			[UIView transitionFromView:snapshot
                                toView:nil
                              duration:0.2
                               options:UIViewAnimationOptionTransitionCrossDissolve
                            completion:^(BOOL finished)
            {
				[snapshot removeFromSuperview];
			}];
            break;
		}
	}
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [[AwfulNewPMNotifierAgent agent] checkForNewMessages];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    NSError *error;
    BOOL ok = [_dataStack.managedObjectContext save:&error];
    if (!ok) {
        NSLog(@"%s error saving main managed object context: %@", __PRETTY_FUNCTION__, error);
    }
}

- (void)ignoreSilentSwitchWhenPlayingEmbeddedVideo
{
    NSError *error;
    BOOL ok = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback
                                                     error:&error];
    if (!ok) {
        NSLog(@"error setting shared audio session category: %@", error);
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    if (![AwfulHTTPClient client].loggedIn) return;
    
	// Get a URL from the pasteboard, and fallback to checking the string pasteboard
	// in case some app is a big jerk and only sets a string value.
    NSURL *url = [UIPasteboard generalPasteboard].URL;
    if (!url) {
        url = [NSURL awful_URLWithString:[UIPasteboard generalPasteboard].string];
    }
    if (![url awfulURL] || [[url scheme] compare:@"awful" options:NSCaseInsensitiveSearch] == NSOrderedSame) return;
    
    // Don't ask about the same URL over and over.
    if ([[AwfulSettings settings].lastOfferedPasteboardURL isEqualToString:[url absoluteString]]) {
        return;
    }
    [AwfulSettings settings].lastOfferedPasteboardURL = [url absoluteString];
    NSMutableString *abbreviatedURL = [[url awful_absoluteUnicodeString] mutableCopy];
    NSRange upToHost = [abbreviatedURL rangeOfString:@"://"];
    if (upToHost.location == NSNotFound) {
        upToHost = [abbreviatedURL rangeOfString:@":"];
    }
    if (upToHost.location != NSNotFound) {
        upToHost.length += upToHost.location;
        upToHost.location = 0;
        [abbreviatedURL deleteCharactersInRange:upToHost];
    }
    if ([abbreviatedURL length] > 60) {
        [abbreviatedURL replaceCharactersInRange:NSMakeRange(55, [abbreviatedURL length] - 55)
                                      withString:@"…"];
    }
    NSString *message = [NSString stringWithFormat:@"Would you like to open this URL in Awful?\n\n%@", abbreviatedURL];
    [AwfulAlertView showWithTitle:@"Open in Awful"
                          message:message
                    noButtonTitle:@"Cancel"
                   yesButtonTitle:@"Open"
                     onAcceptance:^{ [self openAwfulURL:[url awfulURL]]; }];
}

- (BOOL)application:(UIApplication *)application shouldSaveApplicationState:(NSCoder *)coder
{
    return [AwfulHTTPClient client].isLoggedIn;
}

- (void)application:(UIApplication *)application willEncodeRestorableStateWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:0 forKey:InterfaceVersionKey];
}

- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(NSCoder *)coder
{
    NSNumber *userInterfaceIdiom = [coder decodeObjectForKey:UIApplicationStateRestorationUserInterfaceIdiomKey];
    return userInterfaceIdiom.integerValue == UI_USER_INTERFACE_IDIOM() && [AwfulHTTPClient client].loggedIn;
}

- (UIViewController *)application:(UIApplication *)application viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    return ViewControllerWithRestorationIdentifier(self.window.rootViewController, identifierComponents.lastObject);
}

static UIViewController * ViewControllerWithRestorationIdentifier(UIViewController *viewController, NSString *identifier)
{
    if ([viewController.restorationIdentifier isEqualToString:identifier]) return viewController;
    if (![viewController respondsToSelector:@selector(viewControllers)]) return nil;
    for (UIViewController *child in [viewController valueForKey:@"viewControllers"]) {
        UIViewController *found = ViewControllerWithRestorationIdentifier(child, identifier);
        if (found) return found;
    }
    return nil;
}

/**
 * Incremented whenever the state-preservable/restorable user interface changes so restoration code can migrate old saved state.
 */
static NSString * const InterfaceVersionKey = @"AwfulInterfaceVersion";

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    if (!AwfulHTTPClient.client.loggedIn) return NO;
    if ([self openAwfulURL:url]) return YES;
    return [PocketAPI.sharedAPI handleOpenURL:url];
}

- (BOOL)openAwfulURL:(NSURL *)url
{
    return [_awfulURLRouter routeURL:url];
}

#pragma mark - AwfulLoginControllerDelegate

- (void)loginController:(AwfulLoginController *)login
         didLogInAsUser:(AwfulUser *)user
{
    NSString *appVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
    AwfulSettings *settings = [AwfulSettings settings];
    settings.lastForcedUserInfoUpdateVersion = appVersion;
    settings.username = user.username;
    SetCrashlyticsUsername();
    settings.userID = user.userID;
    settings.canSendPrivateMessages = user.canReceivePrivateMessages;
    [[AwfulHTTPClient client] listForumHierarchyAndThen:nil];
    [UIView transitionWithView:self.window
                      duration:0.3
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        [UIView performWithoutAnimation:^{
                            [login dismissViewControllerAnimated:NO completion:nil];
                            self.window.rootViewController = [self createRootViewControllerStack];;
                        }];
                    } completion:nil];
}

- (void)loginController:(AwfulLoginController *)login didFailToLogInWithError:(NSError *)error
{
    [AwfulAlertView showWithTitle:@"Problem Logging In"
                          message:@"Double-check your username and password, then try again."
                      buttonTitle:@"OK"
                       completion:nil];
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated
{
    [navigationController setToolbarHidden:(viewController.toolbarItems.count == 0) animated:animated];
}

@end
