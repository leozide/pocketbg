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
	int Player1Type;
	char Player2[32];
	int Player2Type;
	int MatchLength;
	int Cube;
	int Crawford;
	int Jacoby;
	int Sounds;
	int Clockwise;
	int TargetHelp;
} bgSettings;

@class TypePickerController;

@interface SettingsViewController : UIViewController <UIScrollViewDelegate,
                                                      UITableViewDelegate, UITableViewDataSource,
                                                      UITextFieldDelegate, EditableTableViewCellDelegate>
{
	TypePickerController *typePickerController;
	IBOutlet UITableView *tableView;
	UIView *headerView;
	NSArray *difficultyLevels;

@public
	bgSettings settings;
}

@property (nonatomic, retain) TypePickerController *typePickerController;
@property (nonatomic, retain) IBOutlet UITableView *tableView;
@property (nonatomic, retain) UIView *headerView;
@property (nonatomic, retain) NSArray *difficultyLevels;

@end
