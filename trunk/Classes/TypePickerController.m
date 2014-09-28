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

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex == 0)
	{
		*editingItem = alertIndex;
	
		if (cell)
			cell.detailTextLabel.text = [types objectAtIndex:alertIndex];
	}

	[self.navigationController popViewControllerAnimated:YES];
}

- (NSIndexPath *)tableView:(UITableView *)aTableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	int row = (int)indexPath.row;

	if (row > 5)
	{
		alertIndex = row;
		UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Warning" message:@"You have selected a difficulty level that may take up to a minute for the AI to make a move, please try Expert or lower levels first before trying the harder levels. Are you sure you want to continue?" delegate:self cancelButtonTitle:@"Yes" otherButtonTitles:@"No", nil];
		[alertView show];
		[alertView release];
		return indexPath;
	}
	
	*editingItem = row;
	if (cell)
		cell.detailTextLabel.text = [types objectAtIndex:row];
	
	[self.navigationController popViewControllerAnimated:YES];
	
	return indexPath;
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell* nameCell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"nameCell"] autorelease];
	NSString* check = (indexPath.row == *editingItem) ? @"\u2713 " : @"\u2001 ";
	nameCell.textLabel.text = [check stringByAppendingString:[types objectAtIndex:indexPath.row]];
	return nameCell;
}

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section
{
	return [types count];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView
{
	return 1;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
	return [types objectAtIndex:row];
}

@end
