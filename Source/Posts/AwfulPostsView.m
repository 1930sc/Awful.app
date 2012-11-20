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
{
    dispatch_once_t _onceOnFirstLoad;
}

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    UIWebView *webView = [[UIWebView alloc] initWithFrame:(CGRect){ .size = frame.size }];
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    webView.delegate = self;
    webView.dataDetectorTypes = UIDataDetectorTypeNone;
    webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    RemoveShadowFromAboveAndBelowWebView(webView);
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

static void RemoveShadowFromAboveAndBelowWebView(UIWebView *webView)
{
    for (UIView *view in [webView.scrollView subviews]) {
        if ([view isKindOfClass:[UIImageView class]]) {
            view.hidden = YES;
        }
    }
}

- (void)reloadData
{
    NSMutableArray *posts = [NSMutableArray new];
    NSInteger numberOfPosts = [self.delegate numberOfPostsInPostsView:self];
    for (NSInteger i = 0; i < numberOfPosts; i++) {
        [posts addObject:[self.delegate postsView:self postAtIndex:i]];
    }
    [self sendPostsJSONAndTellDelegate:JSONize(posts)];
    [self reloadAdvertisementHTML];
}

- (void)reloadAdvertisementHTML
{
    NSString *ad = @"";
    if ([self.delegate respondsToSelector:@selector(advertisementHTMLForPostsView:)]) {
        NSString *ad = [self.delegate advertisementHTMLForPostsView:self];
        if ([ad length] == 0) ad = @"";
    }
    // Foundation's JSON serializer only does arrays and objects at the top level.
    [self evalJavaScript:@"Awful.ad(%@[0])", JSONize(@[ ad ])];
}

- (void)insertPostAtIndex:(NSInteger)index
{
    NSDictionary *post = [self.delegate postsView:self postAtIndex:index];
    [self evalJavaScript:@"Awful.insertPost(%@, %d)", JSONize(post), index];
}

- (void)deletePostAtIndex:(NSInteger)index
{
    [self evalJavaScript:@"Awful.deletePost(%d)", index];
}

- (void)reloadPostAtIndex:(NSInteger)index
{
    NSDictionary *post = [self.delegate postsView:self postAtIndex:index];
    [self evalJavaScript:@"Awful.post(%d, %@)", index, JSONize(post)];
}

