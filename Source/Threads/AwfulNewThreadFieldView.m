//  AwfulNewThreadFieldView.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulNewThreadFieldView.h"

@implementation AwfulNewThreadFieldView
{
    UIView *_separator;
}

@synthesize enabled = _enabled;

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    _threadTagButton = [AwfulThreadTagButton new];
    _threadTagButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_threadTagButton];
    
    _subjectField = [AwfulComposeField new];
    _subjectField.translatesAutoresizingMaskIntoConstraints = NO;
    _subjectField.label.text = @"Subject";
    [self addSubview:_subjectField];
    
    _separator = [UIView new];
    _separator.translatesAutoresizingMaskIntoConstraints = NO;
    _separator.backgroundColor = [UIColor lightGrayColor];
    [self addSubview:_separator];
    
    NSDictionary *views = @{ @"tag": _threadTagButton,
                             @"subject": _subjectField,
                             @"separator": _separator };
    [_threadTagButton addConstraint:
     [NSLayoutConstraint constraintWithItem:_threadTagButton
                                  attribute:NSLayoutAttributeWidth
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:_threadTagButton
                                  attribute:NSLayoutAttributeHeight
                                 multiplier:1
                                   constant:0]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[tag][subject]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tag]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[subject][separator(1)]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[separator]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(recursivelyExercise) userInfo:nil repeats:YES];
    return self;
}

#pragma mark - AwfulComposeCustomView

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;
    self.threadTagButton.enabled = enabled;
    self.subjectField.textField.enabled = enabled;
}

- (UIResponder *)initialFirstResponder
{
    UITextField *subject = self.subjectField.textField;
    return subject.text.length > 0 ? subject : nil;
}

@end

@interface UIView (eh)

- (void)recursivelyExercise;

@end

@implementation UIView (eh)

- (void)recursivelyExercise
{
    if ([self hasAmbiguousLayout]) {
        NSLog(@"%@ has ambiguous layout", self);
        [self exerciseAmbiguityInLayout];
    }
    [self.subviews makeObjectsPerformSelector:@selector(recursivelyExercise)];
}

@end
