//
//  AwfulThreadTagButton.m
//  Awful
//
//  Created by Nolan Waite on 2013-05-22.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulThreadTagButton.h"

@interface AwfulThreadTagButton ()

@property (nonatomic) UIImageView *secondaryTagImageView;

@end


@implementation AwfulThreadTagButton

- (UIImage *)secondaryTagImage
{
    return self.secondaryTagImageView.image;
}

- (void)setSecondaryTagImage:(UIImage *)secondaryTagImage
{
    if (secondaryTagImage && !self.secondaryTagImageView) {
        self.secondaryTagImageView = [UIImageView new];
        [self addSubview:self.secondaryTagImageView];
        [self setNeedsLayout];
    }
    self.secondaryTagImageView.image = secondaryTagImage;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect tagFrame = self.imageView.frame;
    self.secondaryTagImageView.frame = (CGRect){
        .origin = tagFrame.origin,
        .size = { CGRectGetWidth(tagFrame) / 2, CGRectGetHeight(tagFrame) / 2 },
    };
}

@end
