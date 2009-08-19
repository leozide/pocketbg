#import "SwitchCell.h"

@implementation SwitchCell

@synthesize label;
@synthesize switchControl;

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier
{
	value = nil;
	
	if (self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier])
	{
		// Initialize the labels, their fonts, colors, alignment, and background color.
		label = [[UILabel alloc] initWithFrame:CGRectZero];
		label.font = [UIFont systemFontOfSize:16];
		label.textColor = [UIColor darkGrayColor];
		label.textAlignment = UITextAlignmentLeft;
		label.backgroundColor = [UIColor clearColor];
		
		// Set the frame to CGRectZero as it will be reset in layoutSubviews
		switchControl = [[UISwitch alloc] initWithFrame:CGRectZero];
		[switchControl addTarget:self action:@selector(segmentAction:) forControlEvents:UIControlEventValueChanged];
		[switchControl retain];
		
		[self addSubview:label];
		[self addSubview:switchControl];
	}
	return self;
}

- (void)dealloc
{
	[label release];
	[switchControl release];
	[super dealloc];
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	
	CGRect baseRect = self.contentView.bounds;
	CGRect rect = baseRect;
	
	// Position each label with a modified version of the base rect.
	rect.origin.x += 15;
	rect.size.width = baseRect.size.width - 94 - 10;
	label.frame = rect;
	rect.origin.x += rect.size.width - 5;
	rect.origin.y += 10;
	rect.size.width = 94;
	rect.size.height = 27;
	switchControl.frame = rect;
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
