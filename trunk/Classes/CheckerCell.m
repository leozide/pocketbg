#import <UIKit/UIKit.h>
#import "CheckerCell.h"
#import "bgBoardData.h"
#import "bgBoard.h"

@implementation CheckerCell

@synthesize imageView;
@synthesize label;
@synthesize name;

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier
{
    if (self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier])
	{
		// Set the frame to CGRectZero as it will be reset in layoutSubviews
		imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
//		[imageView retain];

		// Initialize the labels, their fonts, colors, alignment, and background color.
		label = [[UILabel alloc] initWithFrame:CGRectZero];
		label.font = [UIFont systemFontOfSize:16];
		label.textColor = [UIColor darkGrayColor];
		label.textAlignment = UITextAlignmentLeft;
		label.backgroundColor = [UIColor clearColor];

		name = [[UILabel alloc] initWithFrame:CGRectZero];
		name.font = [UIFont systemFontOfSize:20];
		name.textColor = [UIColor blackColor];
		name.textAlignment = UITextAlignmentLeft;
		name.backgroundColor = [UIColor clearColor];

		[self addSubview:imageView];
		[self addSubview:label];
		[self addSubview:name];
    }

    return self;
}

- (void)dealloc
{
	[imageView release];
	[label release];
	[name release];
    [super dealloc];
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	
	CGRect baseRect = self.contentView.bounds;
	CGRect rect = baseRect;
	
	// Position each label with a modified version of the base rect.
	rect.origin.x += 25;
	rect.size.width = 60;
	label.frame = rect;

	rect.origin.x += 60;
	rect.size.width = 170;
	name.frame = rect;
	
	rect.origin.x += rect.size.width - 5;
	rect.origin.y = (baseRect.size.height - 2 * (CHEQUER_RADIUS + 2)) / 2;
	rect.size.width = 2 * (CHEQUER_RADIUS + 2);
	rect.size.height = 2 * (CHEQUER_RADIUS + 2);
	imageView.frame = rect;
}

- (void)setColor:(int)colorIndex
{
	label.text = @"Color:";
	name.text = [NSString stringWithCString:gCheckerColors[colorIndex].Name];

	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(NULL, 2 * (CHEQUER_RADIUS + 2), 2 * (CHEQUER_RADIUS + 2), 8, 4 * 2 * (CHEQUER_RADIUS + 2), colorSpace, kCGImageAlphaPremultipliedFirst);
	
	float* color = gCheckerColors[colorIndex].Value;
	CGContextSetRGBFillColor(context, color[0], color[1], color[2], color[3]);
	CGContextBeginPath(context);
	CGContextAddArc(context, CHEQUER_RADIUS + 2, CHEQUER_RADIUS + 2, CHEQUER_RADIUS, 0.0, 2*M_PI, 1);
	CGContextDrawPath(context, kCGPathFillStroke);
	CGImageRef image = CGBitmapContextCreateImage(context);

	CGContextRelease(context);
	CGColorSpaceRelease(colorSpace);

	imageView.image = [UIImage imageWithCGImage:image];
	CGImageRelease(image);
}

@end
