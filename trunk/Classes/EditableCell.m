#import "EditableCell.h"

@implementation EditableCell

@synthesize textField;

// Instruct the compiler to create accessor methods for the property.
// It will use the internal variable with the same name for storage.
@synthesize delegate;
@synthesize isInlineEditing;

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier
{
	text = nil;
	maxText = 0;
	number = nil;

	if (self = [super initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:reuseIdentifier])
	{
		self.detailTextLabel.text = @" ";
		
		textField = [[UITextField alloc] initWithFrame:CGRectZero];
		textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
		textField.font = [UIFont systemFontOfSize:18.0];
		textField.textColor = [UIColor blackColor];
		textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
		textField.autocorrectionType = UITextAutocorrectionTypeNo;
		textField.returnKeyType = UIReturnKeyDone;
		textField.delegate = self;

#if PBG_HD
		[self.contentView addSubview: textField];
#else
		[self addSubview: textField];
#endif
	}

	return self;
}

- (void)dealloc
{
	// Release allocated resources.
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
	
	CGRect baseRect = self.detailTextLabel.frame;//self.contentView.bounds;
	baseRect.size.width = self.contentView.frame.size.width / 2;
	textField.frame = baseRect;
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
	textField.text = [NSString stringWithCString:text encoding:NSASCIIStringEncoding];
}

- (void)setNumber:(int*)aNumber
{
	text = nil;
	maxText = 0;
	number = aNumber;
	textField.text = [NSString stringWithFormat:@"%d", *number];
}

@end
