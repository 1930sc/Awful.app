//
//  AwfulPostsView.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-29.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostsView.h"

@interface AwfulPostsView () <UIWebViewDelegate>

@property (weak, nonatomic) UIWebView *webView;

@end


@implementation AwfulPostsView

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    UIWebView *webView = [[UIWebView alloc] initWithFrame:(CGRect){ .size = frame.size }];
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    webView.delegate = self;
    webView.dataDetectorTypes = UIDataDetectorTypeNone;
    NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
    NSURL *postsViewURL = [thisBundle URLForResource:@"posts-view" withExtension:@"html"];
    NSError *error;
    NSString *html = [NSString stringWithContentsOfURL:postsViewURL
                                              encoding:NSUTF8StringEncoding
                                                 error:&error];
    if (!html) {
        NSLog(@"error loading html for %@: %@", [self class], error);
        return nil;
    }
    [webView loadHTMLString:html baseURL:[thisBundle resourceURL]];
    [self addSubview:webView];
    _webView = webView;
    return self;
}

- (void)reloadData
{
    NSMutableArray *posts = [NSMutableArray new];
    NSInteger numberOfPosts = [self.delegate numberOfPostsInPostsView:self];
    for (NSInteger i = 0; i < numberOfPosts; i++) {
        [posts addObject:[self.delegate postsView:self postAtIndex:i]];
    }
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:posts options:0 error:&error];
    if (!data) {
        NSLog(@"error serializing posts: %@", error);
    }
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *js = [NSString stringWithFormat:@"Awful.posts(%@)", json];
    [self.webView stringByEvaluatingJavaScriptFromString:js];
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self reloadData];
}

@end
