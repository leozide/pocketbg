#import "EditableCell.h"

@implementation EditableCell

@synthesize textField;
@synthesize label;
@synthesize labelWidth;

// Instruct the compiler to create accessor methods for the property.
// It will use the internal variable with the same name for storage.
@synthesize delegate;
@synthesize isInlineEditing;

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier
{
	text = nil;
	maxText = 0;
	number = nil;
	labelWidth = 60;

	if (self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier])
	{
		// Initialize the labels, their fonts, colors, alignment, and background color.
		label = [[UILabel alloc] initWithFrame:CGRectZero];
		label.font = [UIFont systemFontOfSize:16];
		label.textColor = [UIColor darkGrayColor];
		label.textAlignment = UITextAlignmentRight;
		label.backgroundColor = [UIColor clearColor];
		
		// Set the frame to CGRectZero as it will be reset in layoutSubviews
		textField = [[UITextField alloc] initWithFrame:CGRectZero];
		textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
		textField.font = [UIFont systemFontOfSize:20.0];
		textField.textColor = [UIColor blackColor];
		textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
		textField.autocorrectionType = UITextAutocorrectionTypeNo;
		textField.returnKeyType = UIReturnKeyDone;
		textField.delegate = self;
		[textField retain];

		[self addSubview:label];
		[self addSubview:textField];
	}

	return self;
}

- (void)dealloc
{
	// Release allocated resources.
	[label release];
	[textField release];
	[super dealloc];
}

- (void)stopEditing
{
    [textField resignFirstResponder];
    [self textFieldDidEndEditing:textField];
}

- (void)layoutSubviews
{
	[super layoutSubviews];

	// Start with a rect that is inset from the content view by 10 pixels on all sides.
	CGRect baseRect = CGRectInset(self.contentView.bounds, 10, 10);
	CGRect rect = baseRect;

	// Position each label with a modified version of the base rect.
	rect.origin.x += 5;
	rect.size.width = labelWidth;
	label.frame = rect;
	rect.origin.x += labelWidth + 10;
	rect.size.width = baseRect.size.width - (labelWidth + 10);
	textField.frame = rect;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
	[super setSelected:selected animated:animated];

	// Update text color so that it matches expected selection behavior.
	if (selected)
		textField.textColor = [UIColor whiteColor];
	else
		textField.textColor = [UIColor blackColor];
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    BOOL beginEditing = YES;
    // Allow the cell delegate to override the decision to begin editing.
    if (self.delegate && [self.delegate respondsToSelector:@selector(cellShouldBeginEditing:)])
	{
        beginEditing = [self.delegate cellShouldBeginEditing:self];
    }
    // Update internal state.
    if (beginEditing)
		self.isInlineEditing = YES;
    return beginEditing;
}

- (void)textFieldDidEndEditing:(UITextField *)aTextField
{
    // Notify the cell delegate that editing ended.
    if (self.delegate && [self.delegate respondsToSelector:@selector(cellShouldEndEditing:)])
	{
        [self.delegate cellDidEndEditing:self];
    }

    // Update internal state.
    self.isInlineEditing = NO;

	// Save text.
	if (text)
		[textField.text getCString:text maxLength:maxText encoding:NSASCIIStringEncoding];

	if (number)
		*number = [textField.text integerValue];
}
 
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self stopEditing];
    return YES;
}

- (void)setText:(char*)aText withMax:(int)aMaxText
{
	text = aText;
	maxText = aMaxText;
	number = nil;
	textField.text = [NSString stringWithCString:text];
}

- (void)setNumber:(int*)aNumber
{
	text = nil;
	maxText = 0;
	number = aNumber;
	textField.text = [NSString stringWithFormat:@"%d", *number];
}

@end
