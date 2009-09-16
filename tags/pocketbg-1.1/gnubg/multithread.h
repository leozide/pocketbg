#include "backgammon.h"

#define GLIB_THREADS

#define MAX_NUMTHREADS 16

typedef enum _TaskType {TT_ANALYSEMOVE, TT_ROLLOUTLOOP, TT_TEST, TT_RUNCALIBRATIONEVALS, TT_CLOSE} TaskType;

typedef struct _Task
{
	TaskType type;
	struct _Task *pLinkedTask;
} Task;

typedef struct _AnalyseMoveTask
{
	Task task;
	moverecord *pmr;
	list *plGame;
	statcontext *psc;
	matchstate ms;
} AnalyseMoveTask;

extern void MT_InitThreads();
extern void MT_Close();
extern void MT_AddTask(Task *pt);
extern int MT_WaitForTasks(void (*pCallback)(), int callbackTime);
extern unsigned int MT_GetNumThreads();
extern void MT_SetNumThreads(unsigned int num);
extern int MT_Enabled(void);
extern int MT_GetThreadID();

extern void MT_Exclusive();
extern void MT_Release();

extern int MT_GetDoneTasks();
extern void MT_SyncInit();
extern void MT_SyncStart();
extern double MT_SyncEnd();

#define MT_SafeInc(x) (++(*x))
#define MT_SafeAdd(x, y) ((*x) += y)
#define MT_SafeDec(x) (--(*x)) == 0)
