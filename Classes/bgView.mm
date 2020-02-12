#import <QuartzCore/QuartzCore.h>

#import "bgAppDelegate.h"
#import "bgViewController.h"
#import "bgView.h"
#import "bgDlg.h"
#import "bgBoard.h"

bgView* gView;
int fAdvancedHint;

extern "C" {
#include "bgBoardData.h"
#include "sound.h"
#include "drawboard.h"
#include "positionid.h"
	int gnubg_main();
	extern void SetDefaultDifficulty();
	extern void UserCommand( const char *szCommand );
	char PKGDATADIR[1024];
	BoardData* pwBoard;
	void* nNextTurn;
	extern int fX;
	int BoardAnimating;
//	int NextTurnNotify(void*);
	char* outputStack[4];
	int outputStackSize;
	int tracking;
	int tracking_type;
	int skip_anim;
	int fEnableProgress;

#define BG_TRACK_NONE 0
#define BG_TRACK_TAKE 1

	typedef struct
	{
		int Type;
		int Param;
		const char* Text;
	} DlgData;

	void bgSetNeedsDisplay()
	{
		[gView setNeedsDisplay];
	}

	void bgDlgShow(int DlgType, int Param)
	{
		[gView ShowDlg:DlgType withParam:Param withText:nil];
	}

	void GTKProgressEnd(void)
	{
		bgDlgShow(BG_DLG_NONE, 0);
	}
	void GTKProgressStart(const char *sz)
	{
		if (fEnableProgress)
			[gView ShowDlg:BG_DLG_PROGRESS withParam:0 withText:sz];

		GTKProgress();
	}
	void GTKProgressStartValue(char *sz, int iMax)
	{
	}
	void GTKProgressValue(int fValue, int iMax)
	{
	}
	void GTKProgress(void)
	{
		BOOL wasEnabled = gView.userInteractionEnabled;
		
		if (wasEnabled)
			gView.userInteractionEnabled = NO;

		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		while (CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, TRUE) == kCFRunLoopRunHandledSource) ;
		[pool release];

		if (wasEnabled)
			gView.userInteractionEnabled = YES;
	}
	
	char* outputStr;

	void bgOutput(const char* sz, int NewLine)
	{
		size_t len = strlen(sz);

		if (outputStr)
			len += strlen(outputStr);

		if (NewLine)
			len++;

		if (!len)
			return;

		char* str = (char*)malloc(len+1);
		str[0] = 0;

		if (outputStr)
			strcpy(str, outputStr);

		strcat(str, sz);

		if (NewLine)
			strcat(str, "\n");

		free(outputStr);
		outputStr = str;
	}
	
	void bgShowOutput()
	{
		if (!outputStr)
			return;

		if (outputStackSize > 0)
		{
			if (!strcmp(outputStr, outputStack[outputStackSize-1]))
				return;
		}

		if (outputStackSize < 3)
		{
			outputStack[outputStackSize++] = outputStr;
			[gView performSelector:@selector(ShowOutput:) withObject:nil afterDelay:0.0];
		}

		outputStr = NULL;
	}
	
//	typedef int (*IdleFunc)(void*);
	typedef struct
	{
		IdleFunc Func;
		void* Data;
	} IdleData;
	
	void* g_idle_add(IdleFunc Func, void* Data)
	{
		IdleData* SelData = new IdleData;
		SelData->Func = Func;
		SelData->Data = Data;
		NSValue* val = [NSValue valueWithPointer:SelData];
		[gView performSelector:@selector(IdleSelector:) withObject:val afterDelay:0.0];
		return val;
	}
	void g_source_remove(void* i)
	{
		NSValue* val = (NSValue*)i;
		[NSObject cancelPreviousPerformRequestsWithTarget:gView selector:@selector(IdleSelector:) object:val];
	}
};

int fGUIHighDieFirst = 1;
int fGUIIllegal = 0;
#define ngettext(a,b,c) ((c==1) ? (a) : (b))

int fGUIDragTargetHelp = 1;
#define _(a) a
static void board_beep(BoardData* bd)
{
}

extern "C"
{
bool can_redouble()
{
    if( ms.nMatchTo > 0 ) {
//		outputl( _("Redoubles are not permitted during match play.") );
		return false;
    }
	
    if( !nBeavers ) {
//		outputl( _("Beavers are disabled (see `help set beavers').") );
		return false;
    }
	
    if( ms.cBeavers >= nBeavers ) {
//		if( nBeavers == 1 )
//			outputl( _("Only one beaver is permitted (see `help set beavers').") );
//		else
//			outputf( _("Only %d beavers are permitted (see `help set beavers').\n"), nBeavers );
		
		return false;
    }
    
    if( ms.gs != GAME_PLAYING || !ms.fDoubled ) {
//		outputl( _("The cube must have been offered before you can redouble it.") );
		return false;
    }
    
//    if( ap[ ms.fTurn ].pt != PLAYER_HUMAN && !fComputerDecision ) {
//		outputl( _("It is the computer's turn -- type `play' to force it to move immediately.") );
//		return false;
//    }
	
    if( ms.nCube >= ( MAX_CUBE >> 1 ) ) {
//		outputf( _("The cube is already at %d; you can't double any more.\n"), MAX_CUBE );
		return false;
    }

    return true;
}

bool can_double()
{
    if( ms.gs != GAME_PLAYING ) {
//		outputl( _("No game in progress (type `new game' to start one).") );
		return false;
    }
	
//    if( ap[ ms.fTurn ].pt != PLAYER_HUMAN && !fComputerDecision ) {
//		outputl( _("It is the computer's turn -- type `play' to force it to move immediately.") );
//		return false;
  //  }
	
    if( ms.fCrawford ) {
//		outputl( _("Doubling is forbidden by the Crawford rule (see `help set crawford').") );
		return false;
    }
	
    if( !ms.fCubeUse ) {
//		outputl( _("The doubling cube has been disabled (see `help set cube use').") );
		return false;
    }
	
    if( ms.fDoubled ) {
//		outputl( _("The `double' command is for offering the cube, not "
//				   "accepting it.  Use\n`redouble' to immediately offer the "
//				   "cube back at a higher value.") );
		return false;
    }
    
    if( ms.fTurn != ms.fMove ) {
		outputl( _("You are only allowed to double if you are on roll.") );
		outputx();
		return false;
    }
    
    if( ms.anDice[ 0 ] ) {
		outputl( _("You can't double after rolling the dice -- wait until your next turn.") );
		outputx();
		return false;
    }
	
    if( ms.fCubeOwner >= 0 && ms.fCubeOwner != ms.fTurn ) {
		outputl( _("You do not own the cube.") );
		outputx();
		return false;
    }
	
    if( ms.nCube >= MAX_CUBE ) {
		outputf( _("The cube is already at %d; you can't double any more.\n"), MAX_CUBE );
		outputx();
		return false;
    }

	return true;
}

animation animGUI = ANIMATE_SLIDE;
unsigned int nGUIAnimSpeed = 4;
int animate_player, animate_move_list[8], animation_finished, anim_move;
int animate_hint;

extern void board_animate( BoardData *board, int move[ 8 ], int player )
{
	if (animGUI == ANIMATE_NONE || ms.fResigned)
	{
		BoardAnimating = FALSE;
		return;
	}
	
	memcpy(animate_move_list, move, sizeof(animate_move_list));
	animate_player = player;

	BoardAnimating = TRUE;
	animation_finished = FALSE;
	anim_move = 0;
	skip_anim = 0;
	animate_hint = 0;

	[gView PlayAnim: nil];
}

/* A global setting has changed; update entry in Settings menu if necessary. */
extern void GTKSet( void *p )
{
//    BoardData *bd = pwBoard;
/*
    if( p == ap ) {
		// Handle the player names.
		gtk_label_set_text( GTK_LABEL( GTK_BIN(gtk_item_factory_get_widget_by_action( pif, CMD_SET_TURN_0 ))->child ), (ap[ 0 ].szName) );
		gtk_label_set_text( GTK_LABEL( GTK_BIN(gtk_item_factory_get_widget_by_action( pif, CMD_SET_TURN_1 ))->child ), (ap[ 1 ].szName) );
		
		GL_SetNames();
		
		GTKRegenerateGames();
    } else */if( p == &ms.fTurn ) {
    } else if( p == &ms.gs ) {
		// Handle the game state.
//		fAutoCommand = TRUE;
		pwBoard->playing = (ms.gs == GAME_PLAYING);
//		fAutoCommand = FALSE;
    } /*else if( p == &ms.fCrawford )
		ShowBoard(); // this is overkill, but it works
    else if (IsPanelShowVar(WINDOW_ANNOTATION, p)) {
		if (PanelShowing(WINDOW_ANNOTATION))
			ShowHidePanel(WINDOW_ANNOTATION);
    } else if (IsPanelShowVar(WINDOW_GAME, p)) {
		ShowHidePanel(WINDOW_GAME);
    } else if (IsPanelShowVar(WINDOW_ANALYSIS, p)) {
		ShowHidePanel(WINDOW_ANALYSIS);
    } else if (IsPanelShowVar(WINDOW_MESSAGE, p)) {
		ShowHidePanel(WINDOW_MESSAGE);
    } else if (IsPanelShowVar(WINDOW_THEORY, p)) {
		ShowHidePanel(WINDOW_THEORY);
    } else if (IsPanelShowVar(WINDOW_COMMAND, p)) {
		ShowHidePanel(WINDOW_COMMAND);
	} else if( p == &bd->rd->fDiceArea ) {
		if( GTK_WIDGET_REALIZED( pwBoard ) )
		{
			{    
				if( GTK_WIDGET_REALIZED( pwBoard ) ) {
					if( GTK_WIDGET_VISIBLE( bd->dice_area ) && !bd->rd->fDiceArea )
						gtk_widget_hide( bd->dice_area );
					else if( ! GTK_WIDGET_VISIBLE( bd->dice_area ) && bd->rd->fDiceArea )
						gtk_widget_show_all( bd->dice_area );
				}
			}}
    }
	else if( p == &bd->rd->fShowIDs )
	{
		inCallback = TRUE;
		gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(gtk_item_factory_get_widget(pif, "/View/Show IDs above board" )), bd->rd->fShowIDs);
		inCallback = FALSE;
		
		if( GTK_WIDGET_REALIZED( pwBoard ) )
		{
			if( GTK_WIDGET_VISIBLE( bd->vbox_ids ) && !bd->rd->fShowIDs )
				gtk_widget_hide( bd->vbox_ids );
			else if( !GTK_WIDGET_VISIBLE( bd->vbox_ids ) && bd->rd->fShowIDs )
				gtk_widget_show_all( bd->vbox_ids );
			gtk_widget_queue_resize(pwBoard);
		}
	}
	else if( p == &fGUIShowPips )
		ShowBoard(); // this is overkill, but it works
	else if (p == &fOutputWinPC)
	{
		MoveListRefreshSize();
	}
	else if (p == &showMoveListDetail)
	{
		if (pwMoveAnalysis && pwDetails)
			gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(pwDetails), showMoveListDetail);
	}
	 */
}
}

static void write_points ( int points[ 28 ], const int turn, const int nchequers, TanBoard anBoard )
{
	int i;
	int anOff[ 2 ];
	TanBoard an;
	
	memcpy( an, anBoard, sizeof an );
	
	if ( turn < 0 )
		SwapSides( an );
	
	for ( i = 0; i < 28; ++i )
		points[ i ] = 0;
	
	/* Opponent on bar */
	points[ 0 ] = -(int)an[ 0 ][ 24 ];
	
	/* Board */
	for( i = 0; i < 24; i++ ) {
		if ( an[ 1 ][ i ] )
			points[ i + 1 ] = an[ 1 ][ i ];
		if ( an[ 0 ][ i ] )
			points[ 24 - i ] = -(int)an[ 0 ][ i ];
	}
	
	/* Player on bar */
	points[ 25 ] = an[ 1 ][ 24 ];
	
	anOff[ 0 ] = anOff[ 1 ] = nchequers;
	for( i = 0; i < 25; i++ ) {
		anOff[ 0 ] -= an[ 0 ][ i ];
		anOff[ 1 ] -= an[ 1 ][ i ];
	}
    
	points[ 26 ] = anOff[ 1 ];
	points[ 27 ] = -anOff[ 0 ];
}

static int board_point( BoardData *bd, int x0, int y0 )
{
	if (bgActiveDlg != BG_DLG_NONE)
		return -1;
/*
	int Offset = fClockwise ? BORDER_WIDTH + POINT_WIDTH : 0;

	if (y0 > BORDER_HEIGHT + 4 * CHEQUER_HEIGHT + CHEQUER_HEIGHT / 2 && y0 < BOARD_HEIGHT - BORDER_HEIGHT - 4 * CHEQUER_HEIGHT - CHEQUER_HEIGHT / 2)
	{
		if (x0 > Offset + BORDER_WIDTH && x0 < Offset + BORDER_WIDTH + 6 * POINT_WIDTH)
			return POINT_LEFT;

		if (x0 > Offset + BORDER_WIDTH + 6 * POINT_WIDTH + BAR_WIDTH && x0 < Offset + BORDER_WIDTH + 12 * POINT_WIDTH + BAR_WIDTH)
			return POINT_RIGHT;
	}
*/
	return bgBoardPoint(&gBoardSize, x0, y0);
}

extern void read_board( BoardData *bd, TanBoard points )
{
    int i;
	
    for( i = 0; i < 24; i++ ) {
        points[ bd->turn <= 0 ][ i ] = bd->points[ 24 - i ] < 0 ?
		abs( bd->points[ 24 - i ] ) : 0;
        points[ bd->turn > 0 ][ i ] = bd->points[ i + 1 ] > 0 ?
		abs( bd->points[ i + 1 ] ) : 0;
    }
    
    points[ bd->turn <= 0 ][ 24 ] = abs( bd->points[ 0 ] );
    points[ bd->turn > 0 ][ 24 ] = abs( bd->points[ 25 ] );
}


extern void write_board ( BoardData *bd, TanBoard anBoard )
{
	write_points( bd->points, bd->turn,  bd->nchequers, anBoard );
}

static size_t board_text_to_setting (const char **board_text, int *failed)
{
	if (*failed)
		return 0;
	
	if( *(*board_text)++ != ':' )
	{
		*failed = 1;
		return 0;
	}
	return strtol( *board_text, (char **) board_text, 10 );
}

