//
//  AwfulNavigationBar.m
//  Awful
//
//  Created by Nolan Waite on 2012-11-14.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulNavigationBar.h"

@implementation AwfulNavigationBar

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
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
    UIView *leftmost;
    for (UIView *subview in self.subviews) {
        if (leftmost && CGRectGetMinX(leftmost.frame) < CGRectGetMinX(subview.frame)) continue;
        if (subview.frame.size.width > self.frame.size.width / 2) continue;
        leftmost = subview;
    }
    CGRect backFrame = leftmost ? leftmost.frame : CGRectMake(5, 0, 100, 40);
    if (CGRectContainsPoint(backFrame, [recognizer locationInView:self])) {
        [nav popToRootViewControllerAnimated:YES];
    }
}

@end
