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
    self = [super initWithFrame:CGRectMake(0, 0, 320, 50)];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0.051 green:0.404 blue:0.592 alpha:1];
        CGRect textFrame = (CGRect){ .origin.x = 12, .size = self.bounds.size };
        textFrame.size.width -= textFrame.origin.x * 2;
        self.textLabel = [[UILabel alloc] initWithFrame:textFrame];
        self.textLabel.font = [UIFont boldSystemFontOfSize:19];
        self.textLabel.textColor = [UIColor whiteColor];
        self.textLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.textLabel.backgroundColor = self.backgroundColor;
        [self addSubview:self.textLabel];
    }
    return self;
}

@end
