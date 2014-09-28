#import <UIKit/UIKit.h>

@class CheckerCell;

@interface ColorListController : UIViewController <UITableViewDelegate, UITableViewDataSource>
{
	int *editingItem;
	UITableView *tableView;
	CheckerCell *cell;
}

@property (nonatomic, retain) CheckerCell *cell;
@property (nonatomic, retain) IBOutlet UITableView *tableView;

- (void)setEditingItem:(int*)aItem;

@end
