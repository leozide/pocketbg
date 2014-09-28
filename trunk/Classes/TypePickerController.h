#import <UIKit/UIKit.h>

@interface TypePickerController : UIViewController <UITableViewDelegate, UITableViewDataSource, UIAlertViewDelegate>
{
	NSArray *types;
	int *editingItem;
	UITableView *pickerView;
	UITableViewCell *cell;
	int alertIndex;
}

@property (nonatomic, retain) NSArray *types;
@property (nonatomic, retain) UITableViewCell *cell;
@property (nonatomic, retain) IBOutlet UITableView *pickerView;

- (void)setEditingItem:(int*)aItem;

@end
