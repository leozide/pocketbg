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
#if PBG_HD
	UIPopoverController* popoverController;
    UIToolbar *toolbar;
#endif
}

@property (nonatomic, retain) bgViewController* mainViewController;
@property (nonatomic, retain) SettingsViewController* settingsViewController;
@property (nonatomic, retain) HelpViewController* helpViewController;
@property (nonatomic, retain) UINavigationBar* settingsNavigationBar;
@property (nonatomic, retain) UINavigationBar* helpNavigationBar;

#if PBG_HD
@property (nonatomic, retain) UIPopoverController* popoverController;
@property (nonatomic, retain) IBOutlet UIToolbar *toolbar;
#endif

-(void) SaveMatch;
-(void) ShowSettingsView:(id)sender;
-(void) ShowMainView;
-(void) ShowHelpView:(id)sender;
-(void) ShowAnalysisView:(id)sender;

- (IBAction)cancel;
- (IBAction)save;

@end
