extern int BOARD_WIDTH;
extern int BOARD_HEIGHT;
extern int BORDER_WIDTH;
extern int BORDER_TOP_HEIGHT;
extern int BORDER_BOTTOM_HEIGHT;
extern int POINT_WIDTH;
extern int POINT_HEIGHT;
extern int BAR_WIDTH;
extern int BAR_OFFSET;
extern int BEAROFF_X;
extern int CHEQUER_HEIGHT;
extern int CHEQUER_RADIUS;
extern int DICE_SIZE;

void CGContextAddRoundedRect(CGContextRef c, CGRect rect, int corner_radius);
void CGContextShowTextAtPointCentered(CGContextRef cgContext, CGFloat x, CGFloat y, const char* string, size_t length);

void bgDrawBoard(CGContextRef cgContext);
void bgDrawChequers(CGContextRef cgContext, BoardData* bd, CGImageRef whiteImage, CGImageRef blackImage);
void bgDrawMark(CGContextRef cgContext, int Index);

int bgBoardPoint(int x, int y);
int bgBoardClick(int x, int y, BoardData* bd);
CGPoint bgBoardPointPos(int Index, int Count);
void bgBoardUpdateTrack(CALayer* GlowLayer, int Tracking, BoardData* bd);

void bgBoardUpdateSize();

typedef struct 
{
	const char* Name;
	float Value[4];
} bgColorEntry;

extern bgColorEntry gCheckerColors[];
extern int gNumCheckerColors;

extern float Player1Color[4];
extern float Player2Color[4];

extern int fAdvancedHint;