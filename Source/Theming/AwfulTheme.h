//  AwfulTheme.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>

/**
 * An AwfulTheme stores colors, fonts, and other easily-customizable design parameters.
 */
@interface AwfulTheme : NSObject

/**
 * Returns an initialized AwfulTheme for the default look or the dark look, depending on the current darkTheme setting.
 */
+ (instancetype)currentTheme;

/**
 * Returns an initialized AwfulTheme that may/may not be customized for a specific fourm
 */
+ (instancetype)currentThemeForForumId:(NSString*)forumId;

/**
 * Returns an initialized AwfulTheme. This is the designated initializer.
 */
- (id)initWithName:(NSString *)name dictionary:(NSDictionary *)dictionary;

/**
 * The source dictionary for this theme. Conventions are:
 *
 * - Colors have a key ending with "Color" and are written as CSS hexadecimal color codes with an optional alpha component (defaults to FF) at the end. For example: "backgroundColor" = "#000000" or, equivalently, "backgroundColor" = "#000000ff". Or, they can be the basename of an image in the main bundle to use as a pattern.
 * - Stylesheets have a key ending in "CSS" and are written as a filename of a resource in the main bundle. The file's contents are returned as a string.
 */
@property (readonly, copy, nonatomic) NSDictionary *dictionary;

/**
 * The name of the theme, usable by +[AwfulThemeLoader themeNamed:].
 */
@property (readonly, copy, nonatomic) NSString *name;

/**
 * A descriptive name of the theme, appropriate for e.g. a UILabel.
 */
@property (readonly, copy, nonatomic) NSString *descriptiveName;

/**
 * A color representative of the theme.
 */
@property (readonly, strong, nonatomic) UIColor *descriptiveColor;

/**
 * YES if the theme is forum-specific, NO if it applies to all forums (the default).
 */
@property (readonly, assign, nonatomic) BOOL forumSpecific;

/**
 * An AwfulTheme to use for looking up values not set by this theme.
 *
 * In the plist, the key is "parent"  and the value is the name of another theme. Defaults to the theme called "default".
 */
@property (weak, nonatomic) AwfulTheme *parentTheme;

/**
 * Returns an NSString or a UIColor for the given key.
 */
- (id)objectForKeyedSubscript:(id)key;

@end
