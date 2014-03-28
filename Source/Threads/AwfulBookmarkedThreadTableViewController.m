//  AwfulBookmarkedThreadTableViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulBookmarkedThreadTableViewController.h"
#import "AwfulAlertView.h"
#import "AwfulForumsClient.h"
#import "AwfulModels.h"
#import "AwfulSettings.h"
#import "AwfulThreadCell.h"
#import <SVPullToRefresh/SVPullToRefresh.h>

@interface AwfulBookmarkedThreadTableViewController ()

@property (assign, nonatomic) NSUInteger mostRecentlyLoadedPage;

@end

@implementation AwfulBookmarkedThreadTableViewController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    if (!(self = [super initWithNibName:Nil bundle:nil])) return nil;
    _managedObjectContext = managedObjectContext;
    self.title = @"Bookmarks";
    self.tabBarItem.image = [UIImage imageNamed:@"bookmarks"];
    self.navigationItem.backBarButtonItem = [UIBarButtonItem emptyBackBarButtonItem];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self configureFetchedResultsController];

    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    __weak __typeof__(self) weakSelf = self;
    [self.tableView addInfiniteScrollingWithActionHandler:^{
        __typeof__(self) self = weakSelf;
        [self loadPage:self.mostRecentlyLoadedPage + 1];
    }];
    self.tableView.showsInfiniteScrolling = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(settingsDidChange:)
                                                 name:AwfulSettingsDidChangeNotification
                                               object:nil];
}

- (void)configureFetchedResultsController
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:[AwfulThread entityName]];
    request.predicate = [NSPredicate predicateWithFormat:@"bookmarked = YES"];
    NSMutableArray *sortDescriptors = [NSMutableArray new];
    if ([AwfulSettings settings].bookmarksSortedByUnread) {
        [sortDescriptors addObject:[NSSortDescriptor sortDescriptorWithKey:@"anyUnreadPosts" ascending:NO]];
	}
    [sortDescriptors addObject:[NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:NO]];
    request.sortDescriptors = sortDescriptors;
    self.threadDataSource.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                                         managedObjectContext:self.managedObjectContext
                                                                                           sectionNameKeyPath:nil
                                                                                                    cacheName:nil];
}

- (void)settingsDidChange:(NSNotification *)note
{
    if ([note.userInfo[AwfulSettingsDidChangeSettingKey] isEqual:AwfulSettingsKeys.bookmarksSortedByUnread]) {
        [self configureFetchedResultsController];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if ([self shouldRefreshOnAppear]) {
        [self refresh];
    }
}

- (BOOL)shouldRefreshOnAppear
{
    if (![AwfulForumsClient client].reachable) return NO;
    if ([self.tableView numberOfRowsInSection:0] == 0) return YES;
    if (!self.lastRefreshDate) return YES;
    return [[NSDate date] timeIntervalSinceDate:self.lastRefreshDate] > 60 * 10;
}

- (NSDate *)lastRefreshDate
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:kLastBookmarksRefreshDate];
}

- (void)setLastRefreshDate:(NSDate *)date
{
    [[NSUserDefaults standardUserDefaults] setObject:date forKey:kLastBookmarksRefreshDate];
}

static NSString * const kLastBookmarksRefreshDate = @"com.awfulapp.Awful.LastBookmarksRefreshDate";

- (void)refresh
{
    [self.refreshControl beginRefreshing];
    [self loadPage:1];
}

- (void)loadPage:(NSInteger)page
{
    __weak __typeof__(self) weakSelf = self;
    [[AwfulForumsClient client] listBookmarkedThreadsOnPage:page andThen:^(NSError *error, NSArray *threads) {
        __typeof__(self) self = weakSelf;
        if (error) {
            [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
        } else {
            [self setLastRefreshDate:[NSDate date]];
            self.mostRecentlyLoadedPage = page;
        }
        [self.refreshControl endRefreshing];
        [self.tableView.infiniteScrollingView stopAnimating];
        self.tableView.showsInfiniteScrolling = threads.count >= 40;
    }];
}

@end
