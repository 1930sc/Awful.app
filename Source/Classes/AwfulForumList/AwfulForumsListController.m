//
//  AwfulForumsListController.m
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForumsListController.h"
#import "AwfulFetchedTableViewControllerSubclass.h"
#import "AwfulThreadListController.h"
#import "AwfulAppDelegate.h"
#import "AwfulBookmarksController.h"
#import "AwfulForum+AwfulMethods.h"
#import "AwfulForumHeader.h"
#import "AwfulLoginController.h"
#import "AwfulSettings.h"
#import "AwfulCustomForums.h"
#import "AwfulForumCell.h"

@interface AwfulForumsListController () <AwfulForumCellDelegate>

@property (nonatomic, strong) IBOutlet AwfulForumHeader *headerView;

@end

@implementation AwfulForumsListController

- (NSFetchedResultsController *)createFetchedResultsController
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:[AwfulForum entityName]];
    request.predicate = [NSPredicate predicateWithFormat:@"parentForum == nil or parentForum.expanded == YES"];
    request.sortDescriptors = @[
        [NSSortDescriptor sortDescriptorWithKey:@"category.index" ascending:YES],
        [NSSortDescriptor sortDescriptorWithKey:@"index" ascending:YES]
    ];
    return [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                               managedObjectContext:ApplicationDelegate.managedObjectContext
                                                 sectionNameKeyPath:@"category.index"
                                                          cacheName:nil];
}

#pragma mark - View lifecycle

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    UITableViewCell* cell = (UITableViewCell*)sender;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    
    AwfulThreadListController *list = (AwfulThreadListController *)segue.destinationViewController;
    list.forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self.navigationController setToolbarHidden:YES];
    
    self.tableView.separatorColor = [UIColor colorWithRed:0.75 green:0.75 blue:0.75 alpha:1.0];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.navigationController setToolbarHidden:YES];
    
    [self.navigationItem.leftBarButtonItem setTintColor:[UIColor colorWithRed:46.0/255 green:146.0/255 blue:190.0/255 alpha:1.0]];
    
    if (IsLoggedIn() && [self.fetchedResultsController.sections count] == 0) {
       [self refresh];
    }
    
    //reset this since it may get changed by custom forums
    [self.navigationController.navigationBar setBackgroundImage:[ApplicationDelegate navigationBarBackgroundImageForMetrics:UIBarMetricsDefault]
                                                  forBarMetrics:(UIBarMetricsDefault)];
}

- (void)refresh
{
    [super refresh];
    [self.networkOperation cancel];
    self.networkOperation = [[AwfulHTTPClient sharedClient] forumsListOnCompletion:^(NSArray *listOfForums)
    {
        [self finishedRefreshing];
        [self.fetchedResultsController performFetch:NULL];
        [self.tableView reloadData];
    } onError:^(NSError *error)
    {
        [self finishedRefreshing];
        [ApplicationDelegate requestFailed:error];
    }];
}

- (void)stop
{
    [self.networkOperation cancel];
    [self finishedRefreshing];
}

#pragma mark - Table view data source

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    [[NSBundle mainBundle] loadNibNamed:@"AwfulForumHeaderView" owner:self options:nil];
    AwfulForumHeader *header = self.headerView;
    self.headerView = nil;
    
    AwfulForum *anyForum = [[self.fetchedResultsController.sections[section] objects] lastObject];
    header.titleLabel.text = anyForum.category.name;
    if ([[AwfulSettings settings] darkTheme]) {
        header.backgroundColor = [UIColor blackColor];
    } else {
        header.backgroundColor = [UIColor colorWithRed:0 green:0.4 blue:0.6 alpha:1];
    }
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 26;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const Identifier = @"ForumCell";
    AwfulForumCell *cell = [tableView dequeueReusableCellWithIdentifier:Identifier];
    if (!cell) {
        cell = [AwfulForumCell new];
    }
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell *)plainCell atIndexPath:(NSIndexPath*)indexPath
{
    AwfulForumCell *cell = (AwfulForumCell *)plainCell;
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.delegate = self;
    cell.textLabel.text = forum.name;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:FontSizeForForum(forum)];
    cell.favorite = forum.isFavoriteValue;
    cell.showsFavorite = YES;
    cell.expanded = forum.expandedValue;
    if ([forum.children count]) {
        cell.showsExpanded = AwfulForumCellShowsExpandedButton;
    } else {
        cell.showsExpanded = AwfulForumCellShowsExpandedLeavesRoom;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    return [AwfulForumCell heightForCellWithText:forum.name
                                        fontSize:FontSizeForForum(forum)
                                   showsFavorite:YES
                                   showsExpanded:AwfulForumCellShowsExpandedLeavesRoom
                                      tableWidth:tableView.bounds.size.width];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([[AwfulSettings settings] darkTheme]) {
        cell.backgroundColor = [UIColor darkGrayColor];
        cell.textLabel.textColor = [UIColor whiteColor];
    } else {
        cell.backgroundColor = [UIColor whiteColor];
        cell.textLabel.textColor = [UIColor blackColor];
    }
}

static inline CGFloat FontSizeForForum(AwfulForum *forum)
{
    return 20 - (forum.parentForum ? 5 : 0);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    AwfulThreadListController *threadList = [AwfulCustomForums threadListControllerForForum:forum];
    threadList.forum = forum;
    [self.navigationController pushViewController:threadList animated:YES];
}

#pragma mark - Parent forum cell delegate

- (void)forumCellDidToggleFavorite:(AwfulForumCell *)cell
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    forum.isFavoriteValue = cell.favorite;
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[AwfulForum entityName]];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"isFavorite == YES"];
    NSError *error;
    if (cell.favorite) {
        NSUInteger count = [ApplicationDelegate.managedObjectContext countForFetchRequest:fetchRequest
                                                                                    error:&error];
        if (count == NSNotFound) {
            NSLog(@"Error setting favorite index: %@", error);
        }
        forum.favoriteIndexValue = count;
    } else {
        NSArray *renumber = [ApplicationDelegate.managedObjectContext executeFetchRequest:fetchRequest
                                                                                    error:&error];
        if (!renumber) {
            NSLog(@"Error renumbering favorites: %@", error);
        }
        [renumber enumerateObjectsUsingBlock:^(AwfulForum *favorite, NSUInteger i, BOOL *stop) {
            favorite.favoriteIndexValue = i;
        }];
    }
    [ApplicationDelegate saveContext];
}

- (void)forumCellDidToggleExpanded:(AwfulForumCell *)cell
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    if (cell.expanded) {
        forum.expandedValue = YES;
    } else {
        RecursivelyCollapseForum(forum);
    }
    [ApplicationDelegate saveContext];
    
    // The fetched results controller won't pick up on changes to the keypath "parentForum.expanded"
    // for forums that should be newly visible (dunno why) so we need to help it along.
    for (AwfulForum *child in forum.children) {
        [child willChangeValueForKey:AwfulForumRelationships.parentForum];
        [child didChangeValueForKey:AwfulForumRelationships.parentForum];
    }
}

static void RecursivelyCollapseForum(AwfulForum *forum)
{
    forum.expandedValue = NO;
    for (AwfulForum *child in forum.children) {
        RecursivelyCollapseForum(child);
    }
}

@end

