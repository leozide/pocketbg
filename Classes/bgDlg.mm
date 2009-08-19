#import <QuartzCore/QuartzCore.h>
#import "bgDlg.h"
#import "bgBoard.h"

int bgActiveDlg;

struct bgDlgButton
{
	CGRect Rect;
	const char* Text;
	int ID;
	bool Disabled;
};

static CGRect bgDlgRect;
static const char* bgDlgText;
static bgDlgButton bgDlgButtons[8];
static int bgDlgNumButtons;
int bgDlgFade;

static void bgDlgAddButton(const CGRect& Rect, const char* Text, int ID)
{
	bgDlgButton& Button = bgDlgButtons[bgDlgNumButtons++];
	Button.Rect = Rect;
	Button.Text = Text;
	Button.ID = ID;
	Button.Disabled = false;
}

CGImage* bgDlgDraw(int Tracking)
{
	if (bgActiveDlg == BG_DLG_NONE)
		return nil;
	
	float Alpha = 0.95;
	int w = CGRectGetWidth(bgDlgRect) + 2;
	int h = CGRectGetHeight(bgDlgRect) + 2;

	CGColorSpaceRef colorSpace;
	colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef cgContext = CGBitmapContextCreate(NULL, w, h, 8, 4 * w, colorSpace, kCGImageAlphaPremultipliedFirst);
	CGColorSpaceRelease(colorSpace);
	
	CGContextSetAllowsAntialiasing(cgContext, TRUE);
	CGContextSetShouldAntialias(cgContext, TRUE);
	
	CGContextSetRGBFillColor(cgContext, 0.0, 0.0, 0.0, Alpha);
	CGContextSetRGBStrokeColor(cgContext, 0.75, 0.75, 0.75, Alpha);

	CGRect Rect = bgDlgRect;
	Rect.origin.x -= bgDlgRect.origin.x - 1;
	Rect.origin.y -= bgDlgRect.origin.y - 1;

	CGContextAddRoundedRect(cgContext, Rect, 4);
	CGContextDrawPath(cgContext, kCGPathFillStroke);
	
	CGContextSelectFont(cgContext, "Helvetica-Bold", 15, kCGEncodingMacRoman);

	if (bgDlgText[0])
	{
		const char* Text = bgDlgText;
		CGPoint pt;
		pt.x = CGRectGetWidth(bgDlgRect) / 2;
		pt.y = h - 24;
		CGContextSetRGBFillColor(cgContext, 1.0, 1.0, 1.0, Alpha);
		CGContextShowTextAtPointCentered(cgContext, pt.x, pt.y, Text, strlen(Text));
	}
	
	for (int i = 0; i < bgDlgNumButtons; i++)
	{
		CGRect Rect = bgDlgButtons[i].Rect;
		Rect.origin.x -= bgDlgRect.origin.x - 1;
		Rect.origin.y = h - (Rect.origin.y - bgDlgRect.origin.y) - CGRectGetHeight(Rect) + 1;

		CGContextSetRGBFillColor(cgContext, 1.0, 1.0, 1.0, Alpha);
		CGContextAddRoundedRect(cgContext, Rect, 10);

		if (bgDlgButtons[i].ID == Tracking)
			CGContextDrawPath(cgContext, kCGPathFillStroke);
		else
			CGContextDrawPath(cgContext, kCGPathStroke);

		if (bgDlgButtons[i].Disabled)
			CGContextSetRGBFillColor(cgContext, 0.5, 0.5, 0.5, Alpha);
		else
			CGContextSetRGBFillColor(cgContext, 1.0, 1.0, 1.0, Alpha);
		
		const char* Text = bgDlgButtons[i].Text;
		CGPoint pt = Rect.origin;
		pt.x += CGRectGetWidth(Rect) / 2;
		pt.y += 16;
		CGContextShowTextAtPointCentered(cgContext, pt.x, pt.y, Text, strlen(Text));
	}
	
	CGImage* image = CGBitmapContextCreateImage(cgContext);
	CGContextRelease(cgContext);
	
	return image;
}

