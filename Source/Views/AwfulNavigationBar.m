//  AwfulNavigationBar.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulNavigationBar.h"

@implementation AwfulNavigationBar

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    self.tintColor = [UIColor whiteColor];
    self.barTintColor = [UIColor colorWithRed:0.078 green:0.514 blue:0.694 alpha:1];
    
    // Setting the barStyle to UIBarStyleBlack results in an appropriate status bar style.
    self.barStyle = UIBarStyleBlack;
    
    UILongPressGestureRecognizer *longPress = [UILongPressGestureRecognizer new];
    [longPress addTarget:self action:@selector(longPress:)];
    [self addGestureRecognizer:longPress];
    return self;
}

- (void)longPress:(UILongPressGestureRecognizer *)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateBegan) return;
    if (!self.backItem) return;
    UINavigationController *nav = self.delegate;
    if (![nav isKindOfClass:[UINavigationController class]]) return;
    
    // Find the leftmost, widest subview whose width is less than half of the navbar's.
    NSMutableArray *subviews = [self.subviews mutableCopy];
    [subviews filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(UIView *view, NSDictionary *bindings) {
        return CGRectGetWidth(view.frame) < CGRectGetWidth(self.frame) / 2;
    }]];
    [subviews sortUsingComparator:^(UIView *a, UIView *b) {
        if (CGRectGetMinX(a.frame) < CGRectGetMinX(b.frame)) {
            return NSOrderedAscending;
        } else if (CGRectGetMinX(a.frame) > CGRectGetMinX(b.frame)) {
            return NSOrderedDescending;
        }
        if (CGRectGetWidth(a.frame) > CGRectGetWidth(b.frame)) {
            return NSOrderedAscending;
        } else if (CGRectGetWidth(a.frame) < CGRectGetWidth(b.frame)) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];
    UIView *leftmost = subviews[0];
    
    if (CGRectContainsPoint(leftmost.frame, [recognizer locationInView:self])) {
        [nav popToRootViewControllerAnimated:YES];
    }
}

@end
