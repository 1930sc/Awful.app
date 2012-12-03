//
//  AwfulFavoritesViewController.m
//  Awful
//
//  Created by Nolan Waite on 12-04-21.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulFavoritesViewController.h"
#import "AwfulFetchedTableViewControllerSubclass.h"
#import "AwfulDataStack.h"
#import "AwfulForumsListController.h"
#import "AwfulModels.h"
#import "AwfulThreadListController.h"
#import "AwfulForumCell.h"
#import "AwfulTheme.h"

@interface CoverView : UIView

@property (readonly, weak, nonatomic) UILabel *noFavoritesLabel;

@property (readonly, weak, nonatomic) UILabel *tapAStarLabel;

@end


@interface AwfulFavoritesViewController ()

@property (readonly, strong, nonatomic) UIBarButtonItem *addButtonItem;

@property (assign, nonatomic) BOOL automaticallyAdded;

@property (weak, nonatomic) CoverView *coverView;

@end


@implementation AwfulFavoritesViewController

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.title = @"Favorites";
        self.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemFavorites
                                                                     tag:0];
    }
    return self;
}

- (void)showNoFavoritesCoverAnimated:(BOOL)animated
{
    self.tableView.scrollEnabled = NO;
    UIView *cover = self.coverView;
    [UIView transitionWithView:self.view
                      duration:animated ? 0.6 : 0
                       options:UIViewAnimationOptionTransitionCurlDown
                    animations:^{ [self.view addSubview:cover]; }
                    completion:nil];
}

- (void)hideNoFavoritesCover
{
    [self.coverView removeFromSuperview];
    self.tableView.scrollEnabled = YES;
}

- (CoverView *)coverView
{
    if (_coverView) return _coverView;
    CoverView *coverView = [[CoverView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:coverView];
    _coverView = coverView;
    return coverView;
}

- (void)updateCoverAndEditButtonAnimated:(BOOL)animated
{
    if ([self.fetchedResultsController.fetchedObjects count] > 0) {
        self.navigationItem.rightBarButtonItem = self.editButtonItem;
        [self hideNoFavoritesCover];
    } else {
        self.navigationItem.rightBarButtonItem = nil;
        [self showNoFavoritesCoverAnimated:animated];
    }
}

#pragma mark - AwfulFetchedTableViewController

- (NSFetchedResultsController *)createFetchedResultsController
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:[AwfulForum entityName]];
    request.predicate = [NSPredicate predicateWithFormat:@"isFavorite = YES"];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"favoriteIndex"
                                                              ascending:YES]];
    return [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                               managedObjectContext:[AwfulDataStack sharedDataStack].context
                                                 sectionNameKeyPath:nil
                                                          cacheName:nil];
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    // Hide the cell separators after the last cell.
    self.tableView.tableFooterView = [UIView new];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateCoverAndEditButtonAnimated:NO];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    if (!editing) {
        [[AwfulDataStack sharedDataStack] save];
        [self updateCoverAndEditButtonAnimated:YES];
    }
}

#pragma mark - AwfulTableViewController

- (BOOL)canPullToRefresh
{
    return NO;
}

- (void)retheme
{
    [super retheme];
    self.tableView.separatorColor = [AwfulTheme currentTheme].favoritesSeparatorColor;
    self.view.backgroundColor = [AwfulTheme currentTheme].favoritesBackgroundColor;
    self.coverView.noFavoritesLabel.textColor = [AwfulTheme currentTheme].noFavoritesTextColor;
    self.coverView.tapAStarLabel.textColor = [AwfulTheme currentTheme].noFavoritesTextColor;
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)object
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    [super controller:controller
      didChangeObject:object
          atIndexPath:indexPath
        forChangeType:type
         newIndexPath:newIndexPath];
    if ([controller.fetchedObjects count] == 0) {
        [self showNoFavoritesCoverAnimated:YES];
    }
}