static int board_set( BoardData *bd, const char *board_text, const int resigned, const int cube_use )
{
	char *dest;//, buf[ 32 ];
    int i, *pn, **ppn;
    int old_board[ 28 ];
    int old_cube, old_doubled, old_crawford;
    int old_resigned;
    int old_turn;
    int redrawNeeded = 0;
    int failed = 0;
	int old_score, old_score_opponent;
    
    int *match_settings[ 3 ]; 
    unsigned int old_dice[ 2 ];

    match_settings[ 0 ] = &bd->match_to;
    match_settings[ 1 ] = &bd->score;
    match_settings[ 2 ] = &bd->score_opponent;

	old_score = bd->score;
	old_score_opponent = bd->score_opponent;

    old_dice[ 0 ] = bd->diceRoll[ 0 ];
    old_dice[ 1 ] = bd->diceRoll[ 1 ];
    old_turn = bd->turn;
	
    if( strncmp( board_text, "board:", 6 ) )
		return -1;
    
    board_text += 6;
	
    for( dest = bd->name, i = 31; i && *board_text && *board_text != ':';
		i-- )
		*dest++ = *board_text++;
	
    *dest = 0;
	
    if( !board_text )
		return -1;
	
    board_text++;
    
    for( dest = bd->name_opponent, i = 31;
		i && *board_text && *board_text != ':'; i-- )
		*dest++ = *board_text++;
	
    *dest = 0;
	
    if( !board_text )
		return -1;
	
    for( i = 3, ppn = match_settings; i--; ) {
		**ppn++ =  (int)board_text_to_setting (&board_text, &failed);
    }
    if (failed)
		return -1;
	
    for( i = 0, pn = bd->points; i < 26; i++ ) {
		old_board[ i ] = *pn;
		*pn++ = (int)board_text_to_setting (&board_text, &failed);
    }
    if (failed)
		return -1;
	
	if (old_score != bd->score || old_score_opponent != bd->score_opponent)
		redrawNeeded = 1;

    old_board[ 26 ] = bd->points[ 26 ];
    old_board[ 27 ] = bd->points[ 27 ];
	
    old_cube = bd->cube;
    old_doubled = bd->doubled;
    old_crawford = bd->crawford_game;
    old_resigned = bd->resigned;
	
    bd->resigned = resigned;
    
    bd->turn = (int)board_text_to_setting (&board_text, &failed);
    bd->diceRoll[0] = (unsigned int)board_text_to_setting (&board_text, &failed);
    bd->diceRoll[1] = (unsigned int)board_text_to_setting (&board_text, &failed);
    board_text_to_setting (&board_text, &failed);
    board_text_to_setting (&board_text, &failed);
    bd->cube = (int)board_text_to_setting (&board_text, &failed);
    bd->can_double = (int)board_text_to_setting (&board_text, &failed);
    bd->opponent_can_double = (int)board_text_to_setting (&board_text, &failed);
    bd->doubled = (int)board_text_to_setting (&board_text, &failed);
    bd->colour = (int)board_text_to_setting (&board_text, &failed);
    bd->direction = (int)board_text_to_setting (&board_text, &failed);
    bd->home = (int)board_text_to_setting (&board_text, &failed);
    bd->bar = (int)board_text_to_setting (&board_text, &failed);
    bd->off = (int)board_text_to_setting (&board_text, &failed);
    bd->off_opponent = (int)board_text_to_setting (&board_text, &failed);
    bd->on_bar = (int)board_text_to_setting (&board_text, &failed);
    bd->on_bar_opponent = (int)board_text_to_setting (&board_text, &failed);
    bd->to_move = (int)board_text_to_setting (&board_text, &failed);
    bd->forced = (int)board_text_to_setting (&board_text, &failed);
    bd->crawford_game = (int)board_text_to_setting (&board_text, &failed);
    bd->redoubles = (int)board_text_to_setting (&board_text, &failed);
    if (failed)
	    return -1;
	
    if( bd->colour < 0 )
		bd->off = -bd->off;
    else
		bd->off_opponent = -bd->off_opponent;
    
    if( bd->direction < 0 ) {
		bd->points[ 26 ] = bd->off;
		bd->points[ 27 ] = bd->off_opponent;
    } else {
		bd->points[ 26 ] = bd->off_opponent;
		bd->points[ 27 ] = bd->off;
    }
	
    /* calculate number of chequers */
    bd->nchequers = 0;
    for ( i = 0; i < 28; ++i )
		if ( bd->points[ i ] > 0 )
			bd->nchequers += bd->points[ i ];
/*
    if( !editing ) {
		gtk_entry_set_text( GTK_ENTRY( bd->name0 ), bd->name_opponent );
		gtk_entry_set_text( GTK_ENTRY( bd->name1 ), bd->name );
		gtk_label_set_text( GTK_LABEL( bd->lname0 ), bd->name_opponent );
		gtk_label_set_text( GTK_LABEL( bd->lname1 ), bd->name );
		
		if( bd->match_to ) {
			sprintf( buf, "%d", bd->match_to );
			gtk_label_set_text( GTK_LABEL( bd->lmatch ), buf );
		} else
			gtk_label_set_text( GTK_LABEL( bd->lmatch ), _("unlimited") );
		
        gtk_spin_button_set_value( GTK_SPIN_BUTTON( bd->score0 ),
								  bd->score_opponent );
        gtk_spin_button_set_value( GTK_SPIN_BUTTON( bd->score1 ),
								  bd->score );
        gtk_spin_button_set_value( GTK_SPIN_BUTTON( bd->match ), 
								  bd->match_to );
		
        score_changed( NULL, bd );
		
		SetCrawfordToggle(bd);
		gtk_widget_set_sensitive( bd->crawford, bd->crawford_game);
*/
		read_board( bd, bd->old_board );
/*
		update_position_id( bd, bd->old_board );
		update_pipcount ( bd, bd->old_board );
    }

	update_match_id ( bd );
    update_move( bd );
*/	
    if (fGUIHighDieFirst && bd->diceRoll[ 0 ] < bd->diceRoll[ 1 ] )
	    swap_us( bd->diceRoll, bd->diceRoll + 1 );

	if (bd->diceRoll[0] != old_dice[0] || bd->diceRoll[1] != old_dice[1])
	{
		redrawNeeded = 1;

		if( bd->x_dice[ 0 ] > 0 )
		{
/*			// dice were visible before; now they're not
			int ax[2];
			ax[0] = bd->x_dice[ 0 ];
			ax[1] = bd->x_dice[ 1 ];
			bd->x_dice[ 0 ] = bd->x_dice[ 1 ] = -DIE_WIDTH - 3;
			if ( bd->rd->nSize > 0 ) {
				board_invalidate_rect( bd->drawing_area,
									  ax[ 0 ] * bd->rd->nSize,
									  bd->y_dice[ 0 ] * bd->rd->nSize,
									  DIE_WIDTH * bd->rd->nSize,  
									  DIE_HEIGHT * bd->rd->nSize, bd);
				board_invalidate_rect( bd->drawing_area, ax[ 1 ] * bd->rd->nSize,
									  bd->y_dice[ 1 ] * bd->rd->nSize, DIE_WIDTH * bd->rd->nSize, 
									  DIE_HEIGHT * bd->rd->nSize, bd );
			}
 */
		}
		
		if (bd->diceRoll[0] <= 0)
		{
/*
			// Dice not on board
			bd->x_dice[ 0 ] = bd->x_dice[ 1 ] = -DIE_WIDTH - 3;
 */
			
			if ((bd->diceRoll[ 0 ] == 0 && old_dice[0] > 0) &&
				(bd->diceRoll[ 1 ] == 0 && old_dice[1] > 0))
			{
				bd->diceShown = DICE_BELOW_BOARD;
				// Keep showing shaken values
				bd->diceRoll[ 0 ] = old_dice[ 0 ];
				bd->diceRoll[ 1 ] = old_dice[ 1 ];
			}
			else
				bd->diceShown = DICE_NOT_SHOWN;
		}
		else
		{
//			RollDice2d(bd);
			bd->diceShown = DICE_ON_BOARD;
		}
	}
	
    if (bd->diceShown == DICE_ON_BOARD )
	{
		GenerateMoves( &bd->move_list, bd->old_board,
					  bd->diceRoll[ 0 ], bd->diceRoll[ 1 ], TRUE );
		
		/* bd->move_list contains pointers to static data, so we need to
		 copy the actual moves into private storage. */
		if( bd->all_moves )
			free( bd->all_moves );
		bd->all_moves = (move*)malloc( bd->move_list.cMoves * sizeof( move ) );
		bd->move_list.amMoves = (move*)memcpy( bd->all_moves, bd->move_list.amMoves,
									   bd->move_list.cMoves * sizeof( move ) );
		bd->valid_move = NULL;
    }

	if (bd->turn != old_turn)
		redrawNeeded = 1;
	
    if (bd->doubled != old_doubled || bd->cube != old_cube || bd->cube_owner != bd->opponent_can_double - bd->can_double ||
	    cube_use != bd->cube_use || bd->crawford_game != old_crawford )
	{
		redrawNeeded = 1;
		
		bd->cube_owner = bd->opponent_can_double - bd->can_double;
		bd->cube_use = cube_use;
	}
	
    if ( bd->resigned != old_resigned )
		redrawNeeded = 1;

    if ( fClockwise != bd->clockwise )
	{
		bd->clockwise = fClockwise;
		[gView UpdateBoardImage];
		redrawNeeded = 1;
    }

	for (i = 0; i < 28; i++)
		if (bd->points[i] != old_board[i])
		{
			redrawNeeded = 1;
			break;
		}

	if (redrawNeeded)
		bgSetNeedsDisplay();

    return 0;
}

extern int game_set( BoardData *bd, TanBoard points, int roll,
					 char *name, char *opp_name, int match,
					 int score, int opp_score, int die0, int die1,
					 int computer_turn, int nchequers )
{
    char board_str[ 256 ];
    
	memcpy( bd->old_board, points, sizeof( bd->old_board ) );
	
    FIBSBoard( board_str, points, roll, name, opp_name, match, score,
			  opp_score, die0, die1, ms.nCube, ms.fCubeOwner, ms.fDoubled,
			  ms.fTurn, ms.fCrawford, nchequers );
	
    board_set( bd, board_str, -bd->turn * ms.fResigned, ms.fCubeUse );
	
    /* FIXME update names, score, match length */
//    if( bd->rd->nSize <= 0 )
//		return 0;
	
    bd->computer_turn = computer_turn;
    
    if( die0 ) {
		if( fGUIHighDieFirst && die0 < die1 )
			swap( &die0, &die1 );
    }
	
//    update_buttons( bd );
	
	/* FIXME it's overkill to do this every time, but if we don't do it,
	 then "set turn <player>" won't redraw the dice in the other colour. */
//		gtk_widget_queue_draw( bd->dice_area );

    return 0;
}

extern char * ReturnHits( TanBoard anBoard )
{
	
	int aiHit[ 15 ];
	int i, j, k, l, m, n, c;
	movelist ml;
	int aiDiceHit[ 6 ][ 6 ];
	
	memset( aiHit, 0, sizeof ( aiHit ) );
	memset( aiDiceHit, 0, sizeof ( aiDiceHit ) );
	
	SwapSides( anBoard );
	
	/* find blots */
	
	for ( i = 0; i < 6; ++i )
		for ( j = 0; j <= i; ++j ) {
			
			if ( ! ( c = GenerateMoves( &ml, anBoard, i + 1, j + 1, FALSE ) ) )
			/* no legal moves */
				continue;
			
			k = 0;
			for ( l = 0; l < 24; ++l )
				if ( anBoard[ 0 ][ l ] == 1 ) {
					for ( m = 0; m < c; ++m ) {
						move *pm = &ml.amMoves[ m ];
						for ( n = 0; n < 4 && pm->anMove[ 2 * n ] > -1; ++n )
							if ( pm->anMove[ 2 * n + 1 ] == ( 23 - l ) ) {
								/* hit */
								aiHit[ k ] += 2 - ( i == j );
								++aiDiceHit[ i ][ j ];
								/* next point */
								goto nextpoint;
							}
					}
				nextpoint:
					++k;
				}
			
		}
	
	for ( j = 14; j >= 0; --j )
		if ( aiHit[ j ] )
			break;
	
	if ( j >= 0 ) {
		char *pch = (char*)malloc( 3 * ( j + 1 ) + 200 );
		strcpy( pch, "" );
		for ( i = 0; i <= j; ++i )
			if ( aiHit[ i ] )
				sprintf( strchr( pch, 0 ), "%d ", aiHit[ i ] );
		
		for ( n = 0, i = 0; i < 6; ++i )
			for ( j = 0; j <= i; ++j )
				n += ( aiDiceHit[ i ][ j ] > 0 ) * ( 2 - ( i == j ) );
		
		sprintf( strchr( pch, 0 ),
				ngettext("(no hit: %d roll)", "(no hit: %d rolls)", (36 - n) ),
				36 - n );
		return pch;
	}
	
	return NULL;
	
}


/* A chequer has been moved or the board has been updated -- update the
 move and position ID labels. */
int update_move(BoardData *bd)
{
    char move_buf[40];
    char *move = move_buf;
    unsigned int i;
	TanBoard points;
    unsigned char key[ 10 ];
    int fIncomplete = TRUE, fIllegal = TRUE;

    strcpy(move, _("Illegal move"));
    
    read_board( bd, points );
//    update_position_id( bd, points );
//    update_pipcount ( bd, points );
	
    bd->valid_move = NULL;
    
    if( EqualBoards( points, bd->old_board ) ) {
        /* no move has been made */
		move = NULL;
		fIncomplete = fIllegal = FALSE;
    } else {
        PositionKey( points, key );
		
        for( i = 0; i < bd->move_list.cMoves; i++ )
            if( EqualKeys( bd->move_list.amMoves[ i ].auch, key ) ) {
                bd->valid_move = bd->move_list.amMoves + i;
				fIncomplete = bd->valid_move->cMoves < bd->move_list.cMaxMoves
				|| bd->valid_move->cPips < bd->move_list.cMaxPips;
				fIllegal = FALSE;
                FormatMove( move = move_buf, bd->old_board,
						   bd->valid_move->anMove );
                break;
            }
		
        /* show number of return hits */
//        UpdateTheoryData(bd, TT_RETURNHITS, msBoard());
		
        if ( bd->valid_move ) {
			TanBoard anBoard;
			char *pch;
			PositionFromKey( anBoard, bd->valid_move->auch );
			if ( ( pch = ReturnHits( anBoard ) ) ) {
//				outputf( _("Return hits: %s\n"), pch );
//				outputx();
				free( pch );
			}
			else {
//				outputl( "" ); 
//				outputx();
			}
			
        }
		
    }
/*	
    gtk_widget_set_state( bd->wmove, fIncomplete ? GTK_STATE_ACTIVE :
						 GTK_STATE_NORMAL );
    gtk_label_set_text( GTK_LABEL( bd->wmove ), move );
	*/
    return (fIllegal && !fGUIIllegal) ? -1 : 0;
}

/* This code is called on a button release event
 *
 * Since this code has side-effects, it should only be called from
 * button_release_event().  Mainly, it assumes that a checker
 * has been picked up.  If the move fails, that pickup will be reverted.
 */