void bgDlgShow(CALayer* DlgLayer, int DlgType, int Param, const char* Text)
{
	bgActiveDlg = DlgType;
	bgDlgNumButtons = 0;

	if (DlgType == BG_DLG_DOUBLE_ACCEPT)
	{
		bgDlgText = "Accept double?";

		if (Param)
		{
			bgDlgRect = CGRectMake(20, 110, 440, 100);

			bgDlgAddButton(CGRectMake(40, 153, 120, 44), "Take", BG_CMD_DOUBLE_TAKE);
			bgDlgAddButton(CGRectMake(180, 153, 120, 44), "Redouble", BG_CMD_DOUBLE_REDOUBLE);
			bgDlgAddButton(CGRectMake(320, 153, 120, 44), "Drop", BG_CMD_DOUBLE_DROP);
		}
		else
		{
			bgDlgRect = CGRectMake(90, 110, 300, 100);

			bgDlgAddButton(CGRectMake(110, 153, 120, 44), "Take", BG_CMD_DOUBLE_TAKE);
			bgDlgAddButton(CGRectMake(250, 153, 120, 44), "Drop", BG_CMD_DOUBLE_DROP);
		}
	}
	else if (DlgType == BG_DLG_ACCEPT_RESIGN)
	{
		const char* Text[] =
		{
			"Accept single game resignation?", 
			"Accept gammon resignation?", 
			"Accept backgammon resignation?" 
		};

		bgDlgRect = CGRectMake(90, 110, 300, 100);
		bgDlgText = Text[Param];

		bgDlgAddButton(CGRectMake(110, 153, 120, 44), "Accept", BG_CMD_ACCEPT_RESIGN_YES);
		bgDlgAddButton(CGRectMake(250, 153, 120, 44), "Reject", BG_CMD_ACCEPT_RESIGN_NO);
	}
	/*
	else if (bgActiveDlg == BG_DLG_GAME_MENU)
	{
		bgDlgRect = CGRectMake(120, 30, 240, 260);
		bgDlgText = "";
		
		bgDlgAddButton(CGRectMake(140, 50, 200, 40), "Main Menu", BG_CMD_GAME_MAIN);
		bgDlgAddButton(CGRectMake(140, 110, 200, 40), "Resume", BG_CMD_GAME_RESUME);
		bgDlgAddButton(CGRectMake(140, 170, 200, 40), "Resign", BG_CMD_GAME_RESIGN);
		bgDlgAddButton(CGRectMake(140, 230, 200, 40), "Undo", BG_CMD_GAME_UNDO);

		bgDlgButtons[3].Disabled = Param;
	}
	 */
	else if (bgActiveDlg == BG_DLG_RESIGN_TYPE)
	{
		bgDlgRect = CGRectMake(120, 30, 240, 260);
		bgDlgText = "";

		bgDlgAddButton(CGRectMake(140, 48, 200, 44), "Resign Single Game", BG_CMD_RESIGN_SINGLE);
		bgDlgAddButton(CGRectMake(140, 108, 200, 44), "Resign Gammon", BG_CMD_RESIGN_GAMMON);
		bgDlgAddButton(CGRectMake(140, 168, 200, 44), "Resign Backgammon", BG_CMD_RESIGN_BACKGAMMON);
		bgDlgAddButton(CGRectMake(140, 228, 200, 44), "Cancel", BG_CMD_RESIGN_CANCEL);
	}
	else if (bgActiveDlg == BG_DLG_MAIN_MENU)
	{
		bgDlgRect = CGRectMake(120, 0, 240, 320);
		bgDlgText = "";

		bgDlgAddButton(CGRectMake(140, 18, 200, 44), "New Match", BG_CMD_MAIN_NEW);
		bgDlgAddButton(CGRectMake(140, 78, 200, 44), "Resume", BG_CMD_MAIN_RESUME);
		bgDlgAddButton(CGRectMake(140, 138, 200, 44), "Resign", BG_CMD_GAME_RESIGN);
		bgDlgAddButton(CGRectMake(140, 198, 200, 44), "Settings", BG_CMD_MAIN_SETTINGS);
		bgDlgAddButton(CGRectMake(140, 258, 200, 44), "How to Play", BG_CMD_MAIN_ABOUT);

		bgDlgButtons[1].Disabled = (ms.gs != GAME_PLAYING);
		bgDlgButtons[2].Disabled = (ms.gs != GAME_PLAYING || ap[ms.fTurn].pt != PLAYER_HUMAN);
	}
	else if (bgActiveDlg == BG_DLG_CONFIRM_EXIT)
	{
		bgDlgText = "Discard the game in progress?";
		bgDlgRect = CGRectMake(90, 110, 300, 100);

		bgDlgAddButton(CGRectMake(110, 153, 120, 44), "Yes", BG_CMD_EXIT_MATCH_YES);
		bgDlgAddButton(CGRectMake(250, 153, 120, 44), "No", BG_CMD_EXIT_MATCH_NO);
	}
	else if (bgActiveDlg == BG_DLG_CONFIRM_DOUBLE)
	{
		bgDlgText = "Are you sure you want to double?";
		bgDlgRect = CGRectMake(90, 110, 300, 100);
		
		bgDlgAddButton(CGRectMake(110, 153, 120, 44), "Yes", BG_CMD_CONFIRM_DOUBLE_YES);
		bgDlgAddButton(CGRectMake(250, 153, 120, 44), "No", BG_CMD_CONFIRM_DOUBLE_NO);
	}
	else if (bgActiveDlg == BG_DLG_PROGRESS)
	{
		bgDlgText = Text;
		bgDlgRect = CGRectMake(90, 110, 300, 100);

//		bgDlgAddButton(CGRectMake(180, 155, 120, 40), "Cancel", BG_DLG_PROGRESS_CANCEL);
	}

	if (bgActiveDlg != BG_DLG_NONE)
	{
		CGImage* Image = bgDlgDraw(-1);

		int w = CGRectGetWidth(bgDlgRect);
		int h = CGRectGetHeight(bgDlgRect);

		[CATransaction begin];
		[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
		DlgLayer.position = CGPointMake(240, 160);
		DlgLayer.bounds = CGRectMake(0, 0, w/4, h/4);
		[CATransaction commit];
		[CATransaction flush];

		DlgLayer.bounds = CGRectMake(0, 0, w, h);
		DlgLayer.hidden = NO;
		DlgLayer.contents = (id)Image;
		DlgLayer.opacity = 1.0;
	}
	else
	{
		DlgLayer.hidden = YES;
		DlgLayer.contents = (id)nil;
		DlgLayer.opacity = 0.0;
	}
}

int bgDlgClick(CALayer* DlgLayer, int x, int y)
{
	CGPoint pt = CGPointMake(x, y);

	if (!CGRectContainsPoint(bgDlgRect, pt))
	{
		// Fade out dialog so the user can see the board.
//		if (bgActiveDlg != BG_DLG_MAIN_MENU && bgActiveDlg != BG_DLG_GAME_MENU)
//			bgDlgFade = !bgDlgFade;

		return -1;
	}

	for (int i = 0; i < bgDlgNumButtons; i++)
		if (CGRectContainsPoint(bgDlgButtons[i].Rect, pt))
			return bgDlgButtons[i].ID;

	return -1;
}

void bgDlgUpdateTrack(CALayer* DlgLayer, int Tracking)
{
	CGImage* Image = bgDlgDraw(Tracking);
	DlgLayer.contents = (id)Image;
}
