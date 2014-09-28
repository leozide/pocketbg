//
//  bgViewController.h
//  bg
//
//  Created by Leo on 5/8/09.
//  Copyright __MyCompanyName__ 2009. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SettingsViewController;

@interface bgViewController : UIViewController
{
	SettingsViewController* settingsViewController;
	UINavigationBar* settingsNavigationBar;
	UINavigationBar* helpNavigationBar;
}

@property (nonatomic, retain) SettingsViewController* settingsViewController;
@property (nonatomic, retain) UINavigationBar* settingsNavigationBar;
@property (nonatomic, retain) UINavigationBar* helpNavigationBar;

-(void) SaveMatch;
-(void) ShowSettingsView:(id)sender;
-(void) ShowMainView;
-(void) ShowHelpView:(id)sender;

- (IBAction)cancel;
- (IBAction)save;

@end
