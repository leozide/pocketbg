#import "ColorListController.h"
#import "CheckerCell.h"
#import "bgBoardData.h"
#import "bgBoard.h"

@implementation ColorListController

@synthesize tableView, cell;

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

- (void)viewDidLoad
{
	[super viewDidLoad];
}

- (void)dealloc
{
	[cell release];
	[tableView release];
	[super dealloc];
}

- (void)viewWillAppear:(BOOL)animated
{
//	[pickerView selectRow:*editingItem inComponent:0 animated:NO];
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[aTableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (NSIndexPath *)tableView:(UITableView *)aTableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	int row = (int)indexPath.row;
	*editingItem = row;
	
	if (cell)
		[cell setColor:row];
	
	[self.navigationController popViewControllerAnimated:YES];
	
	return indexPath;
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell* checkerCell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"checkerCell"] autorelease];
	
	float size = checkerCell.contentView.bounds.size.height - 8;
	UIImageView* imageView = [[[UIImageView alloc] initWithFrame:CGRectMake(0,0,size,size)] autorelease];
		
	[checkerCell addSubview:imageView];
	checkerCell.accessoryView = imageView;
	
	NSString* name = [NSString stringWithCString:gCheckerColors[indexPath.row].Name encoding:NSASCIIStringEncoding];
	NSString* check = (indexPath.row == *editingItem) ? @"\u2713 " : @"\u2001 ";
	checkerCell.textLabel.text = [check stringByAppendingString:name];
	float ChequerRadius = 14;
		
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(NULL, 2 * (ChequerRadius + 2), 2 * (ChequerRadius + 2), 8, 4 * 2 * (ChequerRadius + 2), colorSpace, kCGImageAlphaPremultipliedFirst);
		
	float* color = gCheckerColors[indexPath.row].Value;
	CGContextSetRGBFillColor(context, color[0], color[1], color[2], color[3]);
	CGContextBeginPath(context);
	CGContextAddArc(context, ChequerRadius + 2, ChequerRadius + 2, ChequerRadius, 0.0, 2*M_PI, 1);
	CGContextDrawPath(context, kCGPathFillStroke);
	CGImageRef image = CGBitmapContextCreateImage(context);
		
	CGContextRelease(context);
	CGColorSpaceRelease(colorSpace);
		
	imageView.image = [UIImage imageWithCGImage:image];
	CGImageRelease(image);
	
	return checkerCell;
}

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section
{
	return gNumCheckerColors;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView
{
	return 1;
}

@end
