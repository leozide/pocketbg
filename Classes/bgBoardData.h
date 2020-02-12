#ifndef _BGBOARDDATA_H_
#define _BGBOARDDATA_H_

typedef enum _DiceShown {
	DICE_NOT_SHOWN = 0, DICE_BELOW_BOARD, DICE_ON_BOARD, DICE_ROLLING
} DiceShown;

typedef enum _animation {
    ANIMATE_NONE, ANIMATE_BLINK, ANIMATE_SLIDE
} animation;


#include "config.h"
typedef int TanBoard[2][25];
typedef const int (*ConstTanBoard)[25];
//#include "gnubg-types.h"
#include "eval.h"
#include "backgammon.h"

extern unsigned int nDelay;

	typedef struct 
	{
		int playing, computer_turn;
		int drag_point, drag_colour, x_drag, y_drag, x_dice[ 2 ], y_dice[ 2 ],
		drag_button,
		cube_use; /* roll showing on the off-board dice */
		DiceShown diceShown;
		TanBoard old_board;
		double click_time;
		int clockwise;

		int cube_owner; /* -1 = bottom, 0 = centred, 1 = top */
		int qedit_point; /* used to remember last point in quick edit mode */
		int resigned;
		int nchequers;
		move *all_moves, *valid_move;
		movelist move_list;
		
		/* remainder is from FIBS board: data */
		char name[ MAX_NAME_LEN ], name_opponent[ MAX_NAME_LEN ];
		int match_to, score, score_opponent;
		int points[ 28 ]; /* 0 and 25 are the bars */
		int turn; /* -1 is X, 1 is O, 0 if game over */
		unsigned int diceRoll[ 2 ]; /* 0, 0 if not rolled */
		int cube;
		int can_double, opponent_can_double; /* allowed to double */
		int doubled; /* -1 if X is doubling, 1 if O is doubling */
		int colour; /* -1 for player X, 1 for player O */
		int direction; /* -1 playing from 24 to 1, 1 playing from 1 to 24 */
		int home, bar; /* 0 or 25 depending on fDirection */
		int off, off_opponent; /* number of men borne off */
		int on_bar, on_bar_opponent; /* number of men on bar */
		int to_move; /* 0 to 4 -- number of pieces to move */
		int forced, crawford_game; /* unused, Crawford game flag */
		int redoubles; /* number of instant redoubles allowed */
		int DragTargetHelp;	/* Currently showing draw targets? */
		int iTargetHelpPoints[4];	/* Drag target position */
	} BoardData;
	
extern void board_animate(BoardData* bd, int move[8], int player);

extern BoardData* pwBoard;

extern int game_set( BoardData *board, TanBoard points, int roll,
					 char *name, char *opp_name, int match,
					 int score, int opp_score, int die0, int die1,
					 int computer_turn, int nchequers );

extern void* nNextTurn;

void bgOutput(const char* sz, int NewLine);
void bgShowOutput(void);
void bgSetNeedsDisplay(void);

extern void GTKProgressEnd(void);
extern void GTKProgressStart(const char *sz);
extern void GTKProgressStartValue(char *sz, int iMax);
extern void GTKProgressValue(int fValue, int iMax);
extern void GTKProgress(void);

#endif // _BGBOARDDATA_H_
