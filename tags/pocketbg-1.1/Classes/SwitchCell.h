#import <UIKit/UIKit.h>

@interface SwitchCell : UITableViewCell
{
	UITextField* label;
	UISwitch* switchControl;
	int* value;
}

- (void)setValue:(int*)aValue;

@property (nonatomic, retain) UITextField *label;
@property (nonatomic, retain) UISwitch *switchControl;

@end