bool place_chequer_or_revert(BoardData *bd, int dest )
{
    /* This procedure has grown more complicated than I like
     * We might want to discard most of it and use a calculated 
     * list of valid destination points (since we have the code for that available 
     * 
     * Known problems:
     *    
     * Not tested for "allow dragging to illegal points". Unlikely to work, might crash 
     * It is not possible to drag checkers from the bearoff tray. This must be corrected in 
     * the pick-up code - this proc should be ready for it.
     *
     * Nis Jorgensen, 2004-06-17
     */
	
    int hitCheckers [ 4 ] = {0, 0, 0, 0};
    int unhitCheckers [ 4 ] = {0, 0, 0, 0};
    int bar, hit = 0;
    bool placed = TRUE;
    int unhit = 0;
    int oldpoints[ 28 ];
    int passpoint;
    int source, dest2, i;
	
    /* dest2 is the destination point used  for numerical calculations */
    dest2 = dest;
	
    source = bd->drag_point;
	
	
    /* This is the opponents bar point */
    bar = bd->drag_colour == bd->colour ? 25 - bd->bar : bd->bar;
    
	
    if( dest == -1 || ( bd->drag_colour > 0 ? bd->points[ dest ] < -1
					   : bd->points[ dest ] > 1 ) || dest == bar ||
	   dest > 27 ) {
		placed = FALSE;
		dest = dest2 = source;
    } else if( dest >= 26 ) {
		/* bearing off */
		dest = bd->drag_colour > 0 ? 26 : 27;
        dest2 = bd->drag_colour > 0 ? 0 : 25;
    }
	
	
    /* Check for hits, undoing hits, including pick-and pass */
	
	
    if ( (source - dest2) * bd->drag_colour > 0 ) /*We are moving forward */ 
	{ 
        if( bd->points[ dest ] == -bd->drag_colour ) {
			/* outputf ("Hitting on %d \n", dest); */
			hit++;
			hitCheckers[ 0 ] = dest;
			bd->points[ dest ] = 0;
			bd->points[ bar ] -= bd->drag_colour;
//			board_invalidate_point( bd, bar );
        }
		
        if ( bd->diceRoll[0] == bd->diceRoll[1] ) {
            for (i = 1; i <= 3; i++) {
				passpoint = source - i * bd->diceRoll[0] * bd->drag_colour;
				if ((dest2 - passpoint) * bd->drag_colour >= 0 ) break;
				if (bd->points[ passpoint ] == -bd->drag_colour) {
					hit++;
					hitCheckers[ i ] = passpoint;
					bd->points[ passpoint ] += bd->drag_colour;
					bd->points[ bar ] -= bd->drag_colour;
//					board_invalidate_point( bd, bar );
//					board_invalidate_point( bd, passpoint );
				}
            }
        } else {
			if (ABS(source - dest2) == bd->diceRoll [ 0 ] + bd->diceRoll [ 1 ] || 
				(dest > 25 && ABS (source - dest2) > MAX(bd->diceRoll[ 0 ], bd->diceRoll[ 1 ]))
				) 
				for (i = 0; i < 2; i++) {
                    passpoint = source - bd->diceRoll[ i ] * bd->drag_colour;
                    if ((dest2 - passpoint) * bd->drag_colour >= 0 ) continue;
                    if (bd->points[ passpoint ] == - bd->drag_colour) {
                        hit++;
                        hitCheckers[ i + 1 ] = passpoint;
                        bd->points[ passpoint ] += bd->drag_colour;
                        bd->points[ bar ] -= bd->drag_colour;
//                        board_invalidate_point( bd, bar );
  //                      board_invalidate_point( bd, passpoint );
						
                        break;         
                    }
                }
        } 
    } else if  ( (source - dest2) * bd->drag_colour < 0 )  {
		
		/* 
		 * Check for taking chequer off point where we hit 
		 */
		
		/* check if the opponent had a chequer on the drag point (source),
		 and that it's not pick'n'pass */
		
        write_points(oldpoints,  bd->turn, bd->nchequers, bd->old_board );
		
        if ( oldpoints[ source ] == -bd->drag_colour ) { 
            unhit++;
            unhitCheckers[0] = source; 
            bd->points[ bar ] += bd->drag_colour;
   //         board_invalidate_point( bd, bar );
            bd->points[ source ] -= bd->drag_colour;
//            board_invalidate_point( bd, source );
        }
		
        if ( bd->diceRoll[0] == bd->diceRoll[1]) {
            /* Doubles are tricky - we can have pick-and-passed with 2 chequers */
            for (i = 1; i <= 3; i++) {
                passpoint = source +  i * bd->diceRoll[ 0 ] * bd->drag_colour;
                if ((dest2 - passpoint) * bd->drag_colour <= 0) break;
                if ( ( oldpoints[ passpoint ] ==  -bd->drag_colour ) && /*there was a blot */
					( bd->points[ passpoint ] == 0 ) && /* We actually did p&p */
					bd->points[ source ] == oldpoints [ source ] ) { /* We didn't p&p with a second checker */
					unhit++;
					unhitCheckers [ i ] = passpoint;
					bd->points[ bar ] += bd->drag_colour;
					bd->points[ passpoint ] -= bd->drag_colour;
//					board_invalidate_point( bd, bar );
//					board_invalidate_point( bd, passpoint );
                }
            }
        } else {
            for ( i = 0; i < 2; i++) {
                passpoint = source + bd->diceRoll[ i ] * bd->drag_colour;
                if ((dest2 - passpoint) * bd->drag_colour <= 0) continue;
                if ( ( oldpoints[ passpoint ] ==  -bd->drag_colour ) &&
					( bd->points[ passpoint ] == 0 ) ) {
                    unhit++;
                    unhitCheckers [ i + 1 ] = passpoint;
                    bd->points[ bar ] += bd->drag_colour;
//                    board_invalidate_point( bd, bar );
                    bd->points[ passpoint ] -= bd->drag_colour;
  //                  board_invalidate_point( bd, passpoint );
                }
            }
			
        }
		
    }
    
    bd->points[ dest ] += bd->drag_colour;
    //board_invalidate_point( bd, dest );
	
	
    if( source != dest ) { 
        if( update_move( bd ) ) {
			/* the move was illegal; undo it */
			bd->points[ source ] += bd->drag_colour;
	//		board_invalidate_point( bd, source );
            bd->points[ dest ] -= bd->drag_colour;
      //      board_invalidate_point( bd, dest );
			if( hit > 0 ) {
				bd->points[ bar ] += hit * bd->drag_colour;
//				board_invalidate_point( bd, bar );
                for (i = 0; i < 4; i++) 
                    if (hitCheckers[ i ] > 0) {
						bd->points[ hitCheckers[ i ] ] = -bd->drag_colour;
//						board_invalidate_point( bd, hitCheckers[ i ] );
                    }
			}
			
            if ( unhit > 0 ) {
				bd->points[ bar ] -= unhit * bd->drag_colour;
//				board_invalidate_point( bd, bar );
				for (i = 0; i < 4; i++) 
                    if (unhitCheckers[ i ] > 0) {
						bd->points[ unhitCheckers[ i ] ] += bd->drag_colour;
//						board_invalidate_point( bd, unhitCheckers[ i ] );
                    }
            }
			
			update_move( bd );
			placed = FALSE;
        }
    } 
	
//    board_invalidate_point( bd, placed ? dest : source );
	
    return placed;
}

/* CurrentPipCount: calculates pip counts for both players
 count for player 0 (colour == -1) is always in anPips[0],
 for player 1 (colour == 1) in anPips[1]
 assumes that a chequer has been picked up already from bd->drag_point,
 works on board representation in bd->points[] */
static bool CurrentPipCount( BoardData *bd, unsigned int anPips[ 2 ] )
{
	
	int i;
	
	anPips[ 0 ] = 0;
	anPips[ 1 ] = 0;
	
	for( i = 1; i < 25; i++ ) {
		if ( bd->points[ 25 - i ] < 0 )
			anPips[ 0 ] -= bd->points[ 25 - i ] * i;
		if ( bd->points[ i ] > 0 )
			anPips[ 1 ] += bd->points[ i ] * i;
	}
	/* bars */
	anPips[ 1 ] += bd->points[ 25 ] * 25;
	anPips[ 0 ] -= bd->points[ 0 ] * 25;
	/* add count for missing chequer */
	if ( bd->drag_point != -1 ) {
		if ( bd->drag_colour < 0 )
			anPips[ 0 ] += 25 - bd->drag_point;
		else
			anPips[ 1 ] += bd->drag_point;
	}
	
	return 0;
}

/* PointsAreEmpty: checks if there are chequers of player <iColour> between
 * two points */
static bool PointsAreEmpty( BoardData *bd, int iStartPoint, int iEndPoint, int
							   iColour )
{
	
	int i;
	
	if ( iColour > 0 ) {
		if ( iStartPoint > iEndPoint )
			swap( &iStartPoint, &iEndPoint );
		for ( i = iStartPoint; i <= iEndPoint; ++i )
			if ( bd->points[i] > 0 ) {
				return FALSE;
			}
	}
	else {
		if ( iStartPoint < iEndPoint )
			swap( &iStartPoint, &iEndPoint );
		for ( i = iStartPoint; i >= iEndPoint; --i )
			if ( bd->points[i] < 0 ) {
				return FALSE;
			}
	}
	return TRUE;
}

/* LegalDestPoints: determine destination points for one chequer
 assumes that a chequer has been picked up already from bd->drag_point,
 works on board representation in bd->points[],
 returns TRUE if there are possible moves and fills iDestPoints[] with
 the destination points or -1 */
bool LegalDestPoints( BoardData *bd, int iDestPoints[4] )
{
	
	int i;
	unsigned int anPipsBeforeMove[ 2 ];
	unsigned int anCurPipCount[ 2 ];
	int iCanMove = 0;		/* bits set => could make a move with this die */
	int iDestCount = 0;
	int iDestPt = -1;
	int iDestLegal = TRUE;
	int bar = bd->drag_colour == bd->colour ? bd->bar : 25 - bd->bar; /* determine point number of bar */
	
	if (bd->valid_move && bd->valid_move->cMoves == bd->move_list.cMaxMoves
		&& bd->valid_move->cPips == bd->move_list.cMaxPips)
		return FALSE;	/* Complete move already made */
	
	/* initialise */
	for (i = 0; i <= 3; ++i)
		iDestPoints[i] = -1;
	
	if ( ap[ bd->drag_colour == -1 ? 0 : 1 ].pt != PLAYER_HUMAN )
		return FALSE;
	
	/* pip count before move */
	PipCount( bd->old_board, anPipsBeforeMove );
	if ( bd->turn < 0 )
		swap_us( &anPipsBeforeMove[ 0 ], &anPipsBeforeMove[ 1 ] );
	
	/* current pip count */
	CurrentPipCount( bd, anCurPipCount );
	
	if ( bd->diceRoll[0] == bd->diceRoll[1] ) {
		/* double roll: up to 4 possibilities to move, but only in multiples of dice[0] */
		for ( i = 0; i <= 3; ++i ) {
			if ( ( (i + 1) * bd->diceRoll[0] > anCurPipCount[ bd->drag_colour == -1 ? 0 : 1 ] - anPipsBeforeMove[ bd->drag_colour == -1 ? 0 : 1 ] + bd->move_list.cMaxPips )	/* no moves left*/
				|| ( i && bd->points[ bar ] ) )		/* moving with chequer just entered not allowed if more chequers on the bar */
				break;
			iDestLegal = TRUE;
			if ( !i || iCanMove & ( 1 << ( i - 1 ) ) ) {
				/* only if moving first chequer or if last part-move succeeded */
				iDestPt = bd->drag_point - bd->diceRoll[0] * ( i + 1 ) * bd->drag_colour;
				if( ( iDestPt <= 0 ) || ( iDestPt >= 25 ) ) {
					/* bearing off */
					/* all chequers in home board? */
					if ( bd->drag_colour > 0 ) {
						if ( ! PointsAreEmpty( bd, 7, 25, bd->drag_colour ) ) {
							iDestPt = -1;
							iDestLegal = FALSE;
						}
					}
					else {
						if ( ! PointsAreEmpty( bd, 18, 0, bd->drag_colour ) ) {
							iDestPt = -1;
							iDestLegal = FALSE;
						}
					}
					if ( iDestLegal && ( (iDestPt < 0 ) || (iDestPt > 25 ) ) ) {
						/* bearing off with roll bigger than point */
						if ( iCanMove ) {
							/* prevent bearoff in more than 1 move if there are still chequers on points bigger than destination of the part-move before */
							if ( bd->drag_colour > 0 ) {
								if ( ! PointsAreEmpty( bd, bd->drag_point - i * bd->diceRoll[0] + 1, 6, bd->drag_colour ) ) {
									iDestPt = -1;
									iDestLegal = FALSE;
								}
							}
							else {
								if ( ! PointsAreEmpty( bd, bd->drag_point + i * bd->diceRoll[0] - 1, 19, bd->drag_colour ) ) {
									iDestPt = -1;
									iDestLegal = FALSE;
								}
							}
						}
						/* chequers on higher points? */
						if ( bd->drag_colour > 0 ) {
							if ( ! PointsAreEmpty( bd, bd->drag_point + 1, 6, bd->drag_colour ) ) {
								iDestPt = -1;
								iDestLegal = FALSE;
							}
						}
						else {
							if ( ! PointsAreEmpty( bd, bd->drag_point - 1, 19, bd->drag_colour ) ) {
								iDestPt = -1;
								iDestLegal = FALSE;
							}
						}
					}
					if ( iDestLegal ) {
						iDestPt = bd->drag_colour > 0 ? 26 : 27;
					}
					else {
						iDestPt = -1;
					}
				}
			}
			else {
				iDestPt = -1;
				iDestLegal = FALSE;
				break;
			}
			
			/* check if destination (il)legal */
			if ( !iDestLegal
			    || ( iDestPt == -1 ) || ( iDestPt > 27 )			/* illegal points */
			    || ( bd->drag_colour > 0 ? bd->points[ iDestPt ] < -1
					: bd->points[ iDestPt ] > 1 )		/* blocked by opponent*/
			    || ( iDestPt == bar )					/* bar */
			    || ( ( bd->drag_colour > 0 ? bd->points[ bar ] > 0
					  : bd->points[ bar ] < 0 )	/* when on bar ... */
					&& ( bd->drag_point != bar ) )				/* ... not playing from bar */
				)
			{
				iDestPoints[ iDestCount ] = -1;
			}
			else {		/* legal move */
				iCanMove |= ( 1 << i );		/* set flag that this move could be made */
				iDestPoints[ iDestCount++ ] = iDestPt;
				iDestPt = -1;
			}
		}
	}
	else {
		/* normal roll: up to 3 possibilities */
		unsigned int iUnusedPips = anCurPipCount[ bd->drag_colour == -1 ? 0 : 1 ] - anPipsBeforeMove[ bd->drag_colour == -1 ? 0 : 1 ] + bd->move_list.cMaxPips;
		for ( i = 0; i <= 1; ++i ) {
			if (
				/* not possible to move with this die (anymore) */
				(iUnusedPips < bd->diceRoll[i]) ||
				/* this die has been used already */
				((bd->valid_move) && ((int)bd->diceRoll[i] == (bd->valid_move->anMove[0] - bd->valid_move->anMove[1]))) ||
				/* move already completed */
				((bd->valid_move) && (bd->valid_move->cMoves > 1))
				)
				continue;
			iDestLegal = TRUE;
			iDestPt = bd->drag_point - bd->diceRoll[i] * bd->drag_colour;
			if( ( iDestPt <= 0 ) || ( iDestPt >= 25 ) ) {
				/* bearing off */
				/* all chequers in home board? */
				if ( bd->drag_colour > 0 ) {
					if ( ! PointsAreEmpty( bd, 7, 25, bd->drag_colour ) ) {
						iDestPt = -1;
						iDestLegal = FALSE;
					}
				}
				else {
					if ( ! PointsAreEmpty( bd, 18, 0, bd->drag_colour ) ) {
						iDestPt = -1;
						iDestLegal = FALSE;
					}
				}
				if ( ( iDestLegal ) && ( (iDestPt < 0 ) || (iDestPt > 25 ) ) ) {
					/* bearing off with roll bigger than point */
					if ( bd->drag_colour > 0 ) {
						if ( ! PointsAreEmpty( bd, bd->drag_point + 1, 6, bd->drag_colour ) ) {
							iDestPt = -1;
							iDestLegal = FALSE;
						}
					}
					else {
						if ( ! PointsAreEmpty( bd, bd->drag_point - 1, 19, bd->drag_colour ) ) {
							iDestPt = -1;
							iDestLegal = FALSE;
						}
					}
				}
				if ( iDestLegal ) {
					iDestPt = bd->drag_colour > 0 ? 26 : 27;
				}
				else {
					iDestPt = -1;
				}
			}
			/* check if destination (il)legal */
			if ( !iDestLegal
			    || ( iDestPt == -1 ) || ( iDestPt > 27 )			/* illegal points */
			    || ( bd->drag_colour > 0 ? bd->points[ iDestPt ] < -1
					: bd->points[ iDestPt ] > 1 )		/* blocked by opponent*/
			    || ( iDestPt == bar )					/* bar */
			    || ( ( bd->drag_colour > 0 ? bd->points[ bar ] > 0
					  : bd->points[ bar ] < 0 )	/* when on bar ... */
					&& ( bd->drag_point != bar ) )				/* ... not playing from bar */
				)
			{
				iDestPoints[ iDestCount ] = -1;
			}
			else {		/* legal move */
				iCanMove |= ( 1 << i );		/* set flag that this move could be made */
				iDestPoints[ iDestCount++ ] = iDestPt;
				iDestPt = -1;
			}
		}
		/* check for moving twice with same chequer */
		if ( iCanMove &&				/* only if at least one first half-move could be made, */
			( bd->move_list.cMaxMoves > 1 ) &&		/* there is a legal move with 2 half-moves, */
			( anCurPipCount[ bd->drag_colour == -1 ? 0 : 1 ] == anPipsBeforeMove[ bd->drag_colour == -1 ? 0 : 1 ] ) &&		/* we didn't move yet, */
			( ! bd->points[ bar ] ) )			/* and don't have any more chequers on the bar */
		{
			iDestLegal = TRUE;
			iDestPt = bd->drag_point - ( bd->diceRoll[0] + bd->diceRoll[1] ) * bd->drag_colour;
			if( ( iDestPt <= 0 ) || ( iDestPt >= 25 ) ) {
				/* bearing off */
				/* all chequers in home board? */
				if ( bd->drag_colour > 0 ) {
					if ( ! PointsAreEmpty( bd, 7, 25, bd->drag_colour ) ) {
						iDestPt = -1;
						iDestLegal = FALSE;
					}
				}
				else {
					if ( ! PointsAreEmpty( bd, 18, 0, bd->drag_colour ) ) {
						iDestPt = -1;
						iDestLegal = FALSE;
					}
				}
				if ( iDestLegal && ( (iDestPt < 0 ) || (iDestPt > 25 ) ) ) {
					/* bearing off with roll bigger than point */
					/* prevent bearoff in more than 1 move if there are still chequers on points bigger than destination of first half-move */
					if ( bd->drag_colour > 0 ) {
						if ( ! PointsAreEmpty( bd, bd->drag_point - ( bd->diceRoll[0] < bd->diceRoll[1] ? bd->diceRoll[0] : bd->diceRoll[1] ) + 1, 6, bd->drag_colour ) ) {
							iDestPt = -1;
							iDestLegal = FALSE;
						}
					}
					else {
						if ( ! PointsAreEmpty( bd, bd->drag_point + ( bd->diceRoll[0] < bd->diceRoll[1] ? bd->diceRoll[0] : bd->diceRoll[1] ) - 1, 19, bd->drag_colour ) ) {
							iDestPt = -1;
							iDestLegal = FALSE;
						}
					}
				}
				if ( iDestLegal ) {
					iDestPt = bd->drag_colour > 0 ? 26 : 27;
				}
				else {
					iDestPt = -1;
				}
			}
			
			/* check if destination (il)legal */
			if ( !iDestLegal
			    || ( iDestPt == -1 ) || ( iDestPt > 27 )			/* illegal points */
			    || ( bd->drag_colour > 0 ? bd->points[ iDestPt ] < -1
					: bd->points[ iDestPt ] > 1 )		/* blocked by opponent*/
			    || ( iDestPt == bar )					/* bar */
			    || ( ( bd->drag_colour > 0 ? bd->points[ bar ] > 0
					  : bd->points[ bar ] < 0 )	/* when on bar ... */
					&& ( bd->drag_point != bar ) )				/* ... not playing from bar */
				)
			{
				iDestPoints[ iDestCount ] = -1;
			}
			else {		/* legal move */
				iDestPoints[ iDestCount++ ] = iDestPt;
				iDestPt = -1;
			}
		}
	}
	
	return iDestCount ? TRUE : FALSE;
}

static void board_start_drag( BoardData *bd, int drag_point, int x, int y )
{
	
    bd->drag_point = drag_point;
    bd->drag_colour = bd->points[ drag_point ] < 0 ? -1 : 1;
	
    bd->points[ drag_point ] -= bd->drag_colour;
	
	bd->x_drag = x;
	bd->y_drag = y;

	// Decide if drag targets should be shown
	if (fGUIDragTargetHelp && !bd->DragTargetHelp && drag_point < 26)
	{
		if (ap[bd->drag_colour == -1 ? 0 : 1].pt == PLAYER_HUMAN)		// not for computer turn
		{
			bd->DragTargetHelp = LegalDestPoints(bd, bd->iTargetHelpPoints);
		}
	}

	bgSetNeedsDisplay();
}

static int ForcedMove ( TanBoard anBoard, unsigned int anDice[ 2 ] )
{
	movelist ml;
	
	GenerateMoves ( &ml, anBoard, anDice[ 0 ], anDice[ 1 ], FALSE );
	
	if ( ml.cMoves == 1 )
	{
		ApplyMove ( anBoard, ml.amMoves[ 0 ].anMove, TRUE );
		return TRUE;
	}
	else
		return FALSE;
}

static int GreadyBearoff ( TanBoard anBoard, unsigned int anDice[ 2 ] )
{
	movelist ml;
	unsigned int i, iMove, cMoves;
	
	/* check for all chequers inside home quadrant */
	
	for ( i = 6; i < 25; ++i )
		if ( anBoard[ 1 ][ i ] )
			return FALSE;
	
	cMoves = ( anDice[ 0 ] == anDice[ 1 ] ) ? 4 : 2;
	
	GenerateMoves( &ml, anBoard, anDice[ 0 ], anDice[ 1 ], FALSE );
	
	for( i = 0; i < ml.cMoves; i++ )
		for( iMove = 0; iMove < cMoves; iMove++ )
			if( ( ml.amMoves[ i ].anMove[ iMove << 1 ] < 0 ) ||
			   ( ml.amMoves[ i ].anMove[ ( iMove << 1 ) + 1 ] != -1 ) )
			/* not a bearoff move */
				break;
			else if( iMove == cMoves - 1 ) {
				/* All dice bear off */
				ApplyMove ( anBoard, ml.amMoves[ i ].anMove, TRUE );
				return TRUE;
			}
	
	return FALSE;
}

extern int UpdateMove( BoardData *bd, TanBoard anBoard )
{
	int old_points[ 28 ];
	int i, j;
	int an[ 28 ];
	int rc;
	
	memcpy( old_points, bd->points, sizeof old_points );
	
	write_board ( bd, anBoard );
	
	for ( i = 0, j = 0; i < 28; ++i )
		if ( old_points[ i ] != bd->points[ i ] )
			an[ j++ ] = i;
	
    // illegal move
	if ( ( rc = update_move ( bd ) ) )
		memcpy( bd->points, old_points, sizeof old_points );
	
	// Show move
	[gView setNeedsDisplay];
	
	return rc;
}

extern bool Confirm( BoardData *bd )
{
    char move[ 40 ];
    TanBoard points;
    
    read_board( bd, points );
	
    if( !bd->move_list.cMoves && EqualBoards( points, bd->old_board ) )
		UserCommand( "move" );
    else if( bd->valid_move &&
			bd->valid_move->cMoves == bd->move_list.cMaxMoves &&
			bd->valid_move->cPips == bd->move_list.cMaxPips ) {
        FormatMovePlain( move, bd->old_board, bd->valid_move->anMove );
		
        UserCommand( move );
    }
	else
	{
	/* Illegal move */
		board_beep( bd );
		return false;
	}
	return true;
}

unsigned int convert_point( int i, int player )
{
    if( player )
		return ( i < 0 ) ? 26 : i + 1;
    else
		return ( i < 0 ) ? 27 : 24 - i;
}

bool move_to_make_point(BoardData* bd, int point, bool apply)
{
	int numOnPoint = bd->points[point];
	
	if (point > 24 || (numOnPoint != 0 && numOnPoint != -bd->turn))
		return false;

	int bar;
	int old_points[ 28 ];
	TanBoard points;
	unsigned char key[ 10 ];

	memcpy(old_points, bd->points, sizeof old_points);

	bd->drag_colour = bd->turn;
	bar = bd->drag_colour == bd->colour ? 25 - bd->bar : bd->bar;

	int moves[8][9];
	int nmoves;

	if (bd->diceRoll[0] == bd->diceRoll[1])
	{
		int src[4];
		src[0] = point + 1 * bd->diceRoll[0] * bd->drag_colour;
		src[1] = point + 2 * bd->diceRoll[0] * bd->drag_colour;
		src[2] = point + 3 * bd->diceRoll[0] * bd->drag_colour;
		src[3] = point + 4 * bd->diceRoll[0] * bd->drag_colour;

		moves[0][0] = src[0];
		moves[0][1] = point;
		moves[0][2] = src[0];
		moves[0][3] = point;
		moves[0][4] = -1;

		moves[1][0] = src[1];
		moves[1][1] = src[0];
		moves[1][2] = src[0];
		moves[1][3] = point;
		moves[1][4] = src[0];
		moves[1][5] = point;
		moves[1][6] = -1;

		moves[2][0] = src[1];
		moves[2][1] = src[0];
		moves[2][2] = src[0];
		moves[2][3] = point;
		moves[2][4] = src[1];
		moves[2][5] = src[0];
		moves[2][6] = src[0];
		moves[2][7] = point;
		moves[2][8] = -1;

		moves[3][0] = src[2];
		moves[3][1] = src[1];
		moves[3][2] = src[1];
		moves[3][3] = src[0];
		moves[3][4] = src[0];
		moves[3][5] = point;
		moves[3][6] = src[0];
		moves[3][7] = point;
		moves[3][8] = -1;

		moves[4][0] = src[0];
		moves[4][1] = point;
		moves[4][2] = -1;
		
		moves[5][0] = src[1];
		moves[5][1] = src[0];
		moves[5][2] = src[0];
		moves[5][3] = point;
		moves[5][4] = -1;

		moves[6][0] = src[2];
		moves[6][1] = src[1];
		moves[6][2] = src[1];
		moves[6][3] = src[0];
		moves[6][4] = src[0];
		moves[6][5] = point;
		moves[6][6] = -1;

		moves[7][0] = src[3];
		moves[7][1] = src[2];
		moves[7][2] = src[2];
		moves[7][3] = src[1];
		moves[7][4] = src[1];
		moves[7][5] = src[0];
		moves[7][6] = src[0];
		moves[7][7] = point;
		moves[7][8] = -1;

		nmoves = 8;
	}
	else
	{
		int src[3];
		src[0] = point + bd->diceRoll[0] * bd->drag_colour;
		src[1] = point + bd->diceRoll[1] * bd->drag_colour;
		src[2] = point + (bd->diceRoll[0] + bd->diceRoll[1]) * bd->drag_colour;

		moves[0][0] = src[0];
		moves[0][1] = point;
		moves[0][2] = src[1];
		moves[0][3] = point;
		moves[0][4] = -1;

		moves[1][0] = src[0];
		moves[1][1] = point;
		moves[1][2] = -1;

		moves[2][0] = src[1];
		moves[2][1] = point;
		moves[2][2] = -1;

		moves[3][0] = src[2];
		moves[3][1] = src[1];
		moves[3][2] = src[1];
		moves[3][3] = point;
		moves[3][4] = -1;

		moves[4][0] = src[2];
		moves[4][1] = src[0];
		moves[4][2] = src[0];
		moves[4][3] = point;
		moves[4][4] = -1;

		nmoves = 5;
	}

	for (int i = 0; i < nmoves; i++)
	{
		int* m = moves[i];

		while (*m != -1)
		{
			int s = m[0];
			int d = m[1];

			if (s < 0 || s > 25 || bd->points[s] * bd->drag_colour <= 0)
				break;
			
			if (bd->points[d] != 0 && ABS(bd->points[d]) != 1)
				break;

			if (bd->points[d] == -bd->turn)
			{
				// hitting the opponent in the process
				bd->points[bar] -= bd->drag_colour;
				bd->points[d] = 0;
			}

			bd->points[s] -= bd->drag_colour;
			bd->points[d] += bd->drag_colour;

			m += 2;
		}

		if (*m == -1)
		{
			read_board(bd, points);
			PositionKey(points, key);
			
			if (!update_move(bd))
			{
				if (apply)
				{
					// Show Move
					bgSetNeedsDisplay();
					playSound(SOUND_CHEQUER);
				}
				else
				{
					memcpy(bd->points, old_points, sizeof bd->points);
					update_move( bd );
				}

				return true;
			}
		}

		// the move wasn't legal; undo it.
		memcpy(bd->points, old_points, sizeof bd->points);
	}

	update_move( bd );
	board_beep( bd );

	return false;
}

int viewInit;

@implementation bgView

@synthesize dlgLayer, animLayer, msgLayer, glowLayer;
@synthesize spinner;

