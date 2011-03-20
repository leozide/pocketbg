typedef struct
{
	float Width;
	float Height;
	float BorderWidth;
	float BorderTopHeight;
	float BorderBottomHeight;
	float PointWidth;
	float PointHeight;
	float BarWidth;
	float BarOffset;
	float BearoffX;
	float ChequerHeight;
	float ChequerRadius;
	float DiceSize;
	CGRect PointArea[2][28]; 
} bgBoardSize;

extern bgBoardSize gBoardSize;
extern bgBoardSize gBoardSizeScaled;
extern float gBoardScale;

void bgBoardUpdateSize(bgBoardSize* BoardSize, float Width, float Height);

void CGContextAddRoundedRect(CGContextRef c, CGRect rect, int corner_radius);
void CGContextShowTextAtPointCentered(CGContextRef cgContext, CGFloat x, CGFloat y, const char* string, size_t length);

void bgDrawBoard(bgBoardSize* BoardSize, CGContextRef cgContext);
void bgDrawChequers(bgBoardSize* BoardSize, CGContextRef cgContext, BoardData* bd, CGImageRef whiteImage, CGImageRef blackImage);
void bgDrawMark(bgBoardSize* BoardSize, CGContextRef cgContext, int Index);

int bgBoardPoint(bgBoardSize* BoardSize, int x, int y);
int bgBoardClick(bgBoardSize* BoardSize, int x, int y, BoardData* bd);
CGPoint bgBoardPointPos(bgBoardSize* BoardSize, int Index, int Count);
void bgBoardUpdateTrack(bgBoardSize* BoardSize, CALayer* GlowLayer, int Tracking, BoardData* bd);

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