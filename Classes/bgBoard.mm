#import <QuartzCore/QuartzCore.h>
#import "bgBoardData.h"
#import "bgBoard.h"
#import "bgDlg.h"

extern int fClockwise;

static CGRect bgPointArea[2][28] =
{
	{
		CGRectMake(BORDER_WIDTH + 6 * POINT_WIDTH + BAR_WIDTH / 2 - POINT_WIDTH / 2, BOARD_HEIGHT - BAR_OFFSET, POINT_WIDTH, 3 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH + 11 * POINT_WIDTH + BAR_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH + 10 * POINT_WIDTH + BAR_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH +  9 * POINT_WIDTH + BAR_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH +  8 * POINT_WIDTH + BAR_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH +  7 * POINT_WIDTH + BAR_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH +  6 * POINT_WIDTH + BAR_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH +  5 * POINT_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH +  4 * POINT_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH +  3 * POINT_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH +  2 * POINT_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH +  1 * POINT_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH +  0 * POINT_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH +  0 * POINT_WIDTH, BORDER_HEIGHT + 5 * CHEQUER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH +  1 * POINT_WIDTH, BORDER_HEIGHT + 5 * CHEQUER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH +  2 * POINT_WIDTH, BORDER_HEIGHT + 5 * CHEQUER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH +  3 * POINT_WIDTH, BORDER_HEIGHT + 5 * CHEQUER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH +  4 * POINT_WIDTH, BORDER_HEIGHT + 5 * CHEQUER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH +  5 * POINT_WIDTH, BORDER_HEIGHT + 5 * CHEQUER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH +  6 * POINT_WIDTH + BAR_WIDTH, BORDER_HEIGHT + 5 * CHEQUER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH +  7 * POINT_WIDTH + BAR_WIDTH, BORDER_HEIGHT + 5 * CHEQUER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH +  8 * POINT_WIDTH + BAR_WIDTH, BORDER_HEIGHT + 5 * CHEQUER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH +  9 * POINT_WIDTH + BAR_WIDTH, BORDER_HEIGHT + 5 * CHEQUER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH + 10 * POINT_WIDTH + BAR_WIDTH, BORDER_HEIGHT + 5 * CHEQUER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH + 11 * POINT_WIDTH + BAR_WIDTH, BORDER_HEIGHT + 5 * CHEQUER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH + 6 * POINT_WIDTH + BAR_WIDTH / 2 - POINT_WIDTH / 2, BAR_OFFSET + 3 * CHEQUER_HEIGHT, POINT_WIDTH, 3 * CHEQUER_HEIGHT),
		CGRectMake(2 * BORDER_WIDTH + BAR_WIDTH + 12 * POINT_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(2 * BORDER_WIDTH + BAR_WIDTH + 12 * POINT_WIDTH, BORDER_HEIGHT + POINT_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
	},
	{
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH + 6 * POINT_WIDTH + BAR_WIDTH / 2 - POINT_WIDTH / 2, BOARD_HEIGHT - BAR_OFFSET, POINT_WIDTH, 3 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH +  0 * POINT_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH +  1 * POINT_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH +  2 * POINT_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH +  3 * POINT_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH +  4 * POINT_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH +  5 * POINT_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH +  6 * POINT_WIDTH + BAR_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH +  7 * POINT_WIDTH + BAR_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH +  8 * POINT_WIDTH + BAR_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH +  9 * POINT_WIDTH + BAR_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH + 10 * POINT_WIDTH + BAR_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH + 11 * POINT_WIDTH + BAR_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH + 11 * POINT_WIDTH + BAR_WIDTH, BORDER_HEIGHT + 5 * CHEQUER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH + 10 * POINT_WIDTH + BAR_WIDTH, BORDER_HEIGHT + 5 * CHEQUER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH +  9 * POINT_WIDTH + BAR_WIDTH, BORDER_HEIGHT + 5 * CHEQUER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH +  8 * POINT_WIDTH + BAR_WIDTH, BORDER_HEIGHT + 5 * CHEQUER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH +  7 * POINT_WIDTH + BAR_WIDTH, BORDER_HEIGHT + 5 * CHEQUER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH +  6 * POINT_WIDTH + BAR_WIDTH, BORDER_HEIGHT + 5 * CHEQUER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH +  5 * POINT_WIDTH, BORDER_HEIGHT + 5 * CHEQUER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH +  4 * POINT_WIDTH, BORDER_HEIGHT + 5 * CHEQUER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH +  3 * POINT_WIDTH, BORDER_HEIGHT + 5 * CHEQUER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH +  2 * POINT_WIDTH, BORDER_HEIGHT + 5 * CHEQUER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH +  1 * POINT_WIDTH, BORDER_HEIGHT + 5 * CHEQUER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH +  0 * POINT_WIDTH, BORDER_HEIGHT + 5 * CHEQUER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(POINT_WIDTH + 2 * BORDER_WIDTH + 6 * POINT_WIDTH + BAR_WIDTH / 2 - POINT_WIDTH / 2, BAR_OFFSET + 3 * CHEQUER_HEIGHT, POINT_WIDTH, 3 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
		CGRectMake(BORDER_WIDTH, BORDER_HEIGHT + POINT_HEIGHT, POINT_WIDTH, 5 * CHEQUER_HEIGHT),
	}
};

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

void bgDrawBoard(CGContextRef cgContext)
{
	CGContextSetRGBStrokeColor(cgContext, 0, 0, 0, 1);
	CGContextSetAllowsAntialiasing(cgContext, TRUE);
	CGContextSetShouldAntialias(cgContext, TRUE);

	CGContextSetRGBFillColor(cgContext, 0.5, 0.25, 0.0, 1.0);
	CGContextFillRect(cgContext, CGRectMake(0, 0, BOARD_WIDTH, BOARD_HEIGHT));

	CGContextBeginPath(cgContext);
	CGContextMoveToPoint(cgContext, bgPointArea[fClockwise][26].origin.x, bgPointArea[fClockwise][26].origin.y);
	CGContextAddLineToPoint(cgContext, bgPointArea[fClockwise][26].origin.x + POINT_WIDTH, bgPointArea[fClockwise][26].origin.y);
	CGContextAddLineToPoint(cgContext, bgPointArea[fClockwise][26].origin.x + POINT_WIDTH, bgPointArea[fClockwise][26].origin.y - POINT_HEIGHT);
	CGContextAddLineToPoint(cgContext, bgPointArea[fClockwise][26].origin.x, bgPointArea[fClockwise][26].origin.y - POINT_HEIGHT);
	CGContextClosePath(cgContext);
	CGContextDrawPath(cgContext, kCGPathStroke);

	CGContextBeginPath(cgContext);
	CGContextMoveToPoint(cgContext, bgPointArea[fClockwise][27].origin.x, bgPointArea[fClockwise][27].origin.y);
	CGContextAddLineToPoint(cgContext, bgPointArea[fClockwise][27].origin.x + POINT_WIDTH, bgPointArea[fClockwise][27].origin.y);
	CGContextAddLineToPoint(cgContext, bgPointArea[fClockwise][27].origin.x + POINT_WIDTH, bgPointArea[fClockwise][27].origin.y - POINT_HEIGHT);
	CGContextAddLineToPoint(cgContext, bgPointArea[fClockwise][27].origin.x, bgPointArea[fClockwise][27].origin.y - POINT_HEIGHT);
	CGContextClosePath(cgContext);
	CGContextDrawPath(cgContext, kCGPathStroke);
	
	CGContextSetRGBFillColor(cgContext, 0.0, 0.5, 0.0, 1.0);

	int Offset = fClockwise ? POINT_WIDTH + BORDER_WIDTH : 0;

	CGContextBeginPath(cgContext);
	CGContextMoveToPoint(cgContext, Offset + BORDER_WIDTH, BORDER_HEIGHT);
	CGContextAddLineToPoint(cgContext, Offset + BORDER_WIDTH + 6 * POINT_WIDTH, BORDER_HEIGHT);
	CGContextAddLineToPoint(cgContext, Offset + BORDER_WIDTH + 6 * POINT_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT);
	CGContextAddLineToPoint(cgContext, Offset + BORDER_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT);
	CGContextClosePath(cgContext);
	CGContextDrawPath(cgContext, kCGPathFillStroke);
	
	CGContextBeginPath(cgContext);
	CGContextMoveToPoint(cgContext, Offset + BORDER_WIDTH + BAR_WIDTH + 6 * POINT_WIDTH, BORDER_HEIGHT);
	CGContextAddLineToPoint(cgContext, Offset + BORDER_WIDTH + BAR_WIDTH + 6 * POINT_WIDTH + 6 * POINT_WIDTH, BORDER_HEIGHT);
	CGContextAddLineToPoint(cgContext, Offset + BORDER_WIDTH + BAR_WIDTH + 6 * POINT_WIDTH + 6 * POINT_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT);
	CGContextAddLineToPoint(cgContext, Offset + BORDER_WIDTH + BAR_WIDTH + 6 * POINT_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT);
	CGContextClosePath(cgContext);
	CGContextDrawPath(cgContext, kCGPathFillStroke);
	
	for (int i = 0; i < 24; i++)
	{
		CGPoint pt = bgPointArea[fClockwise][i+1].origin;
		float dy;

		if (i > 11)
		{
			pt.y -= 5 * CHEQUER_HEIGHT;
			dy = POINT_HEIGHT;
		}
		else
			dy = -POINT_HEIGHT;

		CGContextBeginPath(cgContext);
		CGContextMoveToPoint(cgContext, pt.x, pt.y);
		CGContextAddLineToPoint(cgContext, pt.x + POINT_WIDTH/2, pt.y + dy);
		CGContextAddLineToPoint(cgContext, pt.x + POINT_WIDTH, pt.y);
		CGContextClosePath(cgContext);
		if (i % 2)
			CGContextSetRGBFillColor(cgContext, 1.0, 0.75, 0.25, 1.0);
		else
			CGContextSetRGBFillColor(cgContext, 0.75, 0.25, 0.0, 1.0);
		CGContextDrawPath(cgContext, kCGPathFillStroke);
	}

	CGPoint pt = CGPointMake(BORDER_WIDTH + POINT_WIDTH / 2, BOARD_HEIGHT / 2);
	CGRect rect;
	if (!fClockwise)
		pt.x += BORDER_WIDTH + BAR_WIDTH + 12 * POINT_WIDTH;
	rect.origin = CGPointMake(pt.x - POINT_WIDTH/2, pt.y-10);
	rect.size = CGSizeMake(POINT_WIDTH, 20);
	
	CGContextAddRoundedRect(cgContext, rect, 4);
	CGContextSetRGBFillColor(cgContext, 1.0, 1.0, 1.0, 1.0);
	CGContextSetRGBStrokeColor(cgContext, 0.0, 0.0, 0.0, 1);
	CGContextDrawPath(cgContext, kCGPathStroke);
	
	CGContextSelectFont(cgContext, "Helvetica", 10, kCGEncodingMacRoman);
	CGContextSetTextMatrix(cgContext, CGAffineTransformMake(1.0,0.0, 0.0, -1.0, 0.0, 0.0));
	CGContextSetRGBFillColor(cgContext, 0.0, 0.0, 0.0, 1.0);
	
	const char* Text = "Menu";
	CGContextShowTextAtPointCentered(cgContext, pt.x, pt.y + 4, Text, strlen(Text));
}

void bgDrawChequers(CGContextRef cgContext, BoardData* bd, CGImage* whiteImage, CGImage* blackImage)
{
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

		CGPoint pt = bgPointArea[fClockwise][i].origin;
		pt.x += POINT_WIDTH / 2;

		int MaxStack = (i == 0 || i == 25) ? 3 : 5;
		float dy;

		if (i < 13)
		{
			dy = -1;
			pt.y -= CHEQUER_HEIGHT / 2;
		}
		else
		{
			dy = 1;
			pt.y -= (MaxStack - 1) * CHEQUER_HEIGHT + CHEQUER_HEIGHT / 2;
		}

		for (int j = 0; j < MIN(Count, MaxStack); j++)
		{
			CGContextDrawImage(cgContext, CGRectMake(pt.x - (CHEQUER_RADIUS + 2), pt.y - (CHEQUER_RADIUS + 2), 2 * (CHEQUER_RADIUS + 2), 2 * (CHEQUER_RADIUS + 2)), chequerImage);
			pt.y += dy * CHEQUER_HEIGHT;
		}
		
		if (Count > MaxStack)
		{
			pt.y -= dy * CHEQUER_HEIGHT * MaxStack + 3;
			
			char Text[8];
			sprintf(Text, "%d", Count);

			if (bd->points[i] > 0)
				CGContextSetRGBFillColor(cgContext, 0.9, 0.9, 0.9, 1.0);
			else
				CGContextSetRGBFillColor(cgContext, 0.15, 0.15, 0.15, 1.0);
			
			CGContextSelectFont(cgContext, "Helvetica", 28, kCGEncodingMacRoman);
			CGContextSetTextMatrix(cgContext, CGAffineTransformMake(1.0,0.0, 0.0, -1.0, 0.0, 0.0));
			
			CGContextShowTextAtPointCentered(cgContext, pt.x, pt.y + 12, Text, strlen(Text));
		}
	}

	if (bd->points[26])
	{
		int Count = ABS(bd->points[26]);
		
		CGContextSetRGBFillColor(cgContext, 0.15, 0.15, 0.15, 1.0);
		CGPoint pt = bgPointArea[fClockwise][26].origin;

		int dy = POINT_HEIGHT / 15;
		for (int i = 0; i < Count; i++)
		{
			CGContextBeginPath(cgContext);
			CGContextAddRect(cgContext, CGRectMake(pt.x, pt.y - (i + 1) * dy, POINT_WIDTH, dy));
			CGContextDrawPath(cgContext, kCGPathFillStroke);
		}
	}

	if (bd->points[27])
	{
		int Count = ABS(bd->points[27]);
		
		CGContextSetRGBFillColor(cgContext, 0.9, 0.9, 0.9, 1.0);
		CGPoint pt = bgPointArea[fClockwise][27].origin;
		pt.y -= POINT_HEIGHT;
		
		int dy = POINT_HEIGHT / 15;
		for (int i = 0; i < Count; i++)
		{
			CGContextBeginPath(cgContext);
			CGContextAddRect(cgContext, CGRectMake(pt.x, pt.y + i* dy, POINT_WIDTH, dy));
			CGContextDrawPath(cgContext, kCGPathFillStroke);
		}
	}

}

void bgDrawMark(CGContextRef cgContext, int Index)
{
	int dx = POINT_WIDTH / 4;
	int dy = (Index < 13 || Index == 26) ? BORDER_HEIGHT : -BORDER_HEIGHT;

	CGPoint pt;
	pt.x = bgPointArea[fClockwise][Index].origin.x + POINT_WIDTH / 2;
	pt.y = (Index > 12 && Index != 26) ? BORDER_HEIGHT : BOARD_HEIGHT - BORDER_HEIGHT;

	CGContextBeginPath(cgContext);
	CGContextMoveToPoint(cgContext, pt.x, pt.y);
	CGContextAddLineToPoint(cgContext, pt.x + dx, pt.y + dy);
	CGContextAddLineToPoint(cgContext, pt.x - dx, pt.y + dy);
	CGContextClosePath(cgContext);
	CGContextDrawPath(cgContext, kCGPathFill);
}

int bgBoardPoint(int x, int y)
{
	CGPoint pt = CGPointMake(x, y);

	for (int i = 0; i < 28; i++)
	{
		CGRect Rect = bgPointArea[fClockwise][i];
		Rect.origin.y -= CGRectGetHeight(Rect);
		if (CGRectContainsPoint(Rect, pt))
			return i;
	}

	return -1;
}

int bgBoardClick(int x, int y, BoardData* bd)
{
	CGPoint ClickPos = CGPointMake(x, y);

	CGRect MenuRect[2] =
	{
		CGRectMake(BEAROFF_X, BORDER_HEIGHT + POINT_HEIGHT, POINT_WIDTH, BOARD_HEIGHT - 2 * BORDER_HEIGHT - 2 * POINT_HEIGHT),
		CGRectMake(BORDER_WIDTH, BORDER_HEIGHT + POINT_HEIGHT, POINT_WIDTH, BOARD_HEIGHT - 2 * BORDER_HEIGHT - 2 * POINT_HEIGHT)
	};
		
	if (CGRectContainsPoint(MenuRect[fClockwise], ClickPos))
		return BG_CMD_MENU;

	int Offset = fClockwise ? BORDER_WIDTH + POINT_WIDTH : 0;

	if (!bd->crawford_game && bd->cube_use)
	{
		CGPoint pt;

		if (bd->cube_owner > 0)
			pt.y = BORDER_HEIGHT;
		else if (bd->cube_owner < 0)
			pt.y = BOARD_HEIGHT - BORDER_HEIGHT - DICE_SIZE;
		else
			pt.y = (BOARD_HEIGHT - DICE_SIZE) / 2;
		
		pt.x = BORDER_WIDTH + 6 * POINT_WIDTH + (BAR_WIDTH - DICE_SIZE) / 2;
		pt.x += Offset;
		
		float size = DICE_SIZE;
		
		// Increase the touch area to make it easier to tap the dice.
		if (bd->diceShown == DICE_BELOW_BOARD || bd->diceShown == DICE_NOT_SHOWN)
		{
			pt.x -= DICE_SIZE / 4;
			pt.y -= DICE_SIZE / 4;
			size += DICE_SIZE / 2;
		}
		
		if (x > pt.x && x < pt.x + size && y < pt.y + size && y > pt.y)
			return BG_CMD_DOUBLE;
	}

	CGRect BoardRect[2][2] =
	{
		{
			CGRectMake(BORDER_WIDTH, BORDER_HEIGHT, 6 * POINT_WIDTH, BOARD_HEIGHT - 2 * BORDER_HEIGHT),
			CGRectMake(BORDER_WIDTH + 6 * POINT_WIDTH + BAR_WIDTH, BORDER_HEIGHT, 6 * POINT_WIDTH, BOARD_HEIGHT - 2 * BORDER_HEIGHT),
		},
		{
			CGRectMake(BORDER_WIDTH + POINT_WIDTH + BORDER_WIDTH, BORDER_HEIGHT, 6 * POINT_WIDTH, BOARD_HEIGHT - 2 * BORDER_HEIGHT),
			CGRectMake(BORDER_WIDTH + 6 * POINT_WIDTH + BAR_WIDTH + POINT_WIDTH + BORDER_WIDTH, BORDER_HEIGHT, 6 * POINT_WIDTH, BOARD_HEIGHT - 2 * BORDER_HEIGHT),
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
		{
			CGRectMake(BORDER_WIDTH, BORDER_HEIGHT + 4 * CHEQUER_HEIGHT + CHEQUER_HEIGHT / 2, 6 * POINT_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT - 9 * CHEQUER_HEIGHT),
			CGRectMake(BORDER_WIDTH + 6 * POINT_WIDTH + BAR_WIDTH, BORDER_HEIGHT + 4 * CHEQUER_HEIGHT + CHEQUER_HEIGHT / 2, 6 * POINT_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT - 9 * CHEQUER_HEIGHT),
		},
		{
			CGRectMake(BORDER_WIDTH + POINT_WIDTH + BORDER_WIDTH, BORDER_HEIGHT + 4 * CHEQUER_HEIGHT + CHEQUER_HEIGHT / 2, 6 * POINT_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT - 9 * CHEQUER_HEIGHT),
			CGRectMake(BORDER_WIDTH + 6 * POINT_WIDTH + BAR_WIDTH + POINT_WIDTH + BORDER_WIDTH, BORDER_HEIGHT + 4 * CHEQUER_HEIGHT + CHEQUER_HEIGHT / 2, 6 * POINT_WIDTH, BOARD_HEIGHT - BORDER_HEIGHT - 9 * CHEQUER_HEIGHT),
		}
	};

	if (bd->turn == 1 && CGRectContainsPoint(SideRect[fClockwise][1], ClickPos))
		return BG_CMD_DICE;
	
	if (bd->turn == -1 && CGRectContainsPoint(SideRect[fClockwise][0], ClickPos))
		return BG_CMD_DICE;

	if (bd->turn == 1 && CGRectContainsPoint(SideRect[fClockwise][0], ClickPos))
		return BG_CMD_UNDO;
	
	if (bd->turn == -1 && CGRectContainsPoint(SideRect[fClockwise][1], ClickPos))
		return BG_CMD_UNDO;
	
	return -1;
}

CGPoint bgBoardPointPos(int Index, int Count)
{
	CGPoint pt = bgPointArea[fClockwise][Index].origin;
	pt.x += POINT_WIDTH / 2;
	if (Index > 12)
		pt.y -= CGRectGetHeight(bgPointArea[fClockwise][Index]);

	if (Index > 26)
	{
		if (Index == 27)
			pt.y += CHEQUER_HEIGHT / 15 * Count + CHEQUER_HEIGHT / 2;
		else
			pt.y -= CHEQUER_HEIGHT / 15 * Count + CHEQUER_HEIGHT / 2;
	}
	else
	{
		if (Index > 12)
			pt.y += CHEQUER_HEIGHT * Count + CHEQUER_HEIGHT / 2;
		else
			pt.y -= CHEQUER_HEIGHT * Count + CHEQUER_HEIGHT / 2;
	}

	return pt;
}

void bgBoardUpdateTrack(CALayer* GlowLayer, int Tracking, BoardData* bd)
{
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
			pt.y = BORDER_HEIGHT;
		else if (bd->cube_owner < 0)
			pt.y = BOARD_HEIGHT - BORDER_HEIGHT - DICE_SIZE;
		else
			pt.y = (BOARD_HEIGHT - DICE_SIZE) / 2;
		
		int Offset = fClockwise ? BORDER_WIDTH + POINT_WIDTH : 0;

		pt.x = BORDER_WIDTH + 6 * POINT_WIDTH + (BAR_WIDTH - DICE_SIZE) / 2;
		pt.x += Offset;

		int w = DICE_SIZE + 4;
		int h = DICE_SIZE + 4;

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
