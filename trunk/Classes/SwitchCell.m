#import "SwitchCell.h"

@implementation SwitchCell

@synthesize switchControl;

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier
{
	value = nil;
	
	if (self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])
	{
		switchControl = [[[UISwitch alloc] initWithFrame:CGRectZero] autorelease];
		[switchControl addTarget:self action:@selector(segmentAction:) forControlEvents:UIControlEventValueChanged];

		[self addSubview:switchControl];
		self.accessoryView = switchControl;
	}
	return self;
}

- (void)dealloc
{
	[super dealloc];
}

- (void)segmentAction:(id)sender
{
	if (value)
		*value = switchControl.on;
}

- (void)setValue:(int*)aValue
{
	value = aValue;
	if (value)
		switchControl.on = (*value != 0);
}

@end