- (id)initWithCoder:(NSCoder*)coder
{
	if (!viewInit)
	{
		CFBundleRef mainBundle = CFBundleGetMainBundle();
		CFURLRef url = CFBundleCopyBundleURL(mainBundle);
		CFURLGetFileSystemRepresentation(url, YES, (UInt8*)PKGDATADIR, 1024);
		CFRelease(url);

		pwBoard = new BoardData;
		BoardData* bd = pwBoard;

		for (int i = 0; i < 4; i++)
			bd->iTargetHelpPoints[i] = -1;
		
		bd->clockwise = fClockwise;
		bd->drag_point = -1;
		
		bd->crawford_game = FALSE;
		bd->playing = FALSE;
		bd->cube_use = TRUE;    
		bd->all_moves = NULL;
		
		bd->x_dice[0] = bd->x_dice[1] = -10;    
		bd->diceRoll[0] = bd->diceRoll[1] = 0;
		
		bd->crawford_game = 0;
		bd->cube_use = 0;
		bd->doubled = 0;
		bd->cube_owner = 0;
		bd->resigned = 0;
		bd->diceShown = DICE_NOT_SHOWN;
		
		bd->x_dice[ 0 ] = bd->y_dice[ 0 ] = 0;
		bd->x_dice[ 1 ] = bd->y_dice[ 1 ] = 0;

		int ip[] = {0,-2,0,0,0,0,5,0,3,0,0,0,-5,5,0,0,0,-3,0,-5,0,0,0,0,2,0,0,0};
		memcpy(bd->points, ip, sizeof(bd->points));
	}

	if ((self = [super initWithCoder:coder]))
	{
#ifndef PBG_HD
//		CGAffineTransform transform = CGAffineTransformMakeRotation(M_PI/2);
//		self.transform = transform;
//		self.bounds = CGRectMake(0, 0, gBoardSize.Width, gBoardSize.Height);
#endif
		CALayer* root = self.layer;

		glowLayer = [CALayer layer];
		glowLayer.hidden = YES;
		[root addSublayer:glowLayer];
		
		animLayer = [CALayer layer];
		animLayer.opacity = 1.0;
		animLayer.hidden = YES;
		[root addSublayer:animLayer];

		msgLayer = [CALayer layer];
		msgLayer.hidden = YES;
		[root addSublayer:msgLayer];

		dlgLayer = [CALayer layer];
		dlgLayer.hidden = YES;
		[root addSublayer:dlgLayer];

		spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
		[spinner setCenter:CGPointMake(240, 110)];
		[self addSubview:spinner];
	}

	gView = self;
	fX = 1;

	if (!viewInit)
	{
		gnubg_main();
		outputoff();
		SetDefaultDifficulty();
		outputon();

		char buf[1024];
		NSArray* Paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		NSString* DocDir = [Paths objectAtIndex:0];

		outputoff();
		sprintf(buf, "load commands \"%s/bgautorc\"", [DocDir cStringUsingEncoding:NSUTF8StringEncoding]);
		UserCommand(buf);
		outputon();

		sprintf(buf, "load match \"%s/autosave.sgf\"", [DocDir cStringUsingEncoding:NSUTF8StringEncoding]);
		UserCommand(buf);
		ShowBoard();

		NSString* FilePath = [DocDir stringByAppendingPathComponent:@"autosave.sgf"];
		NSFileManager* FileManager = [NSFileManager defaultManager];
		[FileManager removeItemAtPath:FilePath error:NULL];

		extern int fLastMove;
		fLastMove = 0;

		viewInit = true;
	}

	[self UpdateCheckerImages];
	
	bgDlgShow(BG_DLG_MAIN_MENU, ms.gs != GAME_PLAYING);

    return self;
}

- (void)dealloc
{
	CGContextRelease(cgContext);

	CGImageRelease(boardImage);
	CGImageRelease(whiteImage);
	CGImageRelease(blackImage);

    [super dealloc];
}

- (void) SetBoardSize
{
#if PBG_HD
	BOARD_WIDTH = self.bounds.size.width;
	BOARD_HEIGHT = self.bounds.size.height;
	POINT_WIDTH = BOARD_WIDTH / 15;
	POINT_HEIGHT = 240;
	BORDER_WIDTH = POINT_WIDTH / 3;
	BORDER_TOP_HEIGHT = 70;
	BORDER_BOTTOM_HEIGHT = 20;
	BAR_WIDTH = POINT_WIDTH;
	BAR_OFFSET = 30;
	BEAROFF_X = (2*BORDER_WIDTH+BAR_WIDTH+12*POINT_WIDTH);
	CHEQUER_HEIGHT = 48;
	CHEQUER_RADIUS = 24;
	DICE_SIZE = 48;
#else
	float Width = self.bounds.size.width;
	float Height = self.bounds.size.height;
	bgBoardUpdateSize(&gBoardSize, Width, Height);
	gBoardScale = 1.0f;

	if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)])
	{
		float scale = [[UIScreen mainScreen] scale];
		gBoardScale = scale;

		Width *= scale;
		Height *= scale;
	}
#endif

	bgBoardUpdateSize(&gBoardSizeScaled, Width, Height);
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	
	// Create the offscreen context.
	cgContext = CGBitmapContextCreate(NULL, Width, Height, 8, 4 * Width, colorSpace, kCGImageAlphaPremultipliedFirst);
	
	// Draw board.
	bgDrawBoard(&gBoardSizeScaled, cgContext);
	boardImage = CGBitmapContextCreateImage(cgContext);

	CGColorSpaceRelease(colorSpace);
}

- (void) UpdateBoardImage
{
	bgDrawBoard(&gBoardSizeScaled, cgContext);
	boardImage = CGBitmapContextCreateImage(cgContext);
}

- (void) UpdateCheckerImages
{
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	float ChequerRadius = gBoardSizeScaled.ChequerRadius;

	int size = 2 * (ChequerRadius + 2);
	CGContextRef context = CGBitmapContextCreate(NULL, size, size, 8, 4 * size, colorSpace, kCGImageAlphaPremultipliedFirst);
	
	CGContextSetRGBFillColor(context, Player1Color[0], Player1Color[1], Player1Color[2], Player1Color[3]);
	CGContextBeginPath(context);
	CGContextAddArc(context, ChequerRadius + 2, ChequerRadius + 2, ChequerRadius, 0.0, 2*M_PI, 1);
	CGContextDrawPath(context, kCGPathFillStroke);
	whiteImage = CGBitmapContextCreateImage(context);
	
	CGContextSetRGBFillColor(context, Player2Color[0], Player2Color[1], Player2Color[2], Player2Color[3]);
	CGContextBeginPath(context);
	CGContextAddArc(context, ChequerRadius + 2, ChequerRadius + 2, ChequerRadius, 0.0, 2*M_PI, 1);
	CGContextDrawPath(context, kCGPathFillStroke);
	blackImage = CGBitmapContextCreateImage(context);
	
	CGContextRelease(context);
	CGColorSpaceRelease(colorSpace);
}

- (void) setFrame:(CGRect)frame
{
	[super setFrame:frame];
	
	[self SetBoardSize];
	bgDlgSetSize(dlgLayer, frame.size.width, frame.size.height);
}

