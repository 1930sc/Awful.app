//
//  AwfulForumHeader.m
//  Awful
//
//  Created by Sean Berry on 2/2/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForumHeader.h"

@implementation AwfulForumHeader

- (id)init
{
    self = [super initWithFrame:CGRectMake(0, 0, 320, [[self class] height])];
    if (self) {
        CGRect textFrame = (CGRect){ .origin.x = 12, .size = self.bounds.size };
        textFrame.size.width -= textFrame.origin.x * 2;
        textFrame.size.height -= 9;
        self.textLabel = [[UILabel alloc] initWithFrame:textFrame];
        self.textLabel.font = [UIFont boldSystemFontOfSize:19];
        self.textLabel.textColor = [UIColor whiteColor];
        self.textLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self addSubview:self.textLabel];
    }
    return self;
}

+ (CGFloat)height
{
    return 30;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
    self.textLabel.backgroundColor = backgroundColor;
}

@end
