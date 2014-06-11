//  UIBarButtonItem+AwfulConvenience.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

@interface UIBarButtonItem (AwfulConvenience)

/**
 * Returns a UIBarButtonItem of type UIBarButtonSystemItemFlexibleSpace configured with no target.
 */
+ (instancetype)awful_flexibleSpace;

/**
 * Returns a UIBarButtonItem of type UIBarButtonSystemItemFixedSpace.
 */
+ (instancetype)awful_fixedSpace:(CGFloat)width;

/**
 * Returns a UIBarButtonItem with an empty title that, used as -[UINavigationItem backBarButtonItem], shows just the arrow for a back button.
 */
+ (instancetype)awful_emptyBackBarButtonItem;

/**
 * A block called instead of the button item's target and action.
 *
 * @warning Setting an action block and then changing the button item's target or action will likely stop the block from being called.
 */
@property (copy, nonatomic, setter=awful_setActionBlock:) void (^awful_actionBlock)(UIBarButtonItem *sender);

@end
