#import <UIKit/UIKit.h>

@interface bgView : UIView
{
	CGContextRef cgContext;

	CGImage* boardImage;
	CGImage* whiteImage;
	CGImage* blackImage;

	CALayer* dlgLayer;
	CALayer* animLayer;
	CALayer* msgLayer;
	CALayer* glowLayer;
	UIActivityIndicatorView* spinner;
}

@property (nonatomic, retain) CALayer* dlgLayer;
@property (nonatomic, retain) CALayer* animLayer;
@property (nonatomic, retain) CALayer* msgLayer;
@property (nonatomic, retain) CALayer* glowLayer;
@property (nonatomic, retain) UIActivityIndicatorView* spinner;

-(void) IdleSelector: (id) SelData;
-(void) PlayAnim: (id) Data;
-(void) ShowOutput: (id) StringValue;
-(void) UpdateBoardImage;
-(void) ShowDlg:(int)DlgType withParam:(int)Param withText:(const char*)Text;
-(void) DisplayDlg: (NSValue*) Param;
-(void) FadeDlg;

@end
