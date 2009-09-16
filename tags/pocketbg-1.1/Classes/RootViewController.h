//
//  RootViewController.h
//  bg
//
//  Created by Leo on 6/18/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class bgViewController;
@class SettingsViewController;
@class HelpViewController;

@interface RootViewController : UIViewController
{
    bgViewController* mainViewController;
    SettingsViewController* settingsViewController;
	HelpViewController* helpViewController;
	UINavigationBar* settingsNavigationBar;
	UINavigationBar* helpNavigationBar;
}

@property (nonatomic, retain) bgViewController* mainViewController;
@property (nonatomic, retain) SettingsViewController* settingsViewController;
@property (nonatomic, retain) HelpViewController* helpViewController;
@property (nonatomic, retain) UINavigationBar* settingsNavigationBar;
@property (nonatomic, retain) UINavigationBar* helpNavigationBar;

-(void) SaveMatch;
-(void) ShowSettingsView;
-(void) ShowMainView;
-(void) ShowHelpView;

- (IBAction)cancel;
- (IBAction)save;

@end
