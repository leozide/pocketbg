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
}

-(void) SaveMatch;
-(void) ShowSettingsView:(id)sender;
-(void) ShowHelpView:(id)sender;

- (IBAction)cancelSettings:(UIStoryboardSegue *)segue;
- (IBAction)saveSettings:(UIStoryboardSegue *)segue;

@end
