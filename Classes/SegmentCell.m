#import "SegmentCell.h"

@implementation SegmentCell

@synthesize segmentedControl;

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier withItems:(NSArray*)segments
{
	if (self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])
	{
		// Set the frame to CGRectZero as it will be reset in layoutSubviews
		segmentedControl = [[UISegmentedControl alloc] initWithItems:segments];
		segmentedControl.frame = CGRectZero;
		[segmentedControl addTarget:self action:@selector(segmentAction:) forControlEvents:UIControlEventValueChanged];
//		[segmentedControl retain];

		UIView* view = [[UIView alloc] initWithFrame:CGRectZero];
		view.backgroundColor = [UIColor clearColor];
		self.backgroundView = view;
		[view release];

		[self addSubview:segmentedControl];
	}

	return self;
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	
	// Position each label with a modified version of the base rect.
	segmentedControl.frame = self.contentView.frame;
}

- (void)dealloc
{
	[segmentedControl release];
	[super dealloc];
}

- (void)segmentAction:(id)sender
{
	if (valueMap)
		*value = valueMap[segmentedControl.selectedSegmentIndex];
	else
		*value = (int)segmentedControl.selectedSegmentIndex;
}

- (void)setValue:(int*)aValue withMap:(int*)aMap
{
	value = aValue;
	valueMap = aMap;

	if (valueMap)
	{
		for (int i = 0; valueMap[i] >= 0; i++)
		{
			if (valueMap[i] == *value)
			{
				segmentedControl.selectedSegmentIndex = i;
				break;
			}
		}
	}
	else
		segmentedControl.selectedSegmentIndex = *value;
}

@end
