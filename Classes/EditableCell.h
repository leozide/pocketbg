#import <UIKit/UIKit.h>

@protocol EditableTableViewCellDelegate;

@interface EditableCell : UITableViewCell <UITextFieldDelegate>
{
	id <EditableTableViewCellDelegate> delegate;
	BOOL isInlineEditing;
	UITextField *textField;
    UITextField *label;
	int labelWidth;
	char* text;
	int maxText;
	int* number;
}

@property (nonatomic, retain) UITextField *textField;
@property (nonatomic, retain) UITextField *label;
@property (nonatomic, assign) int labelWidth;

// Exposes the delegate property to other objects.
@property (nonatomic, assign) id <EditableTableViewCellDelegate> delegate;
@property (nonatomic, assign) BOOL isInlineEditing;

// Informs the cell to stop editing, resulting in keyboard/pickers/etc. being ordered out 
// and first responder status resigned.
- (void)stopEditing;

- (void)setText:(char*)aText withMax:(int)aMaxText;
- (void)setNumber:(int*)aNumber;

@end

// Protocol to be adopted by an object wishing to customize cell behavior with respect to editing.
@protocol EditableTableViewCellDelegate <NSObject>

@optional

// Invoked before editing begins. The delegate may return NO to prevent editing.
- (BOOL)cellShouldBeginEditing:(EditableCell *)cell;
// Invoked after editing ends.
- (void)cellDidEndEditing:(EditableCell *)cell;

@end
