#import <QuartzCore/QuartzCore.h>
#import "bgBoardData.h"
#import "bgBoard.h"
#import "bgDlg.h"

extern int fClockwise;
float Player1Color[4] = { 0.9, 0.9, 0.9, 1.0 };
float Player2Color[4] = { 0.15, 0.15, 0.15, 1.0 };

bgColorEntry gCheckerColors[] =
{
	{ "Black", { 0.15, 0.15, 0.15, 1.0 } },
	{ "White", { 0.9, 0.9, 0.9, 1.0 } },
	{ "Red", { 0.8, 0.0, 0.0, 1.0 } },
	{ "Brown", { 0.5, 0.0, 0.0, 1.0 } },
	{ "Yellow", { 1.0, 1.0, 0.5, 1.0 } },
};

int gNumCheckerColors = sizeof(gCheckerColors) / sizeof(gCheckerColors[0]);

bgBoardSize gBoardSize;
bgBoardSize gBoardSizeScaled;
float gBoardScale;

void bgBoardUpdateSize(bgBoardSize* BoardSize, float Width, float Height)
{
	float ScaleX = Width / 480;
	float ScaleY = Height / 320;

	float BorderWidth = 6 * ScaleX;
	float BorderTopHeight = 5 * ScaleY;
	float BorderBottomHeight = 5 * ScaleY;
	float PointWidth = 33 * ScaleX;
	float PointHeight = 120 * ScaleY;
	float BarWidth = 33 * ScaleX;
	float BarOffset = 50 * ScaleX;
	float BearoffX = (2 * BorderWidth + BarWidth + 12 * PointWidth);
	float ChequerHeight = 28 * ScaleX;
	float ChequerRadius = 14 * ScaleX;
	float DiceSize = 31 * ScaleX;

	if (ChequerHeight * 5 > 140 * ScaleY)
	{
		ChequerHeight = 140 * ScaleY / 5;
		ChequerRadius = ChequerHeight / 2;
	}
	
	CGRect PointArea[2][28] =
	{
		{
			CGRectMake(BorderWidth +  6 * PointWidth + BarWidth / 2 - PointWidth / 2, Height - BarOffset, PointWidth, 3 * ChequerHeight),
			CGRectMake(BorderWidth + 11 * PointWidth + BarWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth + 10 * PointWidth + BarWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth +  9 * PointWidth + BarWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth +  8 * PointWidth + BarWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth +  7 * PointWidth + BarWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth +  6 * PointWidth + BarWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth +  5 * PointWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth +  4 * PointWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth +  3 * PointWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth +  2 * PointWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth +  1 * PointWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth +  0 * PointWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth +  0 * PointWidth, BorderBottomHeight + 5 * ChequerHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth +  1 * PointWidth, BorderBottomHeight + 5 * ChequerHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth +  2 * PointWidth, BorderBottomHeight + 5 * ChequerHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth +  3 * PointWidth, BorderBottomHeight + 5 * ChequerHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth +  4 * PointWidth, BorderBottomHeight + 5 * ChequerHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth +  5 * PointWidth, BorderBottomHeight + 5 * ChequerHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth +  6 * PointWidth + BarWidth, BorderBottomHeight + 5 * ChequerHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth +  7 * PointWidth + BarWidth, BorderBottomHeight + 5 * ChequerHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth +  8 * PointWidth + BarWidth, BorderBottomHeight + 5 * ChequerHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth +  9 * PointWidth + BarWidth, BorderBottomHeight + 5 * ChequerHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth + 10 * PointWidth + BarWidth, BorderBottomHeight + 5 * ChequerHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth + 11 * PointWidth + BarWidth, BorderBottomHeight + 5 * ChequerHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth + 6 * PointWidth + BarWidth / 2 - PointWidth / 2, BarOffset + 3 * ChequerHeight, PointWidth, 3 * ChequerHeight),
			CGRectMake(Width - BorderWidth - PointWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(Width - BorderWidth - PointWidth, BorderBottomHeight + PointHeight, PointWidth, 5 * ChequerHeight),
		},
		{
			CGRectMake(PointWidth + 2 * BorderWidth +  6 * PointWidth + BarWidth / 2 - PointWidth / 2, Height - BarOffset, PointWidth, 3 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth +  0 * PointWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth +  1 * PointWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth +  2 * PointWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth +  3 * PointWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth +  4 * PointWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth +  5 * PointWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth +  6 * PointWidth + BarWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth +  7 * PointWidth + BarWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth +  8 * PointWidth + BarWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth +  9 * PointWidth + BarWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth + 10 * PointWidth + BarWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth + 11 * PointWidth + BarWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth + 11 * PointWidth + BarWidth, BorderBottomHeight + 5 * ChequerHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth + 10 * PointWidth + BarWidth, BorderBottomHeight + 5 * ChequerHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth +  9 * PointWidth + BarWidth, BorderBottomHeight + 5 * ChequerHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth +  8 * PointWidth + BarWidth, BorderBottomHeight + 5 * ChequerHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth +  7 * PointWidth + BarWidth, BorderBottomHeight + 5 * ChequerHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth +  6 * PointWidth + BarWidth, BorderBottomHeight + 5 * ChequerHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth +  5 * PointWidth, BorderBottomHeight + 5 * ChequerHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth +  4 * PointWidth, BorderBottomHeight + 5 * ChequerHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth +  3 * PointWidth, BorderBottomHeight + 5 * ChequerHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth +  2 * PointWidth, BorderBottomHeight + 5 * ChequerHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth +  1 * PointWidth, BorderBottomHeight + 5 * ChequerHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth +  0 * PointWidth, BorderBottomHeight + 5 * ChequerHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(PointWidth + 2 * BorderWidth + 6 * PointWidth + BarWidth / 2 - PointWidth / 2, BarOffset + 3 * ChequerHeight, PointWidth, 3 * ChequerHeight),
			CGRectMake(BorderWidth, Height - BorderTopHeight, PointWidth, 5 * ChequerHeight),
			CGRectMake(BorderWidth, BorderBottomHeight + PointHeight, PointWidth, 5 * ChequerHeight),
		}
	};

	memcpy(BoardSize->PointArea, PointArea, sizeof(BoardSize->PointArea));

	BoardSize->Width = Width;
	BoardSize->Height = Height;
	BoardSize->BorderWidth = BorderWidth;
	BoardSize->BorderTopHeight = BorderTopHeight;
	BoardSize->BorderBottomHeight = BorderBottomHeight;
	BoardSize->PointWidth = PointWidth;
	BoardSize->PointHeight = PointHeight;
	BoardSize->BarWidth = BarWidth;
	BoardSize->BarOffset = BarOffset;
	BoardSize->BearoffX = BearoffX;
	BoardSize->ChequerHeight = ChequerHeight;
	BoardSize->ChequerRadius = ChequerRadius;
	BoardSize->DiceSize = DiceSize;
}

void CGContextAddRoundedRect(CGContextRef c, CGRect rect, int corner_radius)
{
	int x_left = rect.origin.x;
	int x_left_center = rect.origin.x + corner_radius;
	int x_right_center = rect.origin.x + rect.size.width - corner_radius;
	int x_right = rect.origin.x + rect.size.width;
	int y_top = rect.origin.y;
	int y_top_center = rect.origin.y + corner_radius;
	int y_bottom_center = rect.origin.y + rect.size.height - corner_radius;
	int y_bottom = rect.origin.y + rect.size.height;
	
	CGContextBeginPath(c);
	CGContextMoveToPoint(c, x_left, y_top_center);
	
	CGContextAddArcToPoint(c, x_left, y_top, x_left_center, y_top, corner_radius);
	CGContextAddLineToPoint(c, x_right_center, y_top);
	CGContextAddArcToPoint(c, x_right, y_top, x_right, y_top_center, corner_radius);
	CGContextAddLineToPoint(c, x_right, y_bottom_center);
	CGContextAddArcToPoint(c, x_right, y_bottom, x_right_center, y_bottom, corner_radius);
	CGContextAddLineToPoint(c, x_left_center, y_bottom);
	CGContextAddArcToPoint(c, x_left, y_bottom, x_left, y_bottom_center, corner_radius);
	CGContextAddLineToPoint(c, x_left, y_top_center);
	
	CGContextClosePath(c);
}

void CGContextShowTextAtPointCentered(CGContextRef cgContext, CGFloat x, CGFloat y, const char* string, size_t length)
{
	CGContextSetTextDrawingMode(cgContext, kCGTextInvisible);
	CGContextShowTextAtPoint(cgContext, x, y, string, length);
	CGPoint sz = CGContextGetTextPosition(cgContext);
	CGContextSetTextDrawingMode(cgContext, kCGTextFill);
	CGContextShowTextAtPoint(cgContext, x - (sz.x - x) / 2, y, string, length);
}

void bgDrawBoard(bgBoardSize* BoardSize, CGContextRef cgContext)
{
	float Width = BoardSize->Width;
	float Height = BoardSize->Height;
	float BorderWidth = BoardSize->BorderWidth;
	float BorderTopHeight = BoardSize->BorderTopHeight;
	float BorderBottomHeight = BoardSize->BorderBottomHeight;
	float PointWidth = BoardSize->PointWidth;
	float PointHeight = BoardSize->PointHeight;
	float BarWidth = BoardSize->BarWidth;
	float ChequerHeight = BoardSize->ChequerHeight;
	
	CGContextSetRGBStrokeColor(cgContext, 0, 0, 0, 1);
	CGContextSetAllowsAntialiasing(cgContext, TRUE);
	CGContextSetShouldAntialias(cgContext, TRUE);

	CGContextSetRGBFillColor(cgContext, 0.5, 0.25, 0.0, 1.0);
	CGContextFillRect(cgContext, CGRectMake(0, 0, Width, Height));

	CGContextBeginPath(cgContext);
	CGContextMoveToPoint(cgContext, BoardSize->PointArea[fClockwise][26].origin.x, BoardSize->PointArea[fClockwise][26].origin.y);
	CGContextAddLineToPoint(cgContext, BoardSize->PointArea[fClockwise][26].origin.x + PointWidth, BoardSize->PointArea[fClockwise][26].origin.y);
	CGContextAddLineToPoint(cgContext, BoardSize->PointArea[fClockwise][26].origin.x + PointWidth, BoardSize->PointArea[fClockwise][26].origin.y - PointHeight);
	CGContextAddLineToPoint(cgContext, BoardSize->PointArea[fClockwise][26].origin.x, BoardSize->PointArea[fClockwise][26].origin.y - PointHeight);
	CGContextClosePath(cgContext);
	CGContextDrawPath(cgContext, kCGPathStroke);

	CGContextBeginPath(cgContext);
	CGContextMoveToPoint(cgContext, BoardSize->PointArea[fClockwise][27].origin.x, BoardSize->PointArea[fClockwise][27].origin.y);
	CGContextAddLineToPoint(cgContext, BoardSize->PointArea[fClockwise][27].origin.x + PointWidth, BoardSize->PointArea[fClockwise][27].origin.y);
	CGContextAddLineToPoint(cgContext, BoardSize->PointArea[fClockwise][27].origin.x + PointWidth, BoardSize->PointArea[fClockwise][27].origin.y - PointHeight);
	CGContextAddLineToPoint(cgContext, BoardSize->PointArea[fClockwise][27].origin.x, BoardSize->PointArea[fClockwise][27].origin.y - PointHeight);
	CGContextClosePath(cgContext);
	CGContextDrawPath(cgContext, kCGPathStroke);
	
	CGContextSetRGBFillColor(cgContext, 0.0, 0.5, 0.0, 1.0);

	int Offset = fClockwise ? PointWidth + BorderWidth : 0;

	CGContextBeginPath(cgContext);
	CGContextMoveToPoint(cgContext, Offset + BorderWidth, BorderBottomHeight);
	CGContextAddLineToPoint(cgContext, Offset + BorderWidth + 6 * PointWidth, BorderBottomHeight);
	CGContextAddLineToPoint(cgContext, Offset + BorderWidth + 6 * PointWidth, Height - BorderTopHeight);
	CGContextAddLineToPoint(cgContext, Offset + BorderWidth, Height - BorderTopHeight);
	CGContextClosePath(cgContext);
	CGContextDrawPath(cgContext, kCGPathFillStroke);
	
	CGContextBeginPath(cgContext);
	CGContextMoveToPoint(cgContext, Offset + BorderWidth + BarWidth + 6 * PointWidth, BorderBottomHeight);
	CGContextAddLineToPoint(cgContext, Offset + BorderWidth + BarWidth + 6 * PointWidth + 6 * PointWidth, BorderBottomHeight);
	CGContextAddLineToPoint(cgContext, Offset + BorderWidth + BarWidth + 6 * PointWidth + 6 * PointWidth, Height - BorderTopHeight);
	CGContextAddLineToPoint(cgContext, Offset + BorderWidth + BarWidth + 6 * PointWidth, Height - BorderTopHeight);
	CGContextClosePath(cgContext);
	CGContextDrawPath(cgContext, kCGPathFillStroke);
	
	for (int i = 0; i < 24; i++)
	{
		CGPoint pt = BoardSize->PointArea[fClockwise][i+1].origin;
		float dy;

		if (i > 11)
		{
			pt.y -= 5 * ChequerHeight;
			dy = PointHeight;
		}
		else
			dy = -PointHeight;

		CGContextBeginPath(cgContext);
		CGContextMoveToPoint(cgContext, pt.x, pt.y);
		CGContextAddLineToPoint(cgContext, pt.x + PointWidth/2, pt.y + dy);
		CGContextAddLineToPoint(cgContext, pt.x + PointWidth, pt.y);
		CGContextClosePath(cgContext);
		if (i % 2)
			CGContextSetRGBFillColor(cgContext, 1.0, 0.75, 0.25, 1.0);
		else
			CGContextSetRGBFillColor(cgContext, 0.75, 0.25, 0.0, 1.0);
		CGContextDrawPath(cgContext, kCGPathFillStroke);
	}

#ifndef PBG_HD
	CGPoint pt = CGPointMake(BorderWidth + PointWidth / 2, Height / 2);
	CGRect rect;
	if (!fClockwise)
		pt.x += BorderWidth + BarWidth + 12 * PointWidth;
	rect.origin = CGPointMake(pt.x - PointWidth / 2, pt.y - 10 * gBoardScale);
	rect.size = CGSizeMake(PointWidth, 20 * gBoardScale);
	
	CGContextAddRoundedRect(cgContext, rect, 4 * gBoardScale);
	CGContextSetRGBFillColor(cgContext, 1.0, 1.0, 1.0, 1.0);
	CGContextSetRGBStrokeColor(cgContext, 0.0, 0.0, 0.0, 1);
	CGContextDrawPath(cgContext, kCGPathStroke);
	
	CGContextSelectFont(cgContext, "Helvetica", 10 * gBoardScale, kCGEncodingMacRoman);
	CGContextSetTextMatrix(cgContext, CGAffineTransformMake(1.0,0.0, 0.0, -1.0, 0.0, 0.0));
	CGContextSetRGBFillColor(cgContext, 0.0, 0.0, 0.0, 1.0);
	
	const char* Text = "Menu";
	CGContextShowTextAtPointCentered(cgContext, pt.x, pt.y + 4 * gBoardScale, Text, strlen(Text));
#endif
}

void bgDrawChequers(bgBoardSize* BoardSize, CGContextRef cgContext, BoardData* bd, CGImageRef whiteImage, CGImageRef blackImage)
{
	float PointWidth = BoardSize->PointWidth;
	float PointHeight = BoardSize->PointHeight;
	float ChequerHeight = BoardSize->ChequerHeight;
	float ChequerRadius = BoardSize->ChequerRadius;
	
	// Draw chequers.
	for (int i = 0; i < 26; i++)
	{
		int Count = bd->points[i];

		if (!Count)
			continue;

		CGImage* chequerImage;
		if (Count < 0)
			chequerImage = whiteImage;
		else
			chequerImage = blackImage;
		
		Count = ABS(Count);

		CGPoint pt = BoardSize->PointArea[fClockwise][i].origin;
		pt.x += PointWidth / 2;

		int MaxStack = (i == 0 || i == 25) ? 3 : 5;
		float dy;

		if (i < 13)
		{
			dy = -1;
			pt.y -= ChequerHeight / 2;
		}
		else
		{
			dy = 1;
			pt.y -= (MaxStack - 1) * ChequerHeight + ChequerHeight / 2;
		}

		for (int j = 0; j < MIN(Count, MaxStack); j++)
		{
			CGContextDrawImage(cgContext, CGRectMake(pt.x - (ChequerRadius + 2), pt.y - (ChequerRadius + 2), 2 * (ChequerRadius + 2), 2 * (ChequerRadius + 2)), chequerImage);
			pt.y += dy * ChequerHeight;
		}
		
		if (Count > MaxStack)
		{
			pt.y -= dy * ChequerHeight * MaxStack + 3;
			
			char Text[8];
			sprintf(Text, "%d", Count);

			float* DiceColor;
			if (bd->points[i] > 0)
				DiceColor = Player2Color;
			else
				DiceColor = Player1Color;
			
			if ((DiceColor[0] + DiceColor[1] + DiceColor[2]) / 3 < 0.5f)
				CGContextSetRGBFillColor(cgContext, 1.0, 1.0, 1.0, 1.0);
			else
				CGContextSetRGBFillColor(cgContext, 0.0, 0.0, 0.0, 1.0);

			CGContextSelectFont(cgContext, "Helvetica", 28, kCGEncodingMacRoman);
			CGContextSetTextMatrix(cgContext, CGAffineTransformMake(1.0,0.0, 0.0, -1.0, 0.0, 0.0));
			
			CGContextShowTextAtPointCentered(cgContext, pt.x, pt.y + 12, Text, strlen(Text));
		}
	}

	if (bd->points[26])
	{
		int Count = ABS(bd->points[26]);
		
		CGContextSetRGBFillColor(cgContext, Player2Color[0], Player2Color[1], Player2Color[2], Player2Color[3]);
		CGPoint pt = BoardSize->PointArea[fClockwise][26].origin;

		int dy = PointHeight / 15;
		for (int i = 0; i < Count; i++)
		{
			CGContextBeginPath(cgContext);
			CGContextAddRect(cgContext, CGRectMake(pt.x, pt.y - (i + 1) * dy, PointWidth, dy));
			CGContextDrawPath(cgContext, kCGPathFillStroke);
		}
	}

	if (bd->points[27])
	{
		int Count = ABS(bd->points[27]);
		
		CGContextSetRGBFillColor(cgContext, Player1Color[0], Player1Color[1], Player1Color[2], Player1Color[3]);
		CGPoint pt = BoardSize->PointArea[fClockwise][27].origin;
		pt.y -= PointHeight;
		
		int dy = PointHeight / 15;
		for (int i = 0; i < Count; i++)
		{
			CGContextBeginPath(cgContext);
			CGContextAddRect(cgContext, CGRectMake(pt.x, pt.y + i* dy, PointWidth, dy));
			CGContextDrawPath(cgContext, kCGPathFillStroke);
		}
	}
}

void bgDrawMark(bgBoardSize* BoardSize, CGContextRef cgContext, int Index)
{
	float Height = BoardSize->Height;
	float BorderTopHeight = BoardSize->BorderTopHeight;
	float BorderBottomHeight = BoardSize->BorderBottomHeight;
	float PointWidth = BoardSize->PointWidth;

	int dx = PointWidth / 4;
#if PBG_HD
	int dy = (Index < 13 || Index == 26) ? 10 : -10;
#else
	int dy = (Index < 13 || Index == 26) ? BorderTopHeight : -BorderTopHeight;
#endif
	
	CGPoint pt;
	pt.x = BoardSize->PointArea[fClockwise][Index].origin.x + PointWidth / 2;
	pt.y = (Index > 12 && Index != 26) ? BorderBottomHeight : Height - BorderTopHeight;

	CGContextBeginPath(cgContext);
	CGContextMoveToPoint(cgContext, pt.x, pt.y);
	CGContextAddLineToPoint(cgContext, pt.x + dx, pt.y + dy);
	CGContextAddLineToPoint(cgContext, pt.x - dx, pt.y + dy);
	CGContextClosePath(cgContext);
	CGContextDrawPath(cgContext, kCGPathFill);
}

int bgBoardPoint(bgBoardSize* BoardSize, int x, int y)
{
	CGPoint pt = CGPointMake(x, y);

	for (int i = 0; i < 28; i++)
	{
		CGRect Rect = BoardSize->PointArea[fClockwise][i];
		Rect.origin.y -= CGRectGetHeight(Rect);
		if (CGRectContainsPoint(Rect, pt))
			return i;
	}

	return -1;
}

int bgBoardClick(bgBoardSize* BoardSize, int x, int y, BoardData* bd)
{
	float Height = BoardSize->Height;
	float BorderWidth = BoardSize->BorderWidth;
	float BorderTopHeight = BoardSize->BorderTopHeight;
	float BorderBottomHeight = BoardSize->BorderBottomHeight;
	float PointWidth = BoardSize->PointWidth;
	float PointHeight = BoardSize->PointHeight;
	float BarWidth = BoardSize->BarWidth;
	float BearoffX = BoardSize->BearoffX;
	float ChequerHeight = BoardSize->ChequerHeight;
	float DiceSize = BoardSize->DiceSize;

	CGPoint ClickPos = CGPointMake(x, y);

	CGRect MenuRect[2] =
	{
		CGRectMake(BearoffX, BorderBottomHeight + PointHeight, PointWidth, Height - BorderTopHeight - BorderBottomHeight - 2 * PointHeight),
		CGRectMake(BorderWidth, BorderBottomHeight + PointHeight, PointWidth, Height - BorderTopHeight - BorderBottomHeight - 2 * PointHeight)
	};
		
	if (CGRectContainsPoint(MenuRect[fClockwise], ClickPos))
		return BG_CMD_MENU;

	int Offset = fClockwise ? BorderWidth + PointWidth : 0;

	if (!bd->crawford_game && bd->cube_use)
	{
		CGPoint pt;

		if (bd->cube_owner > 0)
			pt.y = BorderBottomHeight;
		else if (bd->cube_owner < 0)
			pt.y = Height - BorderTopHeight - DiceSize;
		else
			pt.y = (Height - DiceSize) / 2;
		
		pt.x = BorderWidth + 6 * PointWidth + (BarWidth - DiceSize) / 2;
		pt.x += Offset;
		
		float size = DiceSize;
		
		// Increase the touch area to make it easier to tap the dice.
		if (bd->diceShown == DICE_BELOW_BOARD || bd->diceShown == DICE_NOT_SHOWN)
		{
			pt.x -= DiceSize / 4;
			pt.y -= DiceSize / 4;
			size += DiceSize / 2;
		}
		
		if (x > pt.x && x < pt.x + size && y < pt.y + size && y > pt.y)
			return BG_CMD_DOUBLE;
	}

	CGRect BoardRect[2][2] =
	{
		{
			CGRectMake(BorderWidth, BorderBottomHeight, 6 * PointWidth, Height - BorderTopHeight - BorderBottomHeight),
			CGRectMake(BorderWidth + 6 * PointWidth + BarWidth, BorderBottomHeight, 6 * PointWidth, Height - BorderTopHeight - BorderBottomHeight),
		},
		{
			CGRectMake(BorderWidth + PointWidth + BorderWidth, BorderBottomHeight, 6 * PointWidth, Height - BorderTopHeight - BorderBottomHeight),
			CGRectMake(BorderWidth + 6 * PointWidth + BarWidth + PointWidth + BorderWidth, BorderBottomHeight, 6 * PointWidth, Height - BorderTopHeight - BorderBottomHeight),
		}
	};

	if (bd->diceShown == DICE_BELOW_BOARD || bd->diceShown == DICE_NOT_SHOWN)
	{
		if (bd->turn == 1 && CGRectContainsPoint(BoardRect[fClockwise][1], ClickPos))
			return BG_CMD_DICE;

		if (bd->turn == -1 && CGRectContainsPoint(BoardRect[fClockwise][0], ClickPos))
			return BG_CMD_DICE;
	}

	CGRect SideRect[2][2] =
	{
#if PBG_HD
		{
			CGRectMake(BorderWidth, BorderBottomHeight + PointHeight, 6 * PointWidth, BOARD_HEIGHT - BorderTopHeight - BorderBottomHeight - 2 * PointHeight),
			CGRectMake(BorderWidth + 6 * PointWidth + BarWidth, BorderBottomHeight + PointHeight, 6 * PointWidth, Height - BorderTopHeight - BorderBottomHeight - 2 * PointHeight),
		},
		{
			CGRectMake(BorderWidth + PointWidth + BorderWidth, BorderBottomHeight + PointHeight, 6 * PointWidth, Height - BorderTopHeight - BorderBottomHeight - 2 * PointHeight),
			CGRectMake(BorderWidth + 6 * PointWidth + BarWidth + PointWidth + BorderWidth, BorderBottomHeight + PointHeight, 6 * PointWidth, Height - BorderTopHeight - BorderBottomHeight - 2 * PointHeight),
		}
#else
		{
			CGRectMake(BorderWidth, BorderBottomHeight + 4 * ChequerHeight + ChequerHeight / 2, 6 * PointWidth, Height - BorderTopHeight - 9 * ChequerHeight),
			CGRectMake(BorderWidth + 6 * PointWidth + BarWidth, BorderBottomHeight + 4 * ChequerHeight + ChequerHeight / 2, 6 * PointWidth, Height - BorderTopHeight - 9 * ChequerHeight),
		},
		{
			CGRectMake(BorderWidth + PointWidth + BorderWidth, BorderBottomHeight + 4 * ChequerHeight + ChequerHeight / 2, 6 * PointWidth, Height - BorderTopHeight - 9 * ChequerHeight),
			CGRectMake(BorderWidth + 6 * PointWidth + BarWidth + PointWidth + BorderWidth, BorderBottomHeight + 4 * ChequerHeight + ChequerHeight / 2, 6 * PointWidth, Height - BorderTopHeight - 9 * ChequerHeight),
		}
#endif
	};

	if (bd->turn == 1 && CGRectContainsPoint(SideRect[fClockwise][1], ClickPos))
		return BG_CMD_DICE;
	
	if (bd->turn == -1 && CGRectContainsPoint(SideRect[fClockwise][0], ClickPos))
		return BG_CMD_DICE;

	if (bd->turn == 1 && CGRectContainsPoint(SideRect[fClockwise][0], ClickPos))
		return BG_CMD_UNDO_OR_HINT;
	
	if (bd->turn == -1 && CGRectContainsPoint(SideRect[fClockwise][1], ClickPos))
		return BG_CMD_UNDO_OR_HINT;
	
	return -1;
}

CGPoint bgBoardPointPos(bgBoardSize* BoardSize, int Index, int Count)
{
	float PointWidth = BoardSize->PointWidth;
	float ChequerHeight = BoardSize->ChequerHeight;

	CGPoint pt = BoardSize->PointArea[fClockwise][Index].origin;
	pt.x += PointWidth / 2;
	if (Index > 12)
		pt.y -= CGRectGetHeight(BoardSize->PointArea[fClockwise][Index]);

	if (Index > 26)
	{
		if (Index == 27)
			pt.y += ChequerHeight / 15 * Count + ChequerHeight / 2;
		else
			pt.y -= ChequerHeight / 15 * Count + ChequerHeight / 2;
	}
	else
	{
		if (Index > 12)
			pt.y += ChequerHeight * Count + ChequerHeight / 2;
		else
			pt.y -= ChequerHeight * Count + ChequerHeight / 2;
	}

	return pt;
}

void bgBoardUpdateTrack(bgBoardSize* BoardSize, CALayer* GlowLayer, int Tracking, BoardData* bd)
{
	float Height = BoardSize->Height;
	float BorderWidth = BoardSize->BorderWidth;
	float BorderTopHeight = BoardSize->BorderTopHeight;
	float BorderBottomHeight = BoardSize->BorderBottomHeight;
	float PointWidth = BoardSize->PointWidth;
	float BarWidth = BoardSize->BarWidth;
	float DiceSize = BoardSize->DiceSize;

	if (Tracking == -1)
	{
		GlowLayer.hidden = YES;
		GlowLayer.contents = nil;
		return;
	}

	if (Tracking == BG_CMD_DOUBLE)
	{
		CGPoint pt;
		
		if (bd->cube_owner > 0)
			pt.y = BorderBottomHeight;
		else if (bd->cube_owner < 0)
			pt.y = Height - BorderTopHeight - DiceSize;
		else
			pt.y = (Height - DiceSize) / 2;
		
		int Offset = fClockwise ? BorderWidth + PointWidth : 0;

		pt.x = BorderWidth + 6 * PointWidth + (BarWidth - DiceSize) / 2;
		pt.x += Offset;

		int w = DiceSize + 4;
		int h = DiceSize + 4;

		pt.x += w / 2 - 2;
		pt.y += h / 2 - 2;

		CGColorSpaceRef colorSpace;
		colorSpace = CGColorSpaceCreateDeviceRGB();
		CGContextRef cgContext = CGBitmapContextCreate(NULL, w, h, 8, 4 * w, colorSpace, kCGImageAlphaPremultipliedFirst);
		CGColorSpaceRelease(colorSpace);

		CGContextSetAllowsAntialiasing(cgContext, TRUE);
		CGContextSetShouldAntialias(cgContext, TRUE);
		CGContextSetBlendMode(cgContext, kCGBlendModeCopy);
		CGContextSetRGBFillColor(cgContext, 1.0, 1.0, 1.0, 0.75);
//		CGContextFillRect(cgContext, CGRectMake(0, 0, w, h));
		CGContextAddRoundedRect(cgContext, CGRectMake(0, 0, w, h), 4);
		CGContextDrawPath(cgContext, kCGPathFill);
		CGContextSetRGBFillColor(cgContext, 0.0, 0.0, 0.0, 0.0);
//		CGContextFillRect(cgContext, CGRectMake(3, 3, w-6, h-6));
		CGContextAddRoundedRect(cgContext, CGRectMake(3, 3, w-6, h-6), 4);
		CGContextDrawPath(cgContext, kCGPathFill);
		
		CGImage* image = CGBitmapContextCreateImage(cgContext);
		CGContextRelease(cgContext);

		[CATransaction begin];
		[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
		GlowLayer.bounds = CGRectMake(0, 0, w, h);
		GlowLayer.position = pt;
		[CATransaction commit];
		[CATransaction flush];

		GlowLayer.contents = (id)image;
		[GlowLayer setHidden:NO];
	}
}
