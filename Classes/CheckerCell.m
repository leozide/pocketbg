#import <UIKit/UIKit.h>
#import "CheckerCell.h"
#import "bgBoardData.h"
#import "bgBoard.h"

@implementation CheckerCell

@synthesize imageView;

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier
{
    if (self = [super initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:reuseIdentifier])
	{
		float size = self.contentView.bounds.size.height - 8;
		imageView = [[[UIImageView alloc] initWithFrame:CGRectMake(0,0,size,size)] autorelease];

		[self addSubview:imageView];
		self.accessoryView = imageView;
    }

    return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (void)setColor:(int)colorIndex
{
	self.textLabel.text = @"Color:";
	self.detailTextLabel.text = [NSString stringWithCString:gCheckerColors[colorIndex].Name encoding:NSASCIIStringEncoding];

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
