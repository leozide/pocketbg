#import <UIKit/UIKit.h>

@interface TypePickerController : UIViewController <UIPickerViewDelegate, UIPickerViewDataSource, UIAlertViewDelegate>
{
	NSArray *types;
	int *editingItem;
	UIPickerView *pickerView;
	UITableViewCell *cell;
}

@property (nonatomic, retain) NSArray *types;
@property (nonatomic, retain) UITableViewCell *cell;
@property (nonatomic, retain) IBOutlet UIPickerView *pickerView;

- (void)setEditingItem:(int*)aItem;

- (IBAction)cancel;
- (IBAction)save;

@end
