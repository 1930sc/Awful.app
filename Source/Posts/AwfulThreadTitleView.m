//
//  AwfulThreadTitleView.m
//  Awful
//
//  Created by me on 6/25/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadTitleView.h"
#import "AwfulPage.h"

@implementation AwfulThreadTitleView

+ (id)threadTitleViewWithPage:(AwfulPage *)page
{
    AwfulThreadTitleView *view = [[AwfulThreadTitleView alloc] initWithFrame:CGRectMake(0, 0, page.view.frame.size.width - 100, 50)];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    view.backgroundColor = [UIColor greenColor];
    view.title.text = page.thread.title;
    view.threadTag.image = [UIImage imageNamed:[page.thread.threadIconImageURL lastPathComponent]];
    
    [view addSubview:view.title];
    [view addSubview:view.threadTag];
    
    return view;
}

- (void)layoutSubviews
{
    if (self.threadTag.image)
        self.threadTag.frame = CGRectMake(0, 0, 45, 45);
    self.title.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;
    self.title.frame = CGRectMake(50, 0, self.frame.size.width - 50, 25);
    self.title.textAlignment = UITextAlignmentCenter;
}

- (UILabel *)title
{
    if (!_title)
        _title = [UILabel new];
    return _title;
}

- (UIImageView *)threadTag
{
    if (!_threadTag)
        _threadTag = [UIImageView new];
    return _threadTag;
}

@end
