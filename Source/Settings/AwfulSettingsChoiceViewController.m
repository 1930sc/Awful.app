//
//  AwfulSettingsChoiceViewController.m
//  Awful
//
//  Created by Nolan Waite on 12-04-21.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulSettingsChoiceViewController.h"
#import "AwfulSettingsViewController.h"
#import "AwfulSettings.h"

@interface AwfulSettingsChoiceViewController ()

@property (strong) NSDictionary *setting;

@property (weak) id selectedValue;

@property (strong) NSIndexPath *currentIndexPath;

@end

@implementation AwfulSettingsChoiceViewController

#pragma mark - Init

- (id)initWithSetting:(NSDictionary *)setting selectedValue:(id)selectedValue
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.setting = setting;
        self.selectedValue = selectedValue;
        self.title = [setting objectForKey:@"Title"];
    }
    return self;
}

- (id)initWithStyle:(UITableViewStyle)style
{
    return [self initWithSetting:nil selectedValue:nil];
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = [UIColor colorWithHue:0.604 saturation:0.035 brightness:0.898 alpha:1];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.settingsViewController didMakeChoice:self];
    [super viewWillDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - UITableView data source and delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[self.setting objectForKey:@"Choices"] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:CellIdentifier];
    }
    
    NSDictionary *choice = [[self.setting objectForKey:@"Choices"] objectAtIndex:indexPath.row];
    
    cell.textLabel.text = [choice objectForKey:@"Title"];
    if ([[choice objectForKey:@"Value"] isEqual:self.selectedValue]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        self.currentIndexPath = indexPath;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([indexPath isEqual:self.currentIndexPath]) {
        return;
    }
    NSDictionary *choice = [[self.setting objectForKey:@"Choices"] objectAtIndex:indexPath.row];
    self.selectedValue = [choice objectForKey:@"Value"];
    UITableViewCell *oldCell = [tableView cellForRowAtIndexPath:self.currentIndexPath];
    oldCell.accessoryType = UITableViewCellAccessoryNone;
    UITableViewCell *newCell = [tableView cellForRowAtIndexPath:indexPath];
    newCell.accessoryType = UITableViewCellAccessoryCheckmark;
    self.currentIndexPath = indexPath;
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
