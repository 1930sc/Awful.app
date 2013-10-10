//  AwfulVerticalTabBar.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulVerticalTabBar.h"
#import "AwfulTabBarButton.h"

@implementation AwfulVerticalTabBar
{
    NSMutableArray *_buttons;
    NSMutableArray *_buttonConstraints;
}

- (id)initWithItems:(NSArray *)items
{
    if (!(self = [super init])) return nil;
    _buttons = [NSMutableArray new];
    _buttonConstraints = [NSMutableArray new];
    self.items = items;
    self.backgroundColor = [UIColor blackColor];
    return self;
}

- (void)setItems:(NSArray *)items
{
    if (_items == items) return;
    _items = [items copy];
    while (_items.count < _buttons.count) {
        UIButton *button = _buttons.lastObject;
        [button removeFromSuperview];
        [_buttons removeLastObject];
    }
    while (_items.count > _buttons.count) {
        UIButton *button = [AwfulTabBarButton new];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [button addTarget:self action:@selector(didTapItemButton:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:button];
        [_buttons addObject:button];
    }
    [_buttons enumerateObjectsUsingBlock:^(AwfulTabBarButton *button, NSUInteger i, BOOL *stop) {
        UITabBarItem *item = _items[i];
        [button setImage:item.image];
    }];
    [self removeAllConstraints];
    [self setNeedsUpdateConstraints];
    if (![_items containsObject:self.selectedItem]) {
        self.selectedItem = _items[0];
    }
}

- (void)removeAllConstraints
{
    [self removeConstraints:_buttonConstraints];
    [_buttonConstraints removeAllObjects];
}

- (void)setSelectedItem:(UITabBarItem *)selectedItem
{
    if (_selectedItem == selectedItem) return;
    _selectedItem = selectedItem;
    NSUInteger selectedIndex = [self.items indexOfObject:self.selectedItem];
    [_buttons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger i, BOOL *stop) {
        button.selected = (i == selectedIndex);
    }];
}

- (void)didTapItemButton:(UIButton *)button
{
    NSUInteger i = [_buttons indexOfObject:button];
    UITabBarItem *item = _items[i];
    self.selectedItem = item;
    [self.delegate tabBar:self didSelectItem:item];
}

- (void)setInsets:(UIEdgeInsets)insets
{
    _insets = insets;
    [self removeAllConstraints];
    [self setNeedsUpdateConstraints];
}

- (void)updateConstraints
{
    [_buttons enumerateObjectsUsingBlock:^(UITabBarItem *item, NSUInteger i, BOOL *stop) {
        UIButton *button = _buttons[i];
        [_buttonConstraints addObjectsFromArray:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[button]|"
                                                 options:0
                                                 metrics:nil
                                                   views:@{ @"button": button }]];
        if (i == 0) {
            [_buttonConstraints addObjectsFromArray:
             [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-insetTop-[button(==44)]"
                                                     options:0
                                                     metrics:@{ @"insetTop": @(self.insets.top) }
                                                       views:@{ @"button": button }]];
        } else {
            [_buttonConstraints addObjectsFromArray:
             [NSLayoutConstraint constraintsWithVisualFormat:@"V:[top]-8-[bottom(==top)]"
                                                     options:0
                                                     metrics:nil
                                                       views:@{ @"top": _buttons[i - 1],
                                                                @"bottom": button }]];
        }
    }];
    [self addConstraints:_buttonConstraints];
    [super updateConstraints];
}

@end
