//
//  SettingsViewController.m
//  bg
//
//  Created by Leo on 6/20/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "SettingsViewController.h"
#import "RootViewController.h"
#import "TypePickerController.h"
#import "ColorListController.h"
#import "bgAppDelegate.h"
#import "EditableCell.h"
#import "SegmentCell.h"
#import "SwitchCell.h"
#import "CheckerCell.h"

@implementation SettingsViewController

@synthesize tableView, headerView, difficultyLevels;

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	self.navigationController.navigationBarHidden = NO;
}

- (void)viewWillAppear:(BOOL)animated
{
	[tableView reloadData];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}

- (void)dealloc
{
	[difficultyLevels release];
	[tableView release];
	[headerView release];
	[super dealloc];
}

- (IBAction)cancelColor:(UIStoryboardSegue *)segue
{
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[aTableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (NSIndexPath *)tableView:(UITableView *)aTableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.row != 0 || indexPath.section != 0)
	{
		EditableCell* cell = (EditableCell*)[tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
		[cell.textField resignFirstResponder];
	}

	if (indexPath.row != 0 || indexPath.section != 1)
	{
		EditableCell* cell = (EditableCell*)[tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1]];
		[cell.textField resignFirstResponder];
	}

	if ((indexPath.section == 0 || indexPath.section == 1) && indexPath.row == 1)
	{
		UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
		ColorListController* colorListController = (ColorListController *)[storyboard instantiateViewControllerWithIdentifier:@"ColorListController"];
		
		colorListController.cell = (CheckerCell*)[tableView cellForRowAtIndexPath:indexPath];
		if (indexPath.section == 0)
			[colorListController setEditingItem:&settings.Player1Color];
		else
			[colorListController setEditingItem:&settings.Player2Color];

		[self.navigationController pushViewController:colorListController animated:YES];
	}

	if ((indexPath.section == 0 || indexPath.section == 1) && indexPath.row == 2)
	{
		UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
		TypePickerController* typePickerController = (TypePickerController *)[storyboard instantiateViewControllerWithIdentifier:@"TypePickerController"];
		
		typePickerController.types = difficultyLevels;
		typePickerController.cell = [tableView cellForRowAtIndexPath:indexPath];
		if (indexPath.section == 0)
			[typePickerController setEditingItem:&settings.Player1Type];
		else
			[typePickerController setEditingItem:&settings.Player2Type];

		[self.navigationController pushViewController:typePickerController animated:YES];
	 }

	return indexPath;
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 0 || indexPath.section == 1)
	{
		if (indexPath.row == 0)
		{
			EditableCell* cell = [[[EditableCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"editableCell"] autorelease];
			
			cell.textLabel.text = @"Name:";
			cell.textField.placeholder = @"<Player Name>";
			cell.textField.keyboardType = UIKeyboardTypeDefault;
			if (indexPath.section == 0)
				[cell setText:settings.Player1 withMax:sizeof(settings.Player1)];
			else
				[cell setText:settings.Player2 withMax:sizeof(settings.Player2)];

			return cell;
		}
		else if (indexPath.row == 1)
		{
			CheckerCell* cell = [[[CheckerCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"checkerCell"] autorelease];

			if (indexPath.section == 0)
				[cell setColor:settings.Player1Color];
			else
				[cell setColor:settings.Player2Color];

			return cell;
		}
		else if (indexPath.row == 2)
		{
			UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TypeCell"];
			if (cell == nil)
				cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:@"TypeCell"] autorelease];
			cell.textLabel.text = @"Type:";
			if (indexPath.section == 0)
				cell.detailTextLabel.text = [difficultyLevels objectAtIndex:settings.Player1Type];
			else
				cell.detailTextLabel.text = [difficultyLevels objectAtIndex:settings.Player2Type];
			return cell;
		}
	}
	else if (indexPath.section == 2)
	{
		if (indexPath.row == 0)
		{
			NSArray *segments = [NSArray arrayWithObjects: @"1", @"3", @"5", @"7", @"9", @"11", @"13", @"15", @"$", nil];
			static int lengthMap[] = { 1, 3, 5, 7, 9, 11, 13, 15, 0 };

			SegmentCell* cell = [[[SegmentCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"segmentCell" withItems:segments] autorelease];
			[cell setValue:&settings.MatchLength withMap:lengthMap];

			return cell;
		}
	}
	else if (indexPath.section == 3)
	{
		if (indexPath.row == 0 || indexPath.row == 1 || indexPath.row == 2)
		{
			SwitchCell *cell = (SwitchCell*)[aTableView dequeueReusableCellWithIdentifier:@"switchCell"];
			if (cell == nil)
				cell = [[[SwitchCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"switchCell"] autorelease];
			
			if (indexPath.row == 0)
			{
				cell.textLabel.text = @"Use doubling cube";
				[cell setValue:&settings.Cube];
			}
			else if (indexPath.row == 1)
			{
				cell.textLabel.text = @"Use Crawford Rule";
				[cell setValue:&settings.Crawford];
			}
			else
			{
				cell.textLabel.text = @"Use Jacoby Rule";
				[cell setValue:&settings.Jacoby];
			}

			return cell;
		}
	}
	else if (indexPath.section == 4)
	{
		if (indexPath.row == 0 || indexPath.row == 1 || indexPath.row == 2 || indexPath.row == 3)
		{
			SwitchCell *cell = (SwitchCell*)[aTableView dequeueReusableCellWithIdentifier:@"switchCell"];
			if (cell == nil)
				cell = [[[SwitchCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"switchCell"] autorelease];
			
			if (indexPath.row == 0)
			{
				cell.textLabel.text = @"Enable Sounds";
				[cell setValue:&settings.Sounds];
			}
			else if (indexPath.row == 1)
			{
				cell.textLabel.text = @"Show Target Help";
				[cell setValue:&settings.TargetHelp];
			}
			else if (indexPath.row == 2)
			{
				cell.textLabel.text = @"Clockwise Movement";
				[cell setValue:&settings.Clockwise];
			}
			else if (indexPath.row == 3)
			{
				cell.textLabel.text = @"Advanced Hints";
				[cell setValue:&settings.AdvancedHint];
			}
			
			return cell;
		}
	}
			
	return nil;
}

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section
{
	switch (section)
	{
		case 0: return 3;
		case 1: return 3;
		case 2: return 1;
		case 3: return 3;
		case 4: return 4;
	}

	return 0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView
{
	return 5;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	switch (section)
	{
		case 0: return @"Player 1";
		case 1: return @"Player 2";
		case 2: return @"Match Length";
		case 3: return @"Cube Rules";
		case 4: return @"Options";
	}

	return @"";
}

@end
