#import <UIKit/UIKit.h>

@class SettingsViewController;

@interface bgViewController : UIViewController
{
}

-(void) ShowSettingsView:(id)sender;
-(void) ShowHelpView:(id)sender;

- (IBAction)cancelSettings:(UIStoryboardSegue *)segue;
- (IBAction)saveSettings:(UIStoryboardSegue *)segue;

@end
