#import "TypePickerController.h"

@implementation TypePickerController

@synthesize types, pickerView, cell;

- (void)setEditingItem:(int*)aItem
{
	editingItem = aItem;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview.
}

- (void)dealloc
{
	[cell release];
	[pickerView release];
	[types release];
	[super dealloc];
}

- (void)viewWillAppear:(BOOL)animated
{
	[pickerView selectRow:*editingItem inComponent:0 animated:NO];
}

- (IBAction)cancel
{
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:1];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(animationEnded:finished:context:)];
	self.view.frame = CGRectMake(0, 321, 320, 480);
	[UIView commitAnimations];
}

- (IBAction)save
{
	int row = [pickerView selectedRowInComponent:0];

	if (row > 5)
	{
		UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Warning" message:@"You have selected a difficulty level that may take up to a minute for the AI to make a move, please try Expert or lower levels first before trying the harder levels. Are you sure you want to continue?" delegate:self cancelButtonTitle:@"Yes" otherButtonTitles:@"No", nil];
		[alertView show];
		[alertView release];
		return;
	}

	*editingItem = row;

	if (cell)
		cell.detailTextLabel.text = [types objectAtIndex:row];

	[self cancel];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex == 0)
	{
		int row = [pickerView selectedRowInComponent:0];
		*editingItem = row;
	
		if (cell)
			cell.detailTextLabel.text = [types objectAtIndex:row];
	}

	[self cancel];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
	// TODO: place a check mark
}

- (void)animationEnded:(NSString*)animationID finished:(NSNumber*)finished context:(void*)context
{
	[self viewWillDisappear:YES];
	[self.view removeFromSuperview];
	[self viewDidDisappear:YES];
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
	return [types objectAtIndex:row];
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
	return [types count];
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
	return 1;
}

@end
