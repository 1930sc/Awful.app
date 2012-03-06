//
//  BookmarksController.m
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulBookmarksController.h"
#import "AwfulUtil.h"
#import "AwfulConfig.h"
#import "AwfulNavigator.h"
#import "AwfulPageCount.h"
#import "AwfulThread.h"
#import "AwfulPage.h"
#import "AwfulNetworkEngine.h"
#import "AwfulTableViewController.h"

@implementation AwfulBookmarksController

-(void)awakeFromNib
{
    [super awakeFromNib];
    /*NSMutableArray *old_bookmarks = [AwfulUtil newThreadListForForumId:[self getSaveID]];
    self.awfulThreads = old_bookmarks;
    
    // crash fix from one version to another
    if(![[NSUserDefaults standardUserDefaults] boolForKey:@"killbookmarks"]) {
        self.awfulThreads = [NSMutableArray array];
        [AwfulUtil saveThreadList:self.awfulThreads forForumId:[self getSaveID]];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"killbookmarks"];
    }*/
    
    self.tableView.delegate = self;
    self.title = @"Bookmarks";
}

#pragma mark -
#pragma mark View lifecycle

-(void)viewDidLoad {
    [super viewDidLoad];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:YES];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

-(BOOL)shouldReloadOnViewLoad
{
    return NO;
}

-(void)newlyVisible
{
    //[self endTimer];
    //self.refreshed = NO;
    //[self startTimer];
}

-(void)loadPageNum : (NSUInteger)pageNum
{   
    [self.networkOperation cancel];
    self.networkOperation = [ApplicationDelegate.awfulNetworkEngine threadListForBookmarksAtPageNum:1 onCompletion:^(NSMutableArray *threads) {
        
        [self acceptThreads:threads];
        
    } onError:^(NSError *error) {
        [self swapToRefreshButton];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
    }];
}

-(void)prevPage
{
    if(self.pages.currentPage > 1) {
        [self.awfulThreads removeAllObjects];
        [self.tableView reloadData];
        self.pages.currentPage--;
        [self refresh];
    }
}

-(void)nextPage
{
    [self.awfulThreads removeAllObjects];
    [self.tableView reloadData];
    self.pages.currentPage++;
    [self refresh];
}

/*
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self endTimer];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self startTimer];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if(!decelerate) {
        [self startTimer];
    }
}*/

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    if(indexPath.row == [self.awfulThreads count]) {
        return NO;
    }
    return YES;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    int total = [self.awfulThreads count];
    
    // bottom page-nav cell
    if(self.pages.currentPage > 1 || ([self.awfulThreads count] > 0)) {
        total++;
    }
    
    return total;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        //AwfulThread *thread = [self.awfulThreads objectAtIndex:indexPath.row];
        [self.awfulThreads removeObjectAtIndex:indexPath.row];
        //[AwfulUtil saveThreadList:self.awfulThreads forForumId:[self getSaveID]];       
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
        

        /*ASIFormDataRequest *req = [ASIFormDataRequest requestWithURL:[NSURL URLWithString:@"http://forums.somethingawful.com/bookmarkthreads.php"]];
        req.userInfo = [NSDictionary dictionaryWithObject:@"Removed from bookmarks." forKey:@"completionMsg"];
        
        [req setPostValue:@"1" forKey:@"json"];
        [req setPostValue:@"remove" forKey:@"action"];
        [req setPostValue:thread.threadID forKey:@"threadid"];
        
        loadRequestAndWait(req);*/
        

    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}

-(AwfulThreadCellType)getTypeAtIndexPath : (NSIndexPath *)indexPath
{
    if(indexPath.row < [self.awfulThreads count]) {
        return AwfulThreadCellTypeThread;
    } else if(indexPath.row == [self.awfulThreads count]) {
        return AwfulThreadCellTypePageNav;
    }
    return AwfulThreadCellTypeUnknown;
}

@end

@implementation AwfulBookmarksControllerIpad
- (id) init
{
    self = [super init];
    if (self)
    {
        
        self.tabBarItem = [[self tabBarItem] initWithTabBarSystemItem:UITabBarSystemItemBookmarks tag:self.tabBarItem.tag];
    }
    return self;

}
//Copied from AwfulThreadListIpad
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    AwfulThreadCellType type = [self getTypeAtIndexPath:indexPath];
    
    if(type == AwfulThreadCellTypeThread) {
        
        AwfulThread *thread = [self getThreadAtIndexPath:indexPath];
        
        if(thread.threadID != nil) {
            AwfulPageDestinationType start = AwfulPageDestinationTypeNewpost;
            if(thread.totalUnreadPosts == -1) {
                start = AwfulPageDestinationTypeFirst;
            } else if(thread.totalUnreadPosts == 0) {
                start = AwfulPageDestinationTypeLast;
                // if the last page is full, it won't work if you go for &goto=newpost
                // therefore I'm setting it to last page here
            }
            
            AwfulPageIpad *thread_detail = [[AwfulPageIpad alloc] initWithAwfulThread:thread startAt:start];
            loadContentVC(thread_detail);
        }
    }
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

-(void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.titleView = nil;
    self.title = @"Bookmarks";
    [self swapToRefreshButton];
}

-(void)swapToRefreshButton
{
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh)];
    self.navigationItem.rightBarButtonItem = refresh;
}

-(void)swapToStopButton
{
    UIBarButtonItem *stop = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(stop)];
    self.navigationItem.rightBarButtonItem = stop;
}

@end

