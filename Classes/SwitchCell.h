#import <UIKit/UIKit.h>

@interface SwitchCell : UITableViewCell
{
	UISwitch* switchControl;
	int* value;
}

- (void)setValue:(int*)aValue;

@property (nonatomic, retain) UISwitch *switchControl;

@end