- (void)drawRect:(CGRect)rect
{
	CGRect				bounds = CGRectMake(0, 0, gBoardSizeScaled.Width, gBoardSizeScaled.Height);
	CGContextRef		context = UIGraphicsGetCurrentContext();
	CGImageRef			image;

	BoardData* bd = pwBoard;
	CGPoint pt;

	// Draw board.
	CGContextSetRGBStrokeColor(cgContext, 0, 0, 0, 1);

	CGContextDrawImage(cgContext, bounds, boardImage);

	bgDrawChequers(&gBoardSizeScaled, cgContext, pwBoard, whiteImage, blackImage);

	// Display 2d drag target help
	if (bd->DragTargetHelp)
	{
		CGContextSetRGBFillColor(cgContext, 0.0, 1.0, 0.0, 1.0);

		for (int i = 0; i < 4; i++)
		{
			if (bd->iTargetHelpPoints[i] == -1 )
				continue;

			bgDrawMark(&gBoardSizeScaled, cgContext, bd->iTargetHelpPoints[i]);
		}
	}

	if (bd->drag_point != -1)
	{
		CGContextSetRGBFillColor(cgContext, 0.0, 0.0, 0.0, 1.0);
		bgDrawMark(&gBoardSizeScaled, cgContext, bd->drag_point);
	}

	if (tracking_type == BG_TRACK_TAKE)
	{
		int old_points[ 28 ];
		
		CGContextSetRGBFillColor(cgContext, 0.0, 0.0, 0.0, 1.0);

		memcpy(old_points, bd->points, sizeof old_points);
		if (move_to_make_point(bd, bd->drag_point, true))
		{
			for (int i = 0; i < 28; i++)
				if (old_points[i] != bd->points[i])
					bgDrawMark(&gBoardSizeScaled, cgContext, i);
		}
		memcpy(bd->points, old_points, sizeof old_points);
		update_move( bd );

		CGContextSetRGBFillColor(cgContext, 0.0, 1.0, 0.0, 1.0);
		bgDrawMark(&gBoardSizeScaled, cgContext, bd->drag_point);
	}

	float Height = gBoardSizeScaled.Height;
	float PointWidth = gBoardSizeScaled.PointWidth;
	float PointHeight = gBoardSizeScaled.PointHeight;
	float BorderWidth = gBoardSizeScaled.BorderWidth;
	float BorderBottomHeight = gBoardSizeScaled.BorderBottomHeight;
	float BorderTopHeight = gBoardSizeScaled.BorderTopHeight;
	float BarWidth = gBoardSizeScaled.BarWidth;
	float DiceSize = gBoardSizeScaled.DiceSize;

	int Offset = fClockwise ? PointWidth + BorderWidth : 0;

	// Dice.
	if (bd->diceShown == DICE_ON_BOARD)
	{
		CGPoint pt;
		pt.x = (bd->colour == bd->turn) ? BorderWidth + 8 * PointWidth + BarWidth : BorderWidth + 2 * PointWidth;
		pt.x += Offset;
		pt.y = Height / 2;

		int used[2] = { 0, 0 };
		int num_used = 0;

		if (bd->valid_move)
		{
			int* move = bd->valid_move->anMove;
			for (int i = 0; i < 4; i++)
			{
				if (move[i*2] == -1)
					break;

				int pips = ABS(move[i*2] - move[i*2+1]);

				if (pips == bd->diceRoll[0])
				{
					if (!used[0])
						used[0] = 1;
					else
						used[1] = 1;
				}
				else if (pips == bd->diceRoll[1])
				{
					if (!used[1])
						used[1] = 1;
					else
						used[0] = 1;
				}
				else if ((bd->diceRoll[0] > bd->diceRoll[1] && !used[0]) || used[1])
					used[0] = 1;
				else
					used[1] = 1;

				num_used++;
			}

			// Undo.
			{
				CGContextSelectFont(cgContext, "Helvetica", 12 * gBoardScale, kCGEncodingMacRoman);
				CGContextSetTextMatrix(cgContext, CGAffineTransformMake(1.0,0.0, 0.0, -1.0, 0.0, 0.0));
				CGContextSetRGBFillColor(cgContext, 1.0, 1.0, 1.0, 1.0);
				
				CGPoint pt2;
				pt2.x = (bd->colour != bd->turn) ? BorderWidth + 8 * PointWidth + BarWidth : BorderWidth + 2 * PointWidth;
				pt2.x = pt2.x + PointWidth + Offset;
				pt2.y = pt.y - 8 * gBoardScale;
				const char* Text = "Tap here to undo";

				CGContextShowTextAtPointCentered(cgContext, pt2.x, pt2.y + 12 * gBoardScale, Text, strlen(Text));
			}
		}
		else
		{
			CGContextSelectFont(cgContext, "Helvetica", 12 * gBoardScale, kCGEncodingMacRoman);
			CGContextSetTextMatrix(cgContext, CGAffineTransformMake(1.0,0.0, 0.0, -1.0, 0.0, 0.0));
			CGContextSetRGBFillColor(cgContext, 1.0, 1.0, 1.0, 1.0);
			
			CGPoint pt2;
			pt2.x = (bd->colour != bd->turn) ? BorderWidth + 8 * PointWidth + BarWidth : BorderWidth + 2 * PointWidth;
			pt2.x = pt2.x + PointWidth + Offset;
			pt2.y = pt.y - 8 * gBoardScale;
			const char* Text = "Tap here for hint";

			if (ap[ms.fTurn].pt == PLAYER_HUMAN && !BoardAnimating)
				CGContextShowTextAtPointCentered(cgContext, pt2.x, pt2.y + 12 * gBoardScale, Text, strlen(Text));
		}

		if (bd->valid_move && bd->valid_move->cPips == bd->move_list.cMaxPips)
		{
			CGContextSelectFont(cgContext, "Helvetica", 12 * gBoardScale, kCGEncodingMacRoman);
			CGContextSetTextMatrix(cgContext, CGAffineTransformMake(1.0,0.0, 0.0, -1.0, 0.0, 0.0));
			CGContextSetRGBFillColor(cgContext, 1.0, 1.0, 1.0, 1.0);

			CGPoint pt2 = CGPointMake(pt.x + PointWidth, pt.y + gBoardSizeScaled.DiceSize / 2);
			const char* Text = "Tap dice to end turn";

			CGContextShowTextAtPointCentered(cgContext, pt2.x, pt2.y + 12 * gBoardScale, Text, strlen(Text));
		}

		float* DiceColor;
		if (bd->colour == bd->turn)
			DiceColor = Player2Color;
		else
			DiceColor = Player1Color;
		float UsedColor[4] = { DiceColor[0] * 0.25 + 0.25, DiceColor[1] * 0.25 + 0.25, DiceColor[2] * 0.25 + 0.25, DiceColor[3] };

		for (int i = 0; i < 2; i++)
		{
			CGRect rect = CGRectMake(pt.x - gBoardSizeScaled.DiceSize / 2, pt.y - gBoardSizeScaled.DiceSize / 2, gBoardSizeScaled.DiceSize, gBoardSizeScaled.DiceSize);

			float corner_radius = gBoardSizeScaled.DiceSize / 10;
			float x_left = rect.origin.x;
			float x_left_center = rect.origin.x + corner_radius;
			float x_right_center = rect.origin.x + rect.size.width - corner_radius;
			float x_right = rect.origin.x + rect.size.width;
			float y_top = rect.origin.y;
			float y_top_center = rect.origin.y + corner_radius;
			float y_bottom_center = rect.origin.y + rect.size.height - corner_radius;
			float y_bottom = rect.origin.y + rect.size.height;
			float y_center = rect.origin.y + rect.size.height / 2;
			
			if (bd->diceRoll[0] == bd->diceRoll[1])
			{
				if (num_used > i * 2)
					CGContextSetRGBFillColor(cgContext, UsedColor[0], UsedColor[1], UsedColor[2], UsedColor[3]);
				else
					CGContextSetRGBFillColor(cgContext, DiceColor[0], DiceColor[1], DiceColor[2], DiceColor[3]);

				CGContextBeginPath(cgContext);
				CGContextMoveToPoint(cgContext, x_left, y_top_center);
				
				CGContextAddLineToPoint(cgContext, x_left_center, y_top);
				CGContextAddLineToPoint(cgContext, x_right_center, y_top);
				CGContextAddLineToPoint(cgContext, x_right, y_top_center);
				CGContextAddLineToPoint(cgContext, x_right, y_center);
				CGContextAddLineToPoint(cgContext, x_left, y_center);
				
				CGContextClosePath(cgContext);
				CGContextDrawPath(cgContext, kCGPathFill);

				if (num_used > i * 2 + 1)
					CGContextSetRGBFillColor(cgContext, UsedColor[0], UsedColor[1], UsedColor[2], UsedColor[3]);
				else
					CGContextSetRGBFillColor(cgContext, DiceColor[0], DiceColor[1], DiceColor[2], DiceColor[3]);
				
				CGContextBeginPath(cgContext);
				CGContextMoveToPoint(cgContext, x_right, y_center);
				
				CGContextAddLineToPoint(cgContext, x_right, y_bottom_center);
				CGContextAddLineToPoint(cgContext, x_right_center, y_bottom);
				CGContextAddLineToPoint(cgContext, x_left_center, y_bottom);
				CGContextAddLineToPoint(cgContext, x_left, y_bottom_center);
				CGContextAddLineToPoint(cgContext, x_left, y_center);
				
				CGContextClosePath(cgContext);
				CGContextDrawPath(cgContext, kCGPathFill);

				CGContextBeginPath(cgContext);
				CGContextMoveToPoint(cgContext, x_left, y_top_center);
				
				CGContextAddLineToPoint(cgContext, x_left_center, y_top);
				CGContextAddLineToPoint(cgContext, x_right_center, y_top);
				CGContextAddLineToPoint(cgContext, x_right, y_top_center);
				CGContextAddLineToPoint(cgContext, x_right, y_bottom_center);
				CGContextAddLineToPoint(cgContext, x_right_center, y_bottom);
				CGContextAddLineToPoint(cgContext, x_left_center, y_bottom);
				CGContextAddLineToPoint(cgContext, x_left, y_bottom_center);
				CGContextAddLineToPoint(cgContext, x_left, y_top_center);
				
				CGContextClosePath(cgContext);
				CGContextDrawPath(cgContext, kCGPathStroke);
			}
			else
			{
				if (used[i])
					CGContextSetRGBFillColor(cgContext, UsedColor[0], UsedColor[1], UsedColor[2], UsedColor[3]);
				else
					CGContextSetRGBFillColor(cgContext, DiceColor[0], DiceColor[1], DiceColor[2], DiceColor[3]);

				CGContextBeginPath(cgContext);
				CGContextMoveToPoint(cgContext, x_left, y_top_center);
				
				CGContextAddLineToPoint(cgContext, x_left_center, y_top);
				CGContextAddLineToPoint(cgContext, x_right_center, y_top);
				CGContextAddLineToPoint(cgContext, x_right, y_top_center);
				CGContextAddLineToPoint(cgContext, x_right, y_bottom_center);
				CGContextAddLineToPoint(cgContext, x_right_center, y_bottom);
				CGContextAddLineToPoint(cgContext, x_left_center, y_bottom);
				CGContextAddLineToPoint(cgContext, x_left, y_bottom_center);
				CGContextAddLineToPoint(cgContext, x_left, y_top_center);
				
				CGContextClosePath(cgContext);
				CGContextDrawPath(cgContext, kCGPathFillStroke);
			}
			
			if ((DiceColor[0] + DiceColor[1] + DiceColor[2]) / 3 < 0.5f)
				CGContextSetRGBFillColor(cgContext, 1.0, 1.0, 1.0, 1.0);
			else
				CGContextSetRGBFillColor(cgContext, 0.0, 0.0, 0.0, 1.0);

			int afPip[9];
			int n = pwBoard->diceRoll[i];
			int anDicePosition[2][2] = { 0, 0, 0, 0 };

			afPip[ 0 ] = afPip[ 8 ] = ( n == 4 ) || ( n == 5 ) || ( n == 6 ) ||
				( ( ( n == 2 ) || ( n == 3 ) ) && anDicePosition[ i ][ 0 ] & 1 );
			afPip[ 1 ] = afPip[ 7 ] = n == 6 &&
				!( anDicePosition[ i ][ 0 ] & 1 );
			afPip[ 2 ] = afPip[ 6 ] = ( n == 4 ) || ( n == 5 ) || ( n == 6 ) ||
				( ( ( n == 2 ) || ( n == 3 ) ) && !( anDicePosition[ i ][ 0 ] & 1 ) );
			afPip[ 3 ] = afPip[ 5 ] = n == 6 && anDicePosition[ i ][ 0 ] & 1;
			afPip[ 4 ] = n & 1;
			
			for (int iy = 0; iy < 3; iy++)
				for (int ix = 0; ix < 3; ix++)
					if (afPip[ iy * 3 + ix ])
					{
						float x = pt.x + (ix+1) * gBoardSizeScaled.DiceSize / 4 - gBoardSizeScaled.DiceSize / 2;
						float y = pt.y + (iy+1) * gBoardSizeScaled.DiceSize / 4 - gBoardSizeScaled.DiceSize / 2;
						CGContextBeginPath(cgContext);
						CGContextAddArc(cgContext, x, y, gBoardSizeScaled.DiceSize / 10, 0.0, 2*M_PI, 1);
						CGContextDrawPath(cgContext, kCGPathFill);
					}

			pt.x = pt.x + 2 * PointWidth;
		}
	}
	else
	{
		CGPoint pt;
		pt.x = (bd->colour == bd->turn) ? BorderWidth + 9 * PointWidth + BarWidth : BorderWidth + 3 * PointWidth;
		pt.x += Offset;
		pt.y = Height / 2 - 8 * gBoardScale;
		
		CGContextSelectFont(cgContext, "Helvetica", 12 * gBoardScale, kCGEncodingMacRoman);
		CGContextSetTextMatrix(cgContext, CGAffineTransformMake(1.0,0.0, 0.0, -1.0, 0.0, 0.0));
		CGContextSetRGBFillColor(cgContext, 1.0, 1.0, 1.0, 1.0);
		
		CGPoint pt2 = CGPointMake(pt.x, pt.y);
		const char* Text = "Tap to roll dice";
		
		CGContextSetTextDrawingMode(cgContext, kCGTextInvisible);
		CGContextShowTextAtPoint(cgContext, pt2.x, pt2.y, Text, strlen(Text));
		CGPoint sz = CGContextGetTextPosition(cgContext);
		CGContextSetTextDrawingMode(cgContext, kCGTextFill);
		CGContextShowTextAtPoint(cgContext, pt2.x - (sz.x - pt2.x) / 2, pt2.y + 12, Text, strlen(Text));
	}

	// Cube.
	if (!bd->crawford_game && bd->cube_use)
	{
		/*
		if (bd->doubled)
		{
			if (bd->doubled > 0)
				pt.x = BORDER_WIDTH + 9 * POINT_WIDTH + BAR_WIDTH - DICE_SIZE / 2;
			else
				pt.x = BORDER_WIDTH + 3 * POINT_WIDTH - DICE_SIZE / 2;
			pt.y = (BOARD_HEIGHT - DICE_SIZE) / 2;
		}
		else
		 */
		{
			pt.x = BorderWidth + 6 * PointWidth + (BarWidth - DiceSize) / 2 + Offset;
			if (bd->cube_owner > 0)
				pt.y = BorderBottomHeight;
			else if (bd->cube_owner < 0)
				pt.y = Height - BorderTopHeight - DiceSize;
			else
				pt.y = (Height - DiceSize) / 2;
		}

		CGContextSetRGBFillColor(cgContext, 1.0, 0.0, 0.0, 1.0);
//		CGContextFillRect(cgContext, CGRectMake(pt.x, pt.y, DICE_SIZE, DICE_SIZE));

		CGRect rect = CGRectMake(pt.x, pt.y, DiceSize, DiceSize);

		int corner_radius = 3;
		int x_left = rect.origin.x;
		int x_left_center = rect.origin.x + corner_radius;
		int x_right_center = rect.origin.x + rect.size.width - corner_radius;
		int x_right = rect.origin.x + rect.size.width;
		int y_top = rect.origin.y;
		int y_top_center = rect.origin.y + corner_radius;
		int y_bottom_center = rect.origin.y + rect.size.height - corner_radius;
		int y_bottom = rect.origin.y + rect.size.height;

		CGContextBeginPath(cgContext);
		CGContextMoveToPoint(cgContext, x_left, y_top_center);
		
		CGContextAddLineToPoint(cgContext, x_left_center, y_top);
		CGContextAddLineToPoint(cgContext, x_right_center, y_top);
		CGContextAddLineToPoint(cgContext, x_right, y_top_center);
		CGContextAddLineToPoint(cgContext, x_right, y_bottom_center);
		CGContextAddLineToPoint(cgContext, x_right_center, y_bottom);
		CGContextAddLineToPoint(cgContext, x_left_center, y_bottom);
		CGContextAddLineToPoint(cgContext, x_left, y_bottom_center);
		CGContextAddLineToPoint(cgContext, x_left, y_top_center);
		
		CGContextClosePath(cgContext);
		CGContextDrawPath(cgContext, kCGPathFill);

		pt.x += DiceSize / 2;
		pt.y += DiceSize / 2;
		
		int Cube = bd->cube << ABS(bd->doubled);
		if (Cube == 1) Cube = 64;
		char Text[8];
		sprintf(Text, "%d", Cube);

		int FontSize = 26;
		if (Cube > 999)
			FontSize = 14;
		else if (Cube > 99)
			FontSize = 18;
		FontSize *= gBoardScale;
		
		CGContextSetRGBFillColor(cgContext, 0.0, 0.0, 0.0, 1.0);
		CGContextSelectFont(cgContext, "Helvetica", FontSize, kCGEncodingMacRoman);
		CGContextSetTextMatrix(cgContext, CGAffineTransformMake(1.0,0.0, 0.0, -1.0, 0.0, 0.0));

		CGContextShowTextAtPointCentered(cgContext, pt.x, pt.y + FontSize/2 - 3 * gBoardScale, Text, strlen(Text));
	}

	// Pips and score.
	if (ms.gs != GAME_NONE)
	{
#if PBG_HD
		unsigned int Pips[2];
		PipCount(bd->old_board, Pips);
		int f = (bd->turn > 0);
		
		CGContextSetRGBFillColor(cgContext, 1.0, 1.0, 1.0, 1.0);
		CGContextSelectFont(cgContext, "Helvetica", 16, kCGEncodingMacRoman);
		CGContextSetTextMatrix(cgContext, CGAffineTransformMake(1.0,0.0, 0.0, -1.0, 0.0, 0.0));
		
		char Text[32];
		
		pt.x = fClockwise ? 2 * BORDER_WIDTH + POINT_WIDTH : BORDER_WIDTH;
		pt.y = BOARD_HEIGHT - BORDER_TOP_HEIGHT + 28;

		CGContextDrawImage(cgContext, CGRectMake(pt.x, pt.y - 14, 15, 15), blackImage);
		CGContextShowTextAtPoint(cgContext, pt.x + 20, pt.y, bd->name, strlen(bd->name));
		pt.y += 16;

		sprintf(Text, "Pips: %d (%+d)", Pips[!f], Pips[!f] - Pips[f]);
		CGContextShowTextAtPoint(cgContext, pt.x, pt.y, Text, strlen(Text));
		pt.y += 16;

		int nMatchLen = bd->match_to;
		if (nMatchLen)
			sprintf(Text, "Score: %d (%d away)", bd->score_opponent, MAX(nMatchLen - bd->score_opponent, 0));
		else
			sprintf(Text, "Score: %d", bd->score_opponent);
		CGContextShowTextAtPoint(cgContext, pt.x, pt.y, Text, strlen(Text));

		pt.x += 6 * POINT_WIDTH + BAR_WIDTH;
		pt.y = BOARD_HEIGHT - BORDER_TOP_HEIGHT + 28;
		
		CGContextDrawImage(cgContext, CGRectMake(pt.x, pt.y - 14, 15, 15), whiteImage);
		CGContextShowTextAtPoint(cgContext, pt.x + 20, pt.y, bd->name_opponent, strlen(bd->name_opponent));
		pt.y += 16;

		sprintf(Text, "Pips: %d (%+d)", Pips[f], Pips[f] - Pips[!f]);
		CGContextShowTextAtPoint(cgContext, pt.x, pt.y, Text, strlen(Text));
		pt.y += 16;
		
		if (nMatchLen)
			sprintf(Text, "Score: %d (%d away)", bd->score, MAX(nMatchLen - bd->score, 0));
		else
			sprintf(Text, "Score: %d", bd->score);
		CGContextShowTextAtPoint(cgContext, pt.x, pt.y, Text, strlen(Text));

		// Match info.
		pt.x = fClockwise ? BORDER_WIDTH : 2 * BORDER_WIDTH + 12 * POINT_WIDTH + BAR_WIDTH;
		pt.y = BOARD_HEIGHT - BORDER_TOP_HEIGHT + 28;

		if (nMatchLen)
		{
			sprintf(Text, "Match: %d", nMatchLen);
			CGContextShowTextAtPoint(cgContext, pt.x, pt.y, Text, strlen(Text));
			pt.y += 16;
		}

		if (bd->crawford_game)
		{
			strcpy(Text, "Crawford");
			CGContextShowTextAtPoint(cgContext, pt.x, pt.y, Text, strlen(Text));
		}
#else
		unsigned int Pips[2];
		PipCount(bd->old_board, Pips);
		int f = (bd->turn > 0);

		CGContextSetRGBFillColor(cgContext, 1.0, 1.0, 1.0, 1.0);
		CGContextSelectFont(cgContext, "Helvetica", 9 * gBoardScale, kCGEncodingMacRoman);
		CGContextSetTextMatrix(cgContext, CGAffineTransformMake(1.0,0.0, 0.0, -1.0, 0.0, 0.0));

		char Text[32];

		pt.x = fClockwise ? BorderWidth + PointWidth / 2 : 2 * BorderWidth + BarWidth + 12 * PointWidth + PointWidth / 2;
		pt.y = BorderBottomHeight + PointHeight;

		sprintf(Text, "Pips: %d", Pips[!f]);
		CGContextShowTextAtPointCentered(cgContext, pt.x, pt.y + 10 * gBoardScale, Text, strlen(Text));
		int nMatchLen = bd->match_to;
		if (nMatchLen)
			sprintf(Text, "%d (%d away)", bd->score_opponent, MAX(nMatchLen - bd->score_opponent, 0));
		else
			sprintf(Text, "Score: %d", bd->score_opponent);
		CGContextShowTextAtPointCentered(cgContext, pt.x, pt.y + 20 * gBoardScale, Text, strlen(Text));
		
		pt.y = Height - BorderTopHeight - PointHeight - 4 * gBoardScale;

		sprintf(Text, "Pips: %d", Pips[f]);
		CGContextShowTextAtPointCentered(cgContext, pt.x, pt.y, Text, strlen(Text));

		if (nMatchLen)
			sprintf(Text, "%d (%d away)", bd->score, MAX(nMatchLen - bd->score, 0));
		else
			sprintf(Text, "Score: %d", bd->score);
		CGContextShowTextAtPointCentered(cgContext, pt.x, pt.y - 10 * gBoardScale, Text, strlen(Text));
#endif
	}

	if (bgActiveDlg == BG_DLG_NONE && ap[ms.fTurn].pt != PLAYER_GNU)
	{
		if (bd->doubled != 0 && ((moverecord*)plLastMove->p)->mt == MOVE_DOUBLE && ms.gs == GAME_PLAYING)
			bgDlgShow(BG_DLG_DOUBLE_ACCEPT, can_redouble());
		else if (bd->resigned != 0 && ms.gs == GAME_PLAYING && ms.fResignationDeclined == 0)
			bgDlgShow(BG_DLG_ACCEPT_RESIGN, ABS(bd->resigned) - 1);
	}

//	bgDlgDraw(cgContext);
#if PBG_HD
	bounds.origin.x = (self.bounds.size.width - BOARD_WIDTH) / 2;
	bounds.origin.y = (self.bounds.size.height - BOARD_HEIGHT) / 2;
#else
	bounds = self.bounds;
#endif
	
	// Copy the contents of the painting context to the view's context
	image = CGBitmapContextCreateImage(cgContext);
	CGContextDrawImage(context, bounds, image);
	CGImageRelease(image);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch* touch = [[event allTouches] anyObject];
    CGPoint touchPoint = [touch locationInView:self];
	NSUInteger tapCount = [touch tapCount];

	tracking = -1;
	tracking_type = BG_TRACK_NONE;

	if (BoardAnimating)
		return;

	if ([msgLayer animationForKey:@"animateOpacity"])
		return;
	
	BoardData* bd = pwBoard;
	int x = touchPoint.x;
	int y = touchPoint.y;

	if (tapCount != 1)
	{
		bd->drag_point = -1;
		return;
	}
	
	if (bgActiveDlg != BG_DLG_NONE)
	{
		tracking = bgDlgClick(dlgLayer, x, y);

		if (tracking != -1)
			bgDlgUpdateTrack(dlgLayer, tracking);
		return;
	}
	
	tracking = bgBoardClick(&gBoardSize, x, y, bd);
	bgBoardUpdateTrack(&gBoardSize, glowLayer, tracking, bd);
	if (tracking != -1)
		return;
	
	int dest = board_point(bd, x, y);

	int numOnPoint;

	/* Ignore double-clicks and multiple presses and any clicks when not playing */
	if (tapCount != 1 || !bd->playing)
	{
		bd->DragTargetHelp = 0;
		bd->drag_point = -1;
		return;
	}

	// Handle 2-step move.
	if (bd->drag_point > -1 && bd->DragTargetHelp != 0)
	{
		bd->points[ bd->drag_point ] -= bd->drag_colour;

		// Automatically place chequer on destination point
		if( bd->drag_colour != bd->turn )
		{
			// can't move the opponent's chequers
			board_beep(bd);
			dest = bd->drag_point;
			place_chequer_or_revert(bd, dest);
		}
		else
		{
			// bearing off
			if( ( dest <= 0 ) || ( dest >= 25 ) )
				dest = bd->drag_colour > 0 ? 26 : 27;
			
			if( place_chequer_or_revert(bd, dest ) )
				playSound( SOUND_CHEQUER );
			else
				board_beep(bd);
		}
		bd->DragTargetHelp = 0;
		bd->drag_point = -1;
		[self setNeedsDisplay];
		return;
	}

	bd->drag_point = dest;

	bd->click_time = [NSDate timeIntervalSinceReferenceDate];
	bd->DragTargetHelp = 0;

	if (bd->drag_point == -1)
		return;

	if (ap[ms.fTurn].pt != PLAYER_HUMAN)
	{
//		outputl( _("It is the computer's turn -- type `play' to force it to move immediately.") );
//		outputx();
		
//		board_beep(bd);
		UserCommand("play");
		bd->drag_point = -1;
		
		return;
	}

	// Don't let them move chequers unless the dice have been rolled.
	if (bd->diceShown != DICE_ON_BOARD)
	{
//		outputl("You must roll the dice before moving pieces");
//		outputx();
//		board_beep(bd);
		bd->drag_point = -1;
		
		return;
	}

	if (move_to_make_point(bd, bd->drag_point, false))
	{
//		bd->drag_point = -1;
		tracking_type = BG_TRACK_TAKE;
		[self setNeedsDisplay];
		return;
	}

	if (bd->drag_point == (53 - bd->turn) / 2 && !bd->valid_move)
		return;

	// How many chequers on clicked point
	numOnPoint = bd->points[bd->drag_point];

	if (numOnPoint == 0)
	{
		// clicked on empty point
		board_beep( bd );
		bd->drag_point = -1;
		return;
	}

	bd->drag_colour = numOnPoint < 0 ? -1 : 1;

	// trying to move opponent's chequer
	if (bd->drag_colour != bd->turn)
	{
		board_beep( bd );
		bd->drag_point = -1;
		return;
	}

	// Start Dragging piece
	board_start_drag(bd, bd->drag_point, x, y);
//	board_drag(board, bd, x, y);
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch* touch = [[event allTouches] anyObject];
    CGPoint touchPoint = [touch locationInView:self];
	BoardData* bd = pwBoard;
	int x = touchPoint.x;
	int y = touchPoint.y;

	if (BoardAnimating)
		return;

	if (bgActiveDlg != BG_DLG_NONE)
	{
		int pos = bgDlgClick(dlgLayer, x, y);
		
		if (tracking != pos)
		{
//			tracking = pos;
			bgDlgUpdateTrack(dlgLayer, -1);
		}
		return;
	}

	if (tracking != -1)
	{
		int pos = bgBoardClick(&gBoardSize, x, y, bd);
		glowLayer.hidden = (pos != tracking);
		return;
	}

	if (bd->drag_point == -1)
		return;

	if (tracking_type == BG_TRACK_TAKE)
		return;

	if (bd->drag_point == (53 - bd->turn) / 2 && !bd->valid_move)
		return;

	CGImage* chequerImage;
	if (bd->drag_colour == 1)
		chequerImage = blackImage;
	else
		chequerImage = whiteImage;
	
	float ChequerSize = 2 * (gBoardSize.ChequerRadius + 2);
	
	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
	animLayer.bounds = CGRectMake(0, 0, ChequerSize * 1.5, ChequerSize * 1.5);
	animLayer.contents = (id)chequerImage;
	animLayer.position = touchPoint;
	[animLayer setHidden:NO];
	[CATransaction commit];
	[CATransaction flush];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch* touch = [[event allTouches] anyObject];
    CGPoint touchPoint = [touch locationInView:self];
//	NSUInteger tapCount = [touch tapCount];
	
	BoardData* bd = pwBoard;
	int x = touchPoint.x;
	int y = touchPoint.y;
	
	if ([msgLayer animationForKey:@"animateOpacity"])
	{
		[msgLayer removeAnimationForKey:@"animateOpacity"];
		
		for (int i = 0; i < outputStackSize; i++)
			free(outputStack[i]);
		outputStackSize = 0;
		bd->drag_point = -1;
		tracking = -1;
		return;
	}
	
	if (BoardAnimating)
	{
		skip_anim = 1;
		[animLayer removeAnimationForKey:@"animatePosition"];
		return;
	}

	if (bgActiveDlg != BG_DLG_NONE)
	{
		int ID = bgDlgClick(dlgLayer, x, y);

		if (ID != tracking)
		{
			tracking = -1;
			return;
		}

		switch (ID)
		{
			case BG_CMD_MAIN_NEW:
				if (ms.gs == GAME_PLAYING)
					bgDlgShow(BG_DLG_CONFIRM_EXIT, 0);
				else
				{
					bgDlgShow(BG_DLG_NONE, 0);
					CommandNewMatch(NULL);
				}
				break;
				
			case BG_CMD_MAIN_RESUME:
				if (ms.gs == GAME_PLAYING)
				{
					if (bd->doubled != 0 && ((moverecord*)plLastMove->p)->mt == MOVE_DOUBLE && ms.gs == GAME_PLAYING)
						bgDlgShow(BG_DLG_DOUBLE_ACCEPT, can_redouble());
					else if (bd->resigned != 0 && ms.gs == GAME_PLAYING && ms.fResignationDeclined == 0)
						bgDlgShow(BG_DLG_ACCEPT_RESIGN, ABS(bd->resigned) - 1);
					else if( ap[ ms.fTurn ].pt != PLAYER_HUMAN )
					{
						bgDlgShow(BG_DLG_NONE, 0);
						UserCommand("play");
					}
					else
						bgDlgShow(BG_DLG_NONE, 0);
				}
				break;
				
			case BG_CMD_MAIN_SETTINGS:
			{
				if ([self.nextResponder isKindOfClass:UIViewController.class])
				{
					bgViewController* controller = (bgViewController*)self.nextResponder;
					[controller ShowSettingsView:nil];
					bgDlgUpdateTrack(dlgLayer, -1);
				}
			} break;
				
			case BG_CMD_MAIN_ABOUT:
			{
				if ([self.nextResponder isKindOfClass:UIViewController.class])
				{
					bgViewController* controller = (bgViewController*)self.nextResponder;
					[controller ShowHelpView:nil];
					bgDlgUpdateTrack(dlgLayer, -1);
				}
				bgDlgUpdateTrack(dlgLayer, -1);
			} break;

//			case BG_CMD_GAME_MAIN:
//				bgDlgShow(BG_DLG_MAIN_MENU, 0);
//				break;
				
//			case BG_CMD_GAME_RESUME:
//				bgDlgShow(BG_DLG_NONE, 0);
//				break;
				
			case BG_CMD_GAME_RESIGN:
				bgDlgShow(BG_DLG_RESIGN_TYPE, 0);
				break;

			case BG_CMD_GAME_HINT:
				bgDlgShow(BG_DLG_NONE, 0);
				UserCommand("hint");
				break;
				
//			case BG_CMD_GAME_UNDO:
//				if (bd->valid_move)
//				{
//					write_points( bd->points, bd->turn,  bd->nchequers, bd->old_board );
//					bd->valid_move = NULL;
//					bd->drag_point = -1;
//				}
//				bgDlgShow(BG_DLG_NONE, 0);
//				break;
				
			case BG_CMD_RESIGN_SINGLE:
				UserCommand("resign normal");
				bgDlgShow(BG_DLG_NONE, 0);
				break;
				
			case BG_CMD_RESIGN_GAMMON:
				UserCommand("resign gammon");
				bgDlgShow(BG_DLG_NONE, 0);
				break;
				
			case BG_CMD_RESIGN_BACKGAMMON:
				UserCommand("resign backgammon");
				bgDlgShow(BG_DLG_NONE, 0);
				break;
				
			case BG_CMD_RESIGN_CANCEL:
				bgDlgShow(BG_DLG_NONE, 0);
				break;
				
			case BG_CMD_EXIT_MATCH_YES:
				fConfirm = 0;
				CommandNewMatch(NULL);
				fConfirm = 1;
				bgDlgShow(BG_DLG_NONE, 0);
				break;
				
			case BG_CMD_EXIT_MATCH_NO:
				bgDlgShow(BG_DLG_MAIN_MENU, 0);
				break;
				
			case BG_CMD_ACCEPT_RESIGN_YES:
				bd->drag_point = -1;
				if (bd->resigned)
					UserCommand("accept");
				bgDlgShow(BG_DLG_NONE, 0);
				break;
				
			case BG_CMD_ACCEPT_RESIGN_NO:
				bd->drag_point = -1;
				if (bd->resigned)
					UserCommand("reject");
				bgDlgShow(BG_DLG_NONE, 0);
				break;
				
			case BG_CMD_DOUBLE_TAKE:
				bd->drag_point = -1;
				UserCommand( "take" );
				bgDlgShow(BG_DLG_NONE, 0);
				break;
				
			case BG_CMD_DOUBLE_REDOUBLE:
				bd->drag_point = -1;
				UserCommand( "redouble" );
				bgDlgShow(BG_DLG_NONE, 0);
				break;
				
			case BG_CMD_DOUBLE_DROP:
				bd->drag_point = -1;
				UserCommand( "drop" );
				bgDlgShow(BG_DLG_NONE, 0);
				break;
				
			case BG_CMD_CONFIRM_DOUBLE_YES:
				UserCommand("double");
				bgDlgShow(BG_DLG_NONE, 0);
				break;
				
			case BG_CMD_CONFIRM_DOUBLE_NO:
				bgDlgShow(BG_DLG_NONE, 0);
				break;
				
			case BG_CMD_PROGRESS_CANCEL:
				fInterrupt = TRUE;
				break;
				
			case BG_CMD_HINT_MOVE:
			{
				extern movelist* HintMoveList;
				extern int HintIndex;
				TanBoard anBoard;
				move* pm = &HintMoveList->amMoves[HintIndex];
				memcpy(anBoard, ms.anBoard, sizeof(TanBoard));
				ApplyMove(anBoard, pm->anMove, FALSE);
				UpdateMove(pwBoard, anBoard);
				bgDlgShow(BG_DLG_NONE, 0);
			} break;

			case BG_CMD_HINT_CLOSE:
				bgDlgShow(BG_DLG_NONE, 0);
				break;

			default:
				if (!CGRectContainsPoint(bgDlgRect, CGPointMake(x, y)))
				{
					bgDlgFade = !bgDlgFade;
					[gView FadeDlg];
				}
				break;
		}

		tracking = -1;
		return;
	}

	if (tracking != -1)
	{
		int up = bgBoardClick(&gBoardSize, x, y, bd);

		if (up == tracking)
		{
			if (up == BG_CMD_MENU)
			{
//				if (ms.gs == GAME_PLAYING)
//					bgDlgShow(BG_DLG_GAME_MENU, bd->valid_move == NULL);
//				else
					bgDlgShow(BG_DLG_MAIN_MENU, ms.gs != GAME_PLAYING);
			}
			else if (up == BG_CMD_DOUBLE)
			{
				// Clicked on cube; double.
				bd->drag_point = -1;
				if (can_double())
					bgDlgShow(BG_DLG_CONFIRM_DOUBLE, 0);
			}
			else if (up == BG_CMD_DICE)
			{
				if (bd->diceShown == DICE_BELOW_BOARD || bd->diceShown == DICE_NOT_SHOWN)
				{
					bd->drag_point = -1;
					UserCommand("roll");
				}
				else if (bd->diceShown == DICE_ON_BOARD)
				{
					if (bd->valid_move && bd->valid_move->cMoves == bd->move_list.cMaxMoves && bd->valid_move->cPips == bd->move_list.cMaxPips)
						Confirm(bd);
					else
					{
						swap_us(bd->diceRoll, bd->diceRoll + 1);
						[self setNeedsDisplay];
					}
				}
			}
			else if (up == BG_CMD_UNDO_OR_HINT)
			{
				if (bd->valid_move)
				{
					// Undo.
					write_points( bd->points, bd->turn,  bd->nchequers, bd->old_board );
					bd->valid_move = NULL;
					bd->drag_point = -1;
					[self setNeedsDisplay];
				}
				else
				{
					// Show hint.
					if (fAdvancedHint)
					{
						bgDlgShow(BG_DLG_NONE, 0);
						UserCommand("hint");
					}
					else
					{
						movelist ml;
						cubeinfo ci;
						
						GetMatchStateCubeInfo( &ci, &ms );
						
						if ( memcmp ( &sm.ms, &ms, sizeof ( matchstate ) ) )
						{
							ProgressStart( _("Considering move...") );
							if( FindnSaveBestMoves( &ml, ms.anDice[ 0 ], ms.anDice[ 1 ],
												   ms.anBoard, 
												   NULL, 
												   arSkillLevel[ SKILL_DOUBTFUL ],
												   &ci, &esEvalChequer.ec,
												   aamfEval ) < 0 || fInterrupt )
							{
								ProgressEnd();

								glowLayer.contents = nil;
								glowLayer.hidden = YES;
								tracking = -1;
								bd->drag_point = -1;
								return;
							}
							ProgressEnd();
							
							UpdateStoredMoves ( &ml, &ms );
							
							if ( ml.amMoves )
								free ( ml.amMoves );
							
						}
						
						if( !sm.ml.cMoves ) {
							outputl( _("There are no legal moves.") );
	//						return;
						}
						else
						{
	//						TanBoard anBoard;
							move* pm = &sm.ml.amMoves[0];

							board_animate(bd, pm->anMove, sm.ms.fTurn);
							animate_hint = 1;
	//						memcpy(anBoard, ms.anBoard, sizeof(TanBoard));
	//						ApplyMove(anBoard, pm->anMove, FALSE);
	//						UpdateMove(pwBoard, anBoard);
						}
					}
				}
			}
		}

		glowLayer.contents = nil;
		glowLayer.hidden = YES;
		tracking = -1;
		bd->drag_point = -1;
		return;
	}

	int dest;

	if (bd->drag_point < 0)
		return;

	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
	[animLayer setHidden:YES];
	[CATransaction commit];

//	board_end_drag( board, bd );
	dest = board_point(bd, x, y);

	if (tracking_type == BG_TRACK_TAKE)
	{
		if (dest == bd->drag_point)
			move_to_make_point(bd, dest, true);

		tracking_type = BG_TRACK_NONE;
		bd->drag_point = -1;
		[self setNeedsDisplay];
		return;
	}

	if (bd->drag_point == (53 - bd->turn) / 2 && !bd->valid_move)
	{
		// if nDragPoint is 26 or 27 (i.e. off), bear off as many chequers as possible.
		if (dest == bd->drag_point)
		{
			// user clicked on bear-off tray: try to bear-off chequers or show forced move
			TanBoard anBoard;
			
			memcpy ( anBoard, ms.anBoard, sizeof(TanBoard) );
			
			bd->drag_colour = bd->turn;
			bd->drag_point = -1;
			
			if (ForcedMove(anBoard, bd->diceRoll) || GreadyBearoff(anBoard, bd->diceRoll))
			{
				int old_points[28];
				memcpy (old_points, bd->points, sizeof old_points);
				
				// we've found a move: update board
				if ( UpdateMove( bd, anBoard ) )
				{
					// should not happen as ForcedMove and GreadyBearoff always return legal moves.
					assert(FALSE);
				}
				
				// Play a sound if any chequers have moved.
				if (memcmp(old_points, bd->points, sizeof old_points))
					playSound( SOUND_CHEQUER );
			}
		}
		return;
	}

	if (dest == bd->drag_point && [NSDate timeIntervalSinceReferenceDate] - bd->click_time < 0.4)
	{
		// Automatically place chequer on destination point
		if( bd->drag_colour != bd->turn )
		{
			// can't move the opponent's chequers
			board_beep(bd);
			dest = bd->drag_point;
			place_chequer_or_revert(bd, dest);
		}
		else
		{
			int used[2] = { 0, 0 };
			int num_used = 0;

			if (bd->valid_move)
			{
				int* move = bd->valid_move->anMove;

				for (int i = 0; i < 4; i++)
				{
					if (move[i*2] == -1)
						break;
					
					int pips = ABS(move[i*2] - move[i*2+1]);
					
					if (pips == bd->diceRoll[0])
					{
						if (!used[0])
							used[0] = 1;
						else
							used[1] = 1;
					}
					else if (pips == bd->diceRoll[1])
					{
						if (!used[1])
							used[1] = 1;
						else
							used[0] = 1;
					}
					else if ((bd->diceRoll[0] > bd->diceRoll[1] && !used[0]) || used[1])
						used[0] = 1;
					else
						used[1] = 1;
					
					num_used++;
				}
			}

			int left, right;

			if (used[0])
			{
				left = bd->diceRoll[1];
				right = bd->diceRoll[0];
			}
			else
			{
				left = bd->diceRoll[0];
				right = bd->diceRoll[1];
			}
			
			// Try left roll first.
			dest = bd->drag_point - left * bd->drag_colour;
			
			// bearing off
			if( ( dest <= 0 ) || ( dest >= 25 ) )
				dest = bd->drag_colour > 0 ? 26 : 27;
			
			if( place_chequer_or_revert(bd, dest ) )
				playSound( SOUND_CHEQUER );
			else
			{
				// First roll was illegal.  We are going to 
				// try the second roll next. First, we have 
				// to redo the pickup since we got reverted.
				bd->points[ bd->drag_point ] -= bd->drag_colour;
//				board_invalidate_point(bd, bd->drag_point);
				
				// Now we try the other die roll.
				dest = bd->drag_point - right * bd->drag_colour;
				
				// bearing off
				if( ( dest <= 0 ) || ( dest >= 25 ) )
					dest = bd->drag_colour > 0 ? 26 : 27;
				
				if (place_chequer_or_revert(bd, dest))
					playSound( SOUND_CHEQUER );
				else 
				{
//					board_invalidate_point(bd, bd->drag_point);
					board_beep(bd);
				}
			}
			[self setNeedsDisplay];
		}
		bd->DragTargetHelp = 0;
		bd->drag_point = -1;
		return;
	}

	if (dest == bd->drag_point)
	{
		bd->points[ bd->drag_point ] += bd->drag_colour;
		bd->DragTargetHelp = 0;
		bd->drag_point = -1;
		[self setNeedsDisplay];
		return;
	}
	else
	{
		// This is from a normal drag release
		if (place_chequer_or_revert(bd, dest))
			playSound(SOUND_CHEQUER);
		else
			board_beep(bd);
	}

	bd->DragTargetHelp = 0;
	bd->drag_point = -1;

	[self setNeedsDisplay];
}

