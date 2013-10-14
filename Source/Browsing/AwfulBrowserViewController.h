//  AwfulBrowserViewController.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"

/**
 * An AwfulBrowserViewController displays web content with a minimal browser interface.
 */
@interface AwfulBrowserViewController : AwfulViewController

/**
 * The URL of the current page.
 */
@property (strong, nonatomic) NSURL *URL;

@end
