enum
{
	BG_DLG_NONE,
	BG_DLG_MAIN_MENU,
//	BG_DLG_GAME_MENU,
	BG_DLG_RESIGN_TYPE,
	BG_DLG_CONFIRM_EXIT,
	BG_DLG_ACCEPT_RESIGN,
	BG_DLG_DOUBLE_ACCEPT,
	BG_DLG_CONFIRM_DOUBLE,
	BG_DLG_HINT,
	BG_DLG_PROGRESS
};

enum
{
	// Chequer positions.
	BG_CMD_BAR_BOTTOM,
	BG_CMD_BAR_TOP = 25,
	BG_CMD_TRAY_BOTTOM,
	BG_CMD_TRAY_TOP,

	// Board buttons.
	BG_CMD_MENU,
	BG_CMD_DOUBLE,
	BG_CMD_DICE,
	BG_CMD_UNDO_OR_HINT,

	// Dialog buttons.
	BG_CMD_MAIN_NEW,
	BG_CMD_MAIN_RESUME,
	BG_CMD_MAIN_SETTINGS,
	BG_CMD_MAIN_ABOUT,
//	BG_CMD_GAME_MAIN,
//	BG_CMD_GAME_RESUME,
	BG_CMD_GAME_RESIGN,
	BG_CMD_GAME_HINT,
//	BG_CMD_GAME_UNDO,
	BG_CMD_RESIGN_SINGLE,
	BG_CMD_RESIGN_GAMMON,
	BG_CMD_RESIGN_BACKGAMMON,
	BG_CMD_RESIGN_CANCEL,
	BG_CMD_EXIT_MATCH_YES,
	BG_CMD_EXIT_MATCH_NO,
	BG_CMD_ACCEPT_RESIGN_YES,
	BG_CMD_ACCEPT_RESIGN_NO,
	BG_CMD_DOUBLE_TAKE,
	BG_CMD_DOUBLE_REDOUBLE,
	BG_CMD_DOUBLE_DROP,
	BG_CMD_CONFIRM_DOUBLE_YES,
	BG_CMD_CONFIRM_DOUBLE_NO,
	BG_CMD_PROGRESS_CANCEL,
	BG_CMD_HINT_MOVE,
	BG_CMD_HINT_CLOSE,
};

#ifdef __cplusplus
extern "C" {
#endif
#include "bgBoardData.h"
void bgHint(movelist* pmlOrig, const unsigned int iMove);
#ifdef __cplusplus
}
#endif

void bgDlgSetSize(CALayer* DlgLayer, float width, float height);
void bgDlgShow(CALayer* DlgLayer, int DlgType, int Param, const char* Text);
void bgDlgUpdateTrack(CALayer* DlgLayer, int Tracking);
int bgDlgClick(CALayer* DlgLayer, int x, int y);

extern int bgActiveDlg;
extern int bgDlgFade;
extern CGRect bgDlgRect;