-(void) IdleSelector: (id) FuncData
{
	IdleData* SelData;
	[FuncData getValue:&SelData];

	SelData->Func();
	delete SelData;
}

-(void) PlayAnim: (id) Data
{
	if (outputStackSize != 0 || [msgLayer animationForKey:@"animateOpacity"])
	{
		[self performSelector:@selector(PlayAnim:) withObject:Data afterDelay:0.0];
		return;
	}
	
	BoardData* bd = pwBoard;

	int from = convert_point(animate_move_list[anim_move], animate_player);
	int to = convert_point(animate_move_list[anim_move + 1], animate_player);
	int colour = animate_player ? 1 : -1;
	
	bd->points[from] -= colour;

	int nf = bd->points[from];
	int nt = bd->points[to];
	if (nt == -colour)
		nt = 0;
	nt += colour;
	
	CGPoint Start = bgBoardPointPos(&gBoardSize, from, MIN(ABS(nf), 5));
	CGPoint End = bgBoardPointPos(&gBoardSize, to, MIN(ABS(nt), 5) - 1);

	CGImage* chequerImage;
	if (animate_player)
		chequerImage = blackImage;
	else
		chequerImage = whiteImage;

	float ChequerSize = 2 * (gBoardSize.ChequerRadius + 2);

	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
	animLayer.bounds = CGRectMake(0, 0, ChequerSize, ChequerSize);
	animLayer.contents = (id)chequerImage;
	animLayer.position = Start;
	[animLayer setHidden:NO];
	[CATransaction commit];
	[CATransaction flush];

	[self setNeedsDisplay];

	CGPoint Dir = CGPointMake(End.x - Start.x, End.y - Start.y);
	float d = sqrtf(Dir.x * Dir.x + Dir.y * Dir.y);
	
	CGMutablePathRef path = CGPathCreateMutable(); 
	CGPathMoveToPoint(path, NULL, Start.x, Start.y);
	CGPathAddLineToPoint(path, NULL, End.x, End.y);

	CAKeyframeAnimation* anim;
	anim = [CAKeyframeAnimation animationWithKeyPath:@"position"];
	anim.fillMode = kCAFillModeForwards;
	anim.removedOnCompletion = YES;
	anim.delegate = self;
	anim.path = path;
	anim.duration = d / 300.0;
	CFRelease(path);

	if (skip_anim)
		anim.duration = 0.0;

	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
	animLayer.position = End;
	[CATransaction commit];
	
//	animLayer.position = End;
	[animLayer addAnimation:anim forKey:@"animatePosition"];
}

