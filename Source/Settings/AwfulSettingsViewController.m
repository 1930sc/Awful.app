//
//  AwfulSettingsViewController.m
//  Awful
//
//  Created by Sean Berry on 3/1/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulSettingsViewController.h"
#import "AwfulSettings.h"
#import "AwfulLicensesViewController.h"
#import "AwfulLoginController.h"
#import "AwfulSettingsChoiceViewController.h"
#import "AwfulUser.h"
#import "AwfulAppDelegate.h"

@interface AwfulSettingsViewController () <UIAlertViewDelegate>

@property (strong, nonatomic) NSArray *sections;

@property (strong, nonatomic) AwfulUser *user;

@property (strong, nonatomic) NSMutableArray *switches;

@end


@implementation AwfulSettingsViewController

- (id)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.title = @"Settings";
        self.tabBarItem.image = [UIImage imageNamed:@"cog.png"];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.switches = [NSMutableArray new];
    self.sections = AwfulSettings.settings.sections;
    self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = [UIColor colorWithHue:0.604 saturation:0.035 brightness:0.898 alpha:1];
    
    // Make sure the bottom section's footer is visible.
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 18, 0);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.user = AwfulSettings.settings.currentUser;
    if ([self.user.username length] == 0) {
        [self refresh];
    }
}

- (BOOL)canPullToRefresh
{
    return NO;
}

- (void)refresh
{
    [super refresh];
    [self.networkOperation cancel];
    self.networkOperation = [[AwfulHTTPClient sharedClient] userInfoRequestOnCompletion:^(AwfulUser *user)
    {
        self.user = user;
        [self.tableView reloadData];
        [self finishedRefreshing];
    } onError:^(NSError *error)
    {
        [self finishedRefreshing];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed"
                                                        message:[error localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }];
}

#pragma mark - Table view delegate and data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    return [self.sections count];
} 

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.sections[section][@"Settings"] count];
}

typedef enum SettingType
{
    ImmutableSetting,
    OnOffSetting,
    ChoiceSetting,
    ButtonSetting,
} SettingType;

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Grab the cell we need.
    
    NSDictionary *setting = [self settingForIndexPath:indexPath];
    SettingType settingType = ImmutableSetting;
    if ([setting[@"Type"] isEqual:@"Switch"]) {
        settingType = OnOffSetting;
    } else if (setting[@"Choices"]) {
        settingType = ChoiceSetting;
    } else if (setting[@"Action"]) {
        settingType = ButtonSetting;
    }
    NSString *identifier = @"Value1";
    UITableViewCellStyle style = UITableViewCellStyleValue1;
    if (settingType == OnOffSetting || settingType == ButtonSetting) {
        identifier = @"Default";
        style = UITableViewCellStyleDefault;
    }
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:style 
                                      reuseIdentifier:identifier];
    }
    if (style == UITableViewCellStyleValue1) {
        cell.detailTextLabel.textColor = [UIColor colorWithRed:0.224
                                                         green:0.329
                                                          blue:0.518
                                                         alpha:1];
    }
    
    // Set it up as we like it.
    
    cell.textLabel.text = setting[@"Title"];
    
    if (settingType == ImmutableSetting) {
        // This only works because there's one immutable setting here.
        cell.detailTextLabel.text = self.user.username;
    }
    
    NSString *key = setting[@"Key"];
    id valueForSetting = key ? [[NSUserDefaults standardUserDefaults] objectForKey:key] : nil;
    
    if (settingType == OnOffSetting) {
        NSUInteger tag = [self.switches indexOfObject:indexPath];
        if (tag == NSNotFound) {
            tag = self.switches.count;
            [self.switches addObject:indexPath];
        }
        UISwitch *switchView = [UISwitch new];
        switchView.on = [valueForSetting boolValue];
        [switchView addTarget:self
                       action:@selector(hitSwitch:)
             forControlEvents:UIControlEventValueChanged];
        switchView.tag = tag;
        cell.accessoryView = switchView;
    } else {
        cell.accessoryView = nil;
    }
    
    if (settingType == ChoiceSetting) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        for (NSDictionary *choice in setting[@"Choices"]) {
            if ([choice[@"Value"] isEqual:valueForSetting]) {
                cell.detailTextLabel.text = choice[@"Title"];
                break;
            }
        }
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    if (settingType == ChoiceSetting || settingType == ButtonSetting) {
         cell.selectionStyle = UITableViewCellSelectionStyleBlue;   
    } else {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    if (settingType == ButtonSetting) {
        cell.textLabel.textAlignment = UITextAlignmentCenter;
    } else {
        cell.textLabel.textAlignment = UITextAlignmentLeft;
    }
    
    return cell;
}

- (void)hitSwitch:(UISwitch *)switchView
{
    NSIndexPath *indexPath = self.switches[switchView.tag];
    NSDictionary *setting = [self settingForIndexPath:indexPath];
    NSString *key = [setting objectForKey:@"Key"];
    [[NSUserDefaults standardUserDefaults] setBool:switchView.on forKey:key];
}

