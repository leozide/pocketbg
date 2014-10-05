//
//  SettingsViewController.h
//  bg
//
//  Created by Leo on 6/20/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "EditableCell.h"

typedef struct
{
	char Player1[32];
	int Player1Color;
	int Player1Type;
	char Player2[32];
	int Player2Color;
	int Player2Type;
	int MatchLength;
	int Cube;
	int Crawford;
	int Jacoby;
	int Sounds;
	int Clockwise;
	int TargetHelp;
	int AdvancedHint;
} bgSettings;

@class ColorListController;
@class TypePickerController;

@interface SettingsViewController : UIViewController <UIScrollViewDelegate,
                                                      UITableViewDelegate, UITableViewDataSource,
                                                      UITextFieldDelegate, EditableTableViewCellDelegate>
{
	IBOutlet UITableView *tableView;
	UIView *headerView;
	NSArray *difficultyLevels;

@public
	bgSettings settings;
}

- (IBAction)cancelColor:(UIStoryboardSegue *)segue;

@property (nonatomic, retain) IBOutlet UITableView *tableView;
@property (nonatomic, retain) UIView *headerView;
@property (nonatomic, retain) NSArray *difficultyLevels;

@end
