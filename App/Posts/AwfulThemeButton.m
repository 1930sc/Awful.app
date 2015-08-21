//  AwfulThemeButton.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThemeButton.h"

@implementation AwfulThemeButton

- (instancetype)initWithThemeColor:(UIColor *)themeColor
{
    if ((self = [super initWithFrame:CGRectZero])) {
        _themeColor = themeColor;
        self.accessibilityLabel = themeColor.accessibilityLabel;
        self.opaque = NO;
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    NSAssert(nil, @"Use -initWithThemeColor: instead");
    return [self initWithThemeColor:nil];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSAssert(nil, @"Use -initWithThemeColor: instead");
    return [self initWithThemeColor:nil];
}

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(32, 32);
}

- (void)drawRect:(CGRect)rect
{
    static const CGFloat borderWidth = 2;
    UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(self.bounds, borderWidth, borderWidth)];
    path.lineWidth = borderWidth;
    [self.themeColor set];
    [path fill];
    if (self.selected) {
        [self.tintColor set];
        [path stroke];
    }
}

@end
