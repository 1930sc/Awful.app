//
//  AwfulPageBottomBar.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulPageBarBackgroundView.h"

@interface AwfulPageBottomBar : AwfulPageBarBackgroundView

@property (readonly, weak, nonatomic) UISegmentedControl *backForwardControl;
@property (readonly, weak, nonatomic) UIButton *jumpToPageButton;
@property (readonly, weak, nonatomic) UISegmentedControl *actionsFontSizeControl;

@end