- (void)animationDidStart:(CAAnimation *)animation
{
	/*
	wasEnabled = self.userInteractionEnabled;
	
	if (wasEnabled)
		self.userInteractionEnabled = NO;
 */
}

- (void)animationDidStop:(CAAnimation *)animation finished:(BOOL)finished
{
	BoardData* bd = pwBoard;
	int colour = animate_player ? 1 : -1;

	int to = convert_point(animate_move_list[anim_move + 1], animate_player);
	
	if (bd->points[to] == -colour)
	{
		bd->points[to] = 0;
		bd->points[animate_player ? 0 : 25] -= colour;
	}
	bd->points[to] += colour;
	
	if (anim_move == 6 || animate_move_list[anim_move+2] < 0)
	{
		[CATransaction begin];
		[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
		[animLayer setHidden:YES];
		[CATransaction commit];
		
		if (animate_hint)
		{
			update_move(bd);
		}

		BoardAnimating = FALSE;
		NextTurnNotify();
	}
	else
	{
		anim_move += 2;
		[self performSelector:@selector(PlayAnim:) withObject:nil afterDelay:0.0];
	}

	[self setNeedsDisplay];

	/*
	if (wasEnabled)
		self.userInteractionEnabled = YES;
	
	animLayer.contents = nil;
	//	[animLayer setHidden:YES];
	 */
}

- (void) ShowOutput: (id) Value
{
	const int maxLines = 10;
	char* lines[maxLines];
	int numLines = 0;
	int mx = 0;

	if ([msgLayer animationForKey:@"animateOpacity"])
	{
		[self performSelector:@selector(ShowOutput:) withObject:nil afterDelay:0.1];
		return;
	}

	if (outputStackSize == 0)
		return;

	char* text = outputStack[0];
	outputStackSize--;

	for (int i = 0; i < 3; i++)
		outputStack[i] = outputStack[i+1];
	
	CGContextSelectFont(cgContext, "Helvetica", 15, kCGEncodingMacRoman);
	CGContextSetTextMatrix(cgContext, CGAffineTransformMake(1.0,0.0, 0.0, -1.0, 0.0, 0.0));
	CGContextSetTextDrawingMode(cgContext, kCGTextInvisible);

	char* str = text;
	for (;;)
	{
		if (!*str || numLines == maxLines)
			break;
		
		char* nl = strchr(str, '\n');
		if (nl)
			*nl = 0;
		lines[numLines] = str;
		numLines++;

		CGContextShowTextAtPoint(cgContext, 0, 0, str, strlen(str));
		CGPoint sz = CGContextGetTextPosition(cgContext);

		if (sz.x > mx)
			mx = sz.x;

		if (nl)
			str = nl + 1;
		else
			break;
	}

	CGRect rect;
	int w = 20 + mx;
	int h = 10 + numLines * 22;
	float x = self.frame.origin.x + self.frame.size.width / 2;//BORDER_WIDTH + POINT_WIDTH * 6 + BAR_WIDTH / 2;
	float y = gBoardSizeScaled.BorderTopHeight + h / 2;

	int width = w * gBoardScale;
	int height = h * gBoardScale;

	rect = CGRectMake(1, 1, width - 2, height - 2);

	CGColorSpaceRef colorSpace;
	colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 4 * width, colorSpace, kCGImageAlphaPremultipliedFirst);
	CGColorSpaceRelease(colorSpace);

	CGContextSetAllowsAntialiasing(context, TRUE);
	CGContextSetShouldAntialias(context, TRUE);

	CGContextAddRoundedRect(context, rect, 4);
	CGContextSetRGBFillColor(context, 0.0, 0.0, 0.0, 0.95);
	CGContextSetRGBStrokeColor(context, 0.75, 0.75, 0.75, 1);
	CGContextDrawPath(context, kCGPathFillStroke);

	CGContextSelectFont(context, "Helvetica", 15 * gBoardScale, kCGEncodingMacRoman);
//	CGContextSetTextMatrix(context, CGAffineTransformMake(1.0,0.0, 0.0, -1.0, 0.0, 0.0));
	CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0);
//	CGContextSetTextDrawingMode(context, kCGTextInvisible);

	int ty = 22 * gBoardScale;
	for (int i = 0; i < numLines; i++)
	{
		CGContextShowTextAtPoint(context, 10 * gBoardScale, height - ty, lines[i], strlen(lines[i]));
		ty += 22 * gBoardScale;
	}

	CGImage* image = CGBitmapContextCreateImage(context);
	CGContextRelease(context);

	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
	msgLayer.bounds = CGRectMake(0, 0, w/4, h/4);
	[CATransaction commit];

	[CATransaction flush];
	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
	msgLayer.opacity = 0.0;
	msgLayer.position = CGPointMake(x, y);
	msgLayer.hidden = NO;
	msgLayer.contents = (id)image;
	[CATransaction commit];
	msgLayer.bounds = CGRectMake(0, 0, w, h);

	float Duration = 1.5f + numLines;
	NSArray* values = [NSArray arrayWithObjects: [NSNumber numberWithFloat:1.0f], [NSNumber numberWithFloat:1.0f], [NSNumber numberWithFloat:0.0f], nil];
	NSArray* times = [NSArray arrayWithObjects: [NSNumber numberWithFloat:0.0f], [NSNumber numberWithFloat:1.0f - 0.25f / Duration], [NSNumber numberWithFloat:1.0f], nil];
	CAKeyframeAnimation* anim;
	anim = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
	anim.calculationMode = kCAAnimationLinear;
	anim.values = values;
	anim.keyTimes = times;
	anim.fillMode = kCAFillModeForwards;
	anim.duration = Duration;
	anim.removedOnCompletion = YES;
	anim.delegate = nil;
	[msgLayer addAnimation:anim forKey:@"animateOpacity"];

	free(text);
}

-(void) ShowDlg:(int)DlgType withParam:(int)Param withText:(const char*)Text
{
	DlgData* Data = new DlgData;
	
	Data->Type = DlgType;
	Data->Param = Param;
	Data->Text = Text;

	NSValue* Val = [NSValue valueWithPointer:Data];

	self.userInteractionEnabled = NO;
	if (bgActiveDlg != BG_DLG_NONE && DlgType != BG_DLG_NONE && DlgType != BG_DLG_PROGRESS)
	{
		dlgLayer.contents = nil;
		dlgLayer.hidden = YES;
		bgActiveDlg = BG_DLG_NONE;
		[self performSelector:@selector(DisplayDlg:) withObject:Val afterDelay:0.25];
	}
	else
	{
		[self DisplayDlg:Val];
	}
}

-(void) DisplayDlg: (NSValue*) Param
{
	DlgData* Data;
	[Param getValue:&Data];
	
	if (Data->Type == BG_DLG_PROGRESS)
		[spinner startAnimating];
	else
		[spinner stopAnimating];

	bgDlgShow(dlgLayer, Data->Type, Data->Param, Data->Text);
	self.userInteractionEnabled = YES;

	delete Data;
}

-(void) FadeDlg
{
	if (bgDlgFade)
		dlgLayer.opacity = 0.3;
	else
		dlgLayer.opacity = 1.0;
}

@end