static NSString * JSONize(id obj)
{
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:obj options:0 error:&error];
    if (!data) {
        NSLog(@"error serializing %@: %@", obj, error);
        return nil;
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (void)showHiddenSeenPosts
{
    UIScrollView *scrollView = self.scrollView;
    BOOL justScrollToBottom = scrollView.contentSize.height <= scrollView.frame.size.height;
    
    float diff = [[self evalJavaScript:@"Awful.showAllPosts()"] floatValue];
    
    if (justScrollToBottom) {
        [scrollView scrollRectToVisible:CGRectMake(0, scrollView.contentSize.height - 1, 1, 1)
                               animated:NO];
    } else {
        CGPoint offset = scrollView.contentOffset;
        offset.y += diff;
        scrollView.contentOffset = offset;
    }
    
    if (diff > 0) {
        if ([self.delegate respondsToSelector:@selector(postsView:numberOfHiddenSeenPosts:)]) {
            [self.delegate postsView:self numberOfHiddenSeenPosts:0];
        }
    }
}

- (void)clearAllPosts
{
    [self sendPostsJSONAndTellDelegate:nil];
}

- (void)sendPostsJSONAndTellDelegate:(NSString *)postsJSON
{
    if (!postsJSON) postsJSON = @"[]";
    NSInteger hiddenSeenPosts = [[self evalJavaScript:@"Awful.posts(%@)", postsJSON] integerValue];
    if ([self.delegate respondsToSelector:@selector(postsView:numberOfHiddenSeenPosts:)]) {
        [self.delegate postsView:self numberOfHiddenSeenPosts:hiddenSeenPosts];
    }
}

- (NSString *)evalJavaScript:(NSString *)script, ...
{
    va_list args;
    va_start(args, script);
    NSString *js = [[NSString alloc] initWithFormat:script arguments:args];
    va_end(args);
    return [self.webView stringByEvaluatingJavaScriptFromString:js];
}

- (void)setStylesheetURL:(NSURL *)stylesheetURL
{
    if (_stylesheetURL == stylesheetURL) return;
    _stylesheetURL = stylesheetURL;
    [self updateStylesheetURL];
}

- (void)updateStylesheetURL
{
    NSString *url = [self.stylesheetURL absoluteString];
    [self evalJavaScript:@"Awful.stylesheetURL('%@')", url ? url : @""];
}

- (void)setDark:(BOOL)dark
{
    if (_dark == dark) return;
    _dark = dark;
    [self updateDark];
}

- (void)updateDark
{
    [self evalJavaScript:@"Awful.dark(%@)", self.dark ? @"true" : @"false"];
}

- (UIScrollView *)scrollView
{
    return self.webView.scrollView;
}

- (void)setLoadingMessage:(NSString *)loadingMessage
{
    if (_loadingMessage == loadingMessage) return;
    _loadingMessage = [loadingMessage copy];
    [self updateLoadingMessage];
}

- (void)updateLoadingMessage
{
    NSString *json = JSONize(@[ self.loadingMessage ? self.loadingMessage : [NSNull null] ]);
    [self evalJavaScript:@"Awful.loading(%@[0])", json];
    if (self.loadingMessage) {
        self.scrollView.contentOffset = CGPointZero;
        self.scrollView.scrollEnabled = NO;
    } else {
        self.scrollView.scrollEnabled = YES;
    }
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    dispatch_once(&_onceOnFirstLoad, ^{
        [self updateStylesheetURL];
        [self updateDark];
        [self updateLoadingMessage];
        [self reloadData];
    });
}

- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
    navigationType:(UIWebViewNavigationType)navigationType
{
    if ([[[request URL] scheme] isEqualToString:@"x-objc"]) {
        [self bridgeJavaScriptToObjectiveCWithURL:[request URL]];
        return NO;
    } else if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        if ([self.delegate respondsToSelector:@selector(postsView:didTapLinkToURL:)]) {
            [self.delegate postsView:self didTapLinkToURL:[request URL]];
        }
        return NO;
    }
    return YES;
}

- (void)bridgeJavaScriptToObjectiveCWithURL:(NSURL *)url
{
    if (![self.delegate respondsToSelector:@selector(methodSignatureForSelector:)]) return;
    NSArray *components = [url pathComponents];
    if ([components count] < 2) return;
    
    SEL selector = NSSelectorFromString(components[1]);
    if (![self.delegate respondsToSelector:selector]) return;
    
    NSArray *arguments;
    if ([components count] >= 3) {
        NSArray *args = [components subarrayWithRange:NSMakeRange(2, [components count] - 2)];
        NSString *stringData = [args componentsJoinedByString:@"/"];
        NSData *data = [stringData dataUsingEncoding:NSUTF8StringEncoding];
        NSError *error;
        arguments = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (!arguments) {
            NSLog(@"error deserializing arguments from JavaScript for method %@: %@",
                  NSStringFromSelector(selector), error);
        }
    }
    NSUInteger expectedArguments = [[components[1] componentsSeparatedByString:@":"] count] - 1;
    if ([arguments count] != expectedArguments) {
        NSLog(@"expecting %u arguments for %@, got %u instead",
              expectedArguments, NSStringFromSelector(selector), [arguments count]);
        return;
    }
    
    NSMethodSignature *signature = [self.delegate methodSignatureForSelector:selector];
    if (!signature) return;
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setSelector:selector];
    for (NSUInteger i = 0; i < [arguments count]; i++) {
        id arg = arguments[i];
        [invocation setArgument:&arg atIndex:i + 2];
    }
    [invocation invokeWithTarget:self.delegate];
}

@end
