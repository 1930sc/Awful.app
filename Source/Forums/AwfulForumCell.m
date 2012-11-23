//
//  AwfulForumCell.m
//  Awful
//
//  Created by Nolan Waite on 2012-09-22.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForumCell.h"
#import "AwfulTheme.h"

@interface AwfulForumCell ()

@property (weak, nonatomic) UIButton *expandButton;

@property (weak, nonatomic) UIButton *favoriteButton;

@end


@implementation AwfulForumCell

#pragma mark - Init

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        UIButton *expandButton = [UIButton new];
        [expandButton addTarget:self
                         action:@selector(toggleExpanded)
               forControlEvents:UIControlEventTouchUpInside];
        [expandButton setImage:[AwfulTheme currentTheme].forumCellExpandButtonNormalImage
                      forState:UIControlStateNormal];
        [expandButton setImage:[AwfulTheme currentTheme].forumCellExpandButtonSelectedImage
                      forState:UIControlStateSelected];
        expandButton.contentMode = UIViewContentModeCenter;
        [self updateExpandButtonAccessibilityLabel];
        expandButton.accessibilityLabel = @"List subforums";
        [self.contentView addSubview:expandButton];
        _expandButton = expandButton;
        self.imageView.userInteractionEnabled = YES;
        self.textLabel.font = [UIFont boldSystemFontOfSize:15];
        self.textLabel.numberOfLines = 2;
    }
    return self;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    return [self initWithReuseIdentifier:reuseIdentifier];
}

#pragma mark - Favorite

- (void)setFavorite:(BOOL)isFavorite
{
    if (_favorite == isFavorite) return;
    _favorite = isFavorite;
    self.favoriteButton.selected = isFavorite;
    [self updateFavoriteButtonAccessibilityLabel];
}

- (void)setShowsFavorite:(BOOL)showsFavorite
{
    if (_showsFavorite == showsFavorite) return;
    _showsFavorite = showsFavorite;
    if (showsFavorite) {
        if (!self.favoriteButton) {
            self.favoriteButton = CreateFavoriteButtonWithTarget(self);
            [self.contentView addSubview:self.favoriteButton];
        }
        self.favoriteButton.selected = self.favorite;
        [self updateFavoriteButtonAccessibilityLabel];
    } else {
        [self.favoriteButton removeFromSuperview];
    }
    [self setNeedsLayout];
}

- (void)updateFavoriteButtonAccessibilityLabel
{
    if (self.favoriteButton.selected) {
        self.favoriteButton.accessibilityLabel = @"Remove from favorites";
    } else {
        self.favoriteButton.accessibilityLabel = @"Add to favorites";
    }
}

static UIButton *CreateFavoriteButtonWithTarget(id target)
{
    UIButton *favoriteButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [favoriteButton setImage:[AwfulTheme currentTheme].forumCellFavoriteButtonNormalImage
                    forState:UIControlStateNormal];
    [favoriteButton setImage:[AwfulTheme currentTheme].forumCellFavoriteButtonSelectedImage
                    forState:UIControlStateSelected];
    [favoriteButton addTarget:target
                       action:@selector(toggleFavorite)
             forControlEvents:UIControlEventTouchUpInside];
    favoriteButton.contentMode = UIViewContentModeCenter;
    [favoriteButton sizeToFit];
    CGRect bounds = favoriteButton.bounds;
    bounds.size.width += 40;
    favoriteButton.bounds = bounds;
    return favoriteButton;
}

- (void)toggleFavorite
{
    self.favorite = !self.favorite;
    if ([self.delegate respondsToSelector:@selector(forumCellDidToggleFavorite:)]) {
        [self.delegate forumCellDidToggleFavorite:self];
    }
}

#pragma mark - Expanded

- (void)setExpanded:(BOOL)expanded
{
    if (_expanded == expanded) return;
    _expanded = expanded;
    [self.expandButton setSelected:expanded];
    if (self.showsExpanded) {
        if ([self.delegate respondsToSelector:@selector(forumCellDidToggleExpanded:)]) {
            [self.delegate forumCellDidToggleExpanded:self];
        }
    }
}

- (void)updateExpandButtonAccessibilityLabel
{
    if (self.expandButton.selected) {
        self.expandButton.accessibilityLabel = @"Hide subforums";
    } else {
        self.expandButton.accessibilityLabel = @"List subforums";
    }
}

- (void)setShowsExpanded:(AwfulForumCellShowsExpanded)showsExpanded
{
    if (_showsExpanded == showsExpanded) return;
    _showsExpanded = showsExpanded;
    self.expandButton.hidden = showsExpanded != AwfulForumCellShowsExpandedButton;
}

- (void)toggleExpanded
{
    self.expanded = !self.expanded;
}

#pragma mark - Size and layout

static const CGFloat StarLeftMargin = 11;

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect textFrame = self.textLabel.frame;
    if (self.showsExpanded == AwfulForumCellShowsExpandedNever) {
        self.expandButton.frame = CGRectZero;
    } else {
        self.expandButton.frame = CGRectMake(0, 0, 40, self.contentView.bounds.size.height);
        CGFloat newOriginX = CGRectGetMaxX(self.expandButton.frame) + 4;
        textFrame.size.width -= newOriginX - textFrame.origin.x;
        textFrame.origin.x = newOriginX;
    }
    if (self.favoriteButton) {
        self.favoriteButton.center = CGPointMake(CGRectGetMaxX(textFrame) - StarLeftMargin,
                                                 CGRectGetMidY(textFrame));
        textFrame.size.width -= self.favoriteButton.imageView.bounds.size.width + StarLeftMargin;
    }
    self.textLabel.frame = textFrame;
}

@end
