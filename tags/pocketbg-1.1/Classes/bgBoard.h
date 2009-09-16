#define BOARD_WIDTH 480
#define BOARD_HEIGHT 320
#define BORDER_WIDTH 6
#define BORDER_HEIGHT 5
#define POINT_WIDTH 33
#define POINT_HEIGHT 120
#define BAR_WIDTH 33
#define BAR_OFFSET 50
#define BEAROFF_X (2*BORDER_WIDTH+BAR_WIDTH+12*POINT_WIDTH)
#define CHEQUER_HEIGHT 28
#define CHEQUER_RADIUS 14
#define DICE_SIZE 31

void CGContextAddRoundedRect(CGContextRef c, CGRect rect, int corner_radius);
void CGContextShowTextAtPointCentered(CGContextRef cgContext, CGFloat x, CGFloat y, const char* string, size_t length);

void bgDrawBoard(CGContextRef cgContext);
void bgDrawChequers(CGContextRef cgContext, BoardData* bd, CGImageRef whiteImage, CGImageRef blackImage);
void bgDrawMark(CGContextRef cgContext, int Index);

int bgBoardPoint(int x, int y);
int bgBoardClick(int x, int y, BoardData* bd);
CGPoint bgBoardPointPos(int Index, int Count);
void bgBoardUpdateTrack(CALayer* GlowLayer, int Tracking, BoardData* bd);

typedef struct 
{
	const char* Name;
	float Value[4];
} bgColorEntry;

extern bgColorEntry gCheckerColors[];
extern int gNumCheckerColors;

extern float Player1Color[4];
extern float Player2Color[4];
