#import <UIKit/UIKit.h>

@class CheckerCell;

@interface ColorListController : UIViewController <UIPickerViewDelegate, UIPickerViewDataSource>
{
	int *editingItem;
	UIPickerView *pickerView;
	CheckerCell *cell;
}

@property (nonatomic, retain) CheckerCell *cell;
@property (nonatomic, retain) IBOutlet UIPickerView *pickerView;

- (void)setEditingItem:(int*)aItem;

- (IBAction)cancel;
- (IBAction)save;

@end
