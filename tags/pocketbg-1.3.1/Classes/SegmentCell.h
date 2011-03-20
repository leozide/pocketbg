#import <UIKit/UIKit.h>

@interface SegmentCell : UITableViewCell
{
	UISegmentedControl* segmentedControl;
	int* value;
	int* valueMap;
}

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier withItems:(NSArray*)segments;
- (void)setValue:(int*)aValue withMap:(int*)aMap;

@property (nonatomic, retain) UISegmentedControl *segmentedControl;

@end
