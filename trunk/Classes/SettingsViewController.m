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

@synthesize tableView, headerView, colorListController, typePickerController, difficultyLevels;

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
	[super viewDidLoad];
	difficultyLevels = [[NSArray alloc] initWithObjects: @"Human", @"AI - Beginner", @"AI - Intermediate", @"AI - Expert", @"AI - World Class", @"AI - Grandmaster", nil];
}

- (void)viewWillAppear:(BOOL)animated
{
	[tableView reloadData];
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	// Return YES for supported orientations
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}

- (void)dealloc
{
	[difficultyLevels release];
	[typePickerController release];
	[colorListController release];
	[tableView release];
	[headerView release];
	[super dealloc];
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
		if (!colorListController)
		{
			ColorListController *controller = [[ColorListController alloc] initWithNibName:@"ColorListView" bundle:nil];
			self.colorListController = controller;
			[controller release];
		}

		colorListController.cell = (CheckerCell*)[tableView cellForRowAtIndexPath:indexPath];
		if (indexPath.section == 0)
			[colorListController setEditingItem:&settings.Player1Color];
		else
			[colorListController setEditingItem:&settings.Player2Color];

		bgAppDelegate* delegate = [[UIApplication sharedApplication] delegate];
		RootViewController* rootViewController = [delegate rootViewController];
		
		UIView *colorView = colorListController.view;
		colorView.frame = CGRectMake(0, 321, 320, 480);
		
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:1];
		[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
		colorListController.view.frame = CGRectMake(0, 0, 320, 480);
		
		[colorListController viewWillAppear:YES];
		[rootViewController.view addSubview:colorView];
		[colorListController viewDidAppear:YES];
		[UIView commitAnimations];
	}

	if ((indexPath.section == 0 || indexPath.section == 1) && indexPath.row == 2)
	{
		 if (!typePickerController)
		 {
			 TypePickerController *controller = [[TypePickerController alloc] initWithNibName:@"TypePicker" bundle:nil];
			 self.typePickerController = controller;
			 [controller release];
		 }

		 typePickerController.types = difficultyLevels;
		 typePickerController.cell = [tableView cellForRowAtIndexPath:indexPath];
		 if (indexPath.section == 0)
			 [typePickerController setEditingItem:&settings.Player1Type];
		 else
			 [typePickerController setEditingItem:&settings.Player2Type];

		 bgAppDelegate* delegate = [[UIApplication sharedApplication] delegate];
		 RootViewController* rootViewController = [delegate rootViewController];
		 
		 UIView *typeView = typePickerController.view;
		 typeView.frame = CGRectMake(0, 321, 320, 480);

		 [UIView beginAnimations:nil context:NULL];
		 [UIView setAnimationDuration:1];
		 [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
		 typePickerController.view.frame = CGRectMake(0, 0, 320, 480);

		 [typePickerController viewWillAppear:YES];
		 [rootViewController.view addSubview:typeView];
		 [typePickerController viewDidAppear:YES];
		 [UIView commitAnimations];
	 }

	return indexPath;
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 0 || indexPath.section == 1)
	{
		if (indexPath.row == 0)
		{
			EditableCell* cell = [[[EditableCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"editableCell"] autorelease];
			
			cell.label.text = @"Name:";
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
			CheckerCell* cell = [[[CheckerCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"checkerCell"] autorelease];

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
				cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"TypeCell"] autorelease];
			if (indexPath.section == 0)
				cell.text = [difficultyLevels objectAtIndex:settings.Player1Type];
			else
				cell.text = [difficultyLevels objectAtIndex:settings.Player2Type];
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
				cell = [[[SwitchCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"switchCell"] autorelease];
			
			if (indexPath.row == 0)
			{
				cell.label.text = @"Use doubling cube";
				[cell setValue:&settings.Cube];
			}
			else if (indexPath.row == 1)
			{
				cell.label.text = @"Use Crawford Rule";
				[cell setValue:&settings.Crawford];
			}
			else
			{
				cell.label.text = @"Use Jacoby Rule";
				[cell setValue:&settings.Jacoby];
			}

			return cell;
		}
	}
	else if (indexPath.section == 4)
	{
		if (indexPath.row == 0 || indexPath.row == 1 || indexPath.row == 2)
		{
			SwitchCell *cell = (SwitchCell*)[aTableView dequeueReusableCellWithIdentifier:@"switchCell"];
			if (cell == nil)
				cell = [[[SwitchCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"switchCell"] autorelease];
			
			if (indexPath.row == 0)
			{
				cell.label.text = @"Enable Sounds";
				[cell setValue:&settings.Sounds];
			}
			else if (indexPath.row == 1)
			{
				cell.label.text = @"Show Target Help";
				[cell setValue:&settings.TargetHelp];
			}
			else if (indexPath.row == 2)
			{
				cell.label.text = @"Clockwise Movement";
				[cell setValue:&settings.Clockwise];
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
		case 4: return 3;
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