- (NSIndexPath *)tableView:(UITableView *)tableView
  willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *setting = [self settingForIndexPath:indexPath];
    if (setting[@"Action"] || setting[@"Choices"]) {
        return indexPath;
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *setting = [self settingForIndexPath:indexPath];
    NSString *action = setting[@"Action"];
    if ([action isEqualToString:@"LogOut"]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Log Out"
                                                        message:@"Are you sure you want to log out?"
                                                       delegate:self
                                              cancelButtonTitle:@"Cancel"
                                              otherButtonTitles:@"Log Out", nil];
        alert.delegate = self;
        [alert show];
    } else if ([action isEqualToString:@"GoToAwfulThread"]) {
        NSString *threadID = setting[@"ThreadID"];
        NSArray *threads = [AwfulThread fetchAllMatchingPredicate:@"threadID = %@", threadID];
        AwfulThread *thread;
        if ([threads count] < 1) {
            thread = [AwfulThread insertNew];
            thread.threadID = threadID;
        } else {
            thread = threads[0];
        }
        AwfulPage *page = [AwfulPage newDeviceSpecificPage];
        page.destinationType = AwfulPageDestinationTypeNewpost;
        page.thread = thread;
        [page refresh];
        if (self.splitViewController) {
            AwfulSplitViewController *split = (AwfulSplitViewController *)self.splitViewController;
            UINavigationController *nav = split.viewControllers[1];
            [nav setViewControllers:@[ page ] animated:YES];
            [split ensureLeftBarButtonItemOnDetailView];
            [split.masterPopoverController dismissPopoverAnimated:YES];
        } else {
            [self.navigationController pushViewController:page animated:YES];
        }
    } else if ([action isEqualToString:@"ShowLicenses"]) {
        [self.navigationController pushViewController:[AwfulLicensesViewController new]
                                             animated:YES];
    } else {
        id selectedValue = [[NSUserDefaults standardUserDefaults] objectForKey:setting[@"Key"]];
        AwfulSettingsChoiceViewController *choiceViewController = [[AwfulSettingsChoiceViewController alloc] initWithSetting:setting selectedValue:selectedValue];
        choiceViewController.settingsViewController = self;
        [self.navigationController pushViewController:choiceViewController animated:YES];
    }
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (NSDictionary *)settingForIndexPath:(NSIndexPath *)indexPath
{
    return self.sections[indexPath.section][@"Settings"][indexPath.row];
}

- (void)didMakeChoice:(AwfulSettingsChoiceViewController *)choiceViewController
{
    [[NSUserDefaults standardUserDefaults] setObject:choiceViewController.selectedValue
                                              forKey:choiceViewController.setting[@"Key"]];
    [self.tableView reloadData];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return self.sections[section][@"Title"];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSString *title = [tableView.dataSource tableView:tableView titleForHeaderInSection:section];
    if (!title) return nil;
    
    UILabel *label = [UILabel new];
    label.frame = CGRectMake(20, 13, 280, 30);
    label.font = [UIFont boldSystemFontOfSize:17];
    label.text = title;
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor colorWithRed:0.265 green:0.294 blue:0.367 alpha:1];
    label.shadowColor = [UIColor whiteColor];
    label.shadowOffset = CGSizeMake(-1, 1);

    UIView *wrapper = [UIView new];
    wrapper.frame = (CGRect){ .size = { 320, 40 } };
    wrapper.backgroundColor = [UIColor clearColor];
    [wrapper addSubview:label];
    return wrapper;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    NSString *title = [tableView.dataSource tableView:tableView titleForHeaderInSection:section];
    return title ? 47 : 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return self.sections[section][@"Explanation"];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    NSString *text = [tableView.dataSource tableView:tableView titleForFooterInSection:section];
    if (!text) return nil;
    
    UILabel *label = [UILabel new];
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:15];
    label.frame = CGRectMake(20, 5, 280, 0);
    label.text = text;
    [label sizeToFit];
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor colorWithRed:0.298 green:0.337 blue:0.424 alpha:1];
    label.shadowColor = [UIColor whiteColor];
    label.shadowOffset = CGSizeMake(0, 1);
    
    UIView *wrapper = [UIView new];
    wrapper.frame = (CGRect){ .size = { 320, label.bounds.size.height + 5 } };
    wrapper.backgroundColor = [UIColor clearColor];
    [wrapper addSubview:label];
    return wrapper;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    NSString *text = [tableView.dataSource tableView:tableView titleForFooterInSection:section];
    if (!text) return 0;
    CGSize expected = [text sizeWithFont:[UIFont systemFontOfSize:15]
                                forWidth:280
                           lineBreakMode:NSLineBreakByWordWrapping];
    return expected.height + 5 + (section < tableView.numberOfSections - 1 ? 34 : 0);
}

#pragma mark - UIAlertView delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != 1) return;
    [[AwfulAppDelegate instance] logOut];
}

@end