#pragma mark - UITableViewDataSource and UITableViewDelegate

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const Identifier = @"ForumCell";
    AwfulForumCell *cell = [tableView dequeueReusableCellWithIdentifier:Identifier];
    if (!cell) {
        cell = [[AwfulForumCell alloc] initWithReuseIdentifier:Identifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = forum.name;
    cell.textLabel.textColor = [AwfulTheme currentTheme].forumCellTextColor;
    cell.selectionStyle = [AwfulTheme currentTheme].cellSelectionStyle;
}

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = [AwfulTheme currentTheme].forumCellBackgroundColor;
}

- (void)tableView:(UITableView *)tableView
    moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
    toIndexPath:(NSIndexPath *)destinationIndexPath
{
    self.userDrivenChange = YES;
    NSMutableArray *reorder = [self.fetchedResultsController.fetchedObjects mutableCopy];
    AwfulForum *move = [reorder objectAtIndex:sourceIndexPath.row];
    [reorder removeObjectAtIndex:sourceIndexPath.row];
    [reorder insertObject:move atIndex:destinationIndexPath.row];
    [reorder enumerateObjectsUsingBlock:^(AwfulForum *forum, NSUInteger i, BOOL *stop) {
        forum.favoriteIndexValue = i;
    }];
    [[AwfulDataStack sharedDataStack] save];
    self.userDrivenChange = NO;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
    forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
        forum.isFavoriteValue = NO;
        NSArray *reindex = [self.fetchedResultsController fetchedObjects];
        [reindex enumerateObjectsUsingBlock:^(AwfulForum *f, NSUInteger i, BOOL *stop) {
            if (f.isFavoriteValue) f.favoriteIndexValue = i;
        }];
        if (self.editing && [self.fetchedResultsController.fetchedObjects count] == 0) {
            [self setEditing:NO animated:YES];
        } else {
            [[AwfulDataStack sharedDataStack] save];
            [self updateCoverAndEditButtonAnimated:YES];
        }
    }
}

- (NSString *)tableView:(UITableView *)tableView
    titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return @"Remove";
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    AwfulThreadListController *threadList = [AwfulThreadListController new];
    threadList.forum = forum;
    [self.navigationController pushViewController:threadList animated:YES];
}

@end


@interface CoverView ()

@property (weak, nonatomic) UILabel *noFavoritesLabel;

@property (weak, nonatomic) UILabel *tapAStarLabel;

@end


@implementation CoverView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        UILabel *noFavoritesLabel = [UILabel new];
        noFavoritesLabel.text = @"No Favorites";
        noFavoritesLabel.font = [UIFont systemFontOfSize:35];
        noFavoritesLabel.textColor = [UIColor grayColor];
        noFavoritesLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:noFavoritesLabel];
        _noFavoritesLabel = noFavoritesLabel;
        
        UILabel *tapAStarLabel = [UILabel new];
        tapAStarLabel.text = @"Tap a star in the forums list to add one.";
        tapAStarLabel.font = [UIFont systemFontOfSize:16];
        tapAStarLabel.textColor = [UIColor grayColor];
        tapAStarLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:tapAStarLabel];
        _tapAStarLabel = tapAStarLabel;
    }
    return self;
}

- (void)layoutSubviews
{
    [self.noFavoritesLabel sizeToFit];
    self.noFavoritesLabel.center = CGPointMake(CGRectGetMidX(self.bounds),
                                               CGRectGetMidY(self.bounds));
    self.noFavoritesLabel.frame = CGRectIntegral(self.noFavoritesLabel.frame);
    
    self.tapAStarLabel.bounds = (CGRect){ .size.width = self.noFavoritesLabel.bounds.size.width };
    [self.tapAStarLabel sizeToFit];
    self.tapAStarLabel.center = CGPointMake(self.noFavoritesLabel.center.x,
                                            self.noFavoritesLabel.center.y +
                                            self.noFavoritesLabel.bounds.size.height / 1.5);
    self.tapAStarLabel.frame = CGRectIntegral(self.tapAStarLabel.frame);
}

@end
