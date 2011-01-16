#import "ColorListController.h"
#import "CheckerCell.h"
#import "bgBoardData.h"
#import "bgBoard.h"

@interface CustomView : UIView
{
    NSString* title;
    UIImage* image;
}

@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) UIImage *image;

@end

#define MAIN_FONT_SIZE 18
#define MIN_MAIN_FONT_SIZE 16

@implementation CustomView

@synthesize title, image;

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        self.frame = CGRectMake(0.0, 0.0, 200.0, 44.0);    // we know the frame size
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.backgroundColor = [UIColor clearColor];    // make the background transparent
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    // draw the image and title using their draw methods
    CGFloat yCoord = (self.bounds.size.height - self.image.size.height) / 2;
    CGPoint point = CGPointMake(10.0, yCoord);
    [self.image drawAtPoint:point];
    
    yCoord = (self.bounds.size.height - MAIN_FONT_SIZE) / 2;
    point = CGPointMake(10.0 + self.image.size.width + 10.0, yCoord);
    [self.title drawAtPoint:point
	 forWidth:self.bounds.size.width
	 withFont:[UIFont systemFontOfSize:MAIN_FONT_SIZE]
	 minFontSize:MIN_MAIN_FONT_SIZE
	 actualFontSize:NULL
	 lineBreakMode:UILineBreakModeTailTruncation
	 baselineAdjustment:UIBaselineAdjustmentAlignBaselines];
}

- (void)dealloc
{
    [title release];
    [image release];
    [super dealloc];
}

@end

@implementation ColorListController

@synthesize pickerView, cell;

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
	[pickerView release];
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
	*editingItem = row;

	if (cell)
		[cell setColor:row];

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
	return @"Color";
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
	return gNumCheckerColors;
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
	return 1;
}

// tell the picker which view to use for a given component and row, we have an array of color views to show
- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)reuseView
{
	/*
    UIView *viewToUse = nil;
    if (component == 0)
    {
        viewToUse = [pickerViews objectAtIndex:row];
    }
    return viewToUse;
	 */

	float ChequerRadius = 14;
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(NULL, 2 * (ChequerRadius + 2), 2 * (ChequerRadius + 2), 8, 4 * 2 * (ChequerRadius + 2), colorSpace, kCGImageAlphaPremultipliedFirst);

	float* color = gCheckerColors[row].Value;
	CGContextSetRGBFillColor(context, color[0], color[1], color[2], color[3]);
	CGContextBeginPath(context);
	CGContextAddArc(context, ChequerRadius + 2, ChequerRadius + 2, ChequerRadius, 0.0, 2*M_PI, 1);
	CGContextDrawPath(context, kCGPathFillStroke);
	CGImageRef image = CGBitmapContextCreateImage(context);
		
	CustomView *view = reuseView ? (CustomView*)reuseView : [[[CustomView alloc] initWithFrame:CGRectZero] autorelease];
	view.title = [NSString stringWithCString:gCheckerColors[row].Name encoding:NSASCIIStringEncoding];
	view.image = [UIImage imageWithCGImage:image];
	CGImageRelease(image);
	
	CGContextRelease(context);
	CGColorSpaceRelease(colorSpace);

	return view;
}
/*
// tell the picker the width of each row for a given component (in our case we have one component)
- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component
{
    CustomView *viewToUse = [pickerViews objectAtIndex:0];
    return viewToUse.bounds.size.width;
}

// tell the picker the height of each row for a given component (in our case we have one component)
- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component
{
    CustomView *viewToUse = [pickerViews objectAtIndex:0];
    return viewToUse.bounds.size.height;
}
*/
@end
