/*
 * eval.c
 *
 * by Gary Wong <gtw@gnu.org>, 1998, 1999, 2000, 2001, 2002.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of version 2 of the GNU General Public License as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 * $Id: eval.c,v 1.318 2007/05/01 23:20:15 c_anthon Exp $
 */

#include "config.h"
#include "backgammon.h"

#include <glib.h>
#include <string.h>
#include <errno.h>
#include "cache.h"
#include <fcntl.h>
#if HAVE_SYS_MMAN_H
#include <sys/mman.h>
#endif

#include "isaac.h"
#include "neuralnet.h"
#include "md5.h"
#include "bearoffgammon.h"
#include "positionid.h"
#include "matchid.h"
#include "matchequity.h"
#include "bearoff.h"
#include "format.h"
#include "sse.h"
#include "multithread.h"

#define BINARY 0

/* From pub_eval.c: */
extern float pubeval( int race, int pos[] );

static float
Cl2CfMoney ( float arOutput [ NUM_OUTPUTS ], cubeinfo *pci, float rCubeX );

static float
Cl2CfMatch ( float arOutput [ NUM_OUTPUTS ], cubeinfo *pci, float rCubeX );

static float
Cl2CfMatchOwned ( float arOutput [ NUM_OUTPUTS ], cubeinfo *pci, float rCubeX );

static float
Cl2CfMatchCentered ( float arOutput [ NUM_OUTPUTS ], cubeinfo *pci, float rCubeX );

static float
Cl2CfMatchUnavailable ( float arOutput [ NUM_OUTPUTS ], cubeinfo *pci, float rCubeX );

static float
EvalEfficiency( int anBoard[2][25], positionclass pc );

static int 
EvaluatePositionCubeful4( NNState *nnStates, int anBoard[ 2 ][ 25 ],
                          float arOutput[ NUM_OUTPUTS ],
                          float arCubeful[],
                          const cubeinfo aciCubePos[], int cci, 
                          const cubeinfo* pciMove,
                          const evalcontext* pec, 
                          int nPlies, int fTop );

static int MaxTurns( int i );

typedef int ( *classevalfunc )( int anBoard[ 2 ][ 25 ], float arOutput[],
                                 const bgvariation bgv, NNState *nnStates );

typedef int ( *classdumpfunc )( int anBoard[ 2 ][ 25 ], char *szOutput,
                                 const bgvariation bgv );
typedef void ( *classstatusfunc )( char *szOutput );
typedef int ( *cfunc )( const void *, const void * );

/* Race inputs */
enum {
  /* In a race position, bar and the 24 points are always empty, so only */
  /* 23*4 (92) are needed */

  /* (0 <= k < 14), RI_OFF + k = */
  /*                       1 if exactly k+1 checkers are off, 0 otherwise */

  RI_OFF = 92,

  /* Number of cross-overs by outside checkers */
  
  RI_NCROSS = 92 + 14,
  
  HALF_RACE_INPUTS
};


/* Contact inputs -- see Berliner for most of these */
enum {
  /* n - number of checkers off
     
     off1 -  1         n >= 5
             n/5       otherwise
	     
     off2 -  1         n >= 10
             (n-5)/5   n < 5 < 10
	     0         otherwise
	     
     off3 -  (n-10)/5  n > 10
             0         otherwise
  */
     
  I_OFF1, I_OFF2, I_OFF3,
  
  /* Minimum number of pips required to break contact.

     For each checker x, N(x) is checker location,
     C(x) is max({forall o : N(x) - N(o)}, 0)

     Break Contact : (sum over x of C(x)) / 152

     152 is dgree of contact of start position.
  */
  I_BREAK_CONTACT,

  /* Location of back checker (Normalized to [01])
   */
  I_BACK_CHEQUER,

  /* Location of most backward anchor.  (Normalized to [01])
   */
  I_BACK_ANCHOR,

  /* Forward anchor in opponents home.

     Normalized in the following way:  If there is an anchor in opponents
     home at point k (1 <= k <= 6), value is k/6. Otherwise, if there is an
     anchor in points (7 <= k <= 12), take k/6 as well. Otherwise set to 2.
     
     This is an attempt for some continuity, since a 0 would be the "same" as
     a forward anchor at the bar.
   */
  I_FORWARD_ANCHOR,

  /* Average number of pips opponent loses from hits.
     
     Some heuristics are required to estimate it, since we have no idea what
     the best move actually is.

     1. If board is weak (less than 3 anchors), don't consider hitting on
        points 22 and 23.
     2. Dont break anchors inside home to hit.
   */
  I_PIPLOSS,

  /* Number of rolls that hit at least one checker.
   */
  I_P1,

  /* Number of rolls that hit at least two checkers.
   */
  I_P2,

  /* How many rolls permit the back checker to escape (Normalized to [01])
   */
  I_BACKESCAPES,

  /* Maximum containment of opponent checkers, from our points 9 to op back 
     checker.
     
     Value is (1 - n/36), where n is number of rolls to escape.
   */
  I_ACONTAIN,
  
  /* Above squared */
  I_ACONTAIN2,

  /* Maximum containment, from our point 9 to home.
     Value is (1 - n/36), where n is number of rolls to escape.
   */
  I_CONTAIN,

  /* Above squared */
  I_CONTAIN2,

  /* For all checkers out of home, 
     sum (Number of rolls that let x escape * distance from home)

     Normalized by dividing by 3600.
  */
  I_MOBILITY,

  /* One sided moment.
     Let A be the point of weighted average: 
     A = sum of N(x) for all x) / nCheckers.
     
     Then for all x : A < N(x), M = (average (N(X) - A)^2)

     Diveded by 400 to normalize. 
   */
  I_MOMENT2,

  /* Average number of pips lost when on the bar.
     Normalized to [01]
  */
  I_ENTER,

  /* Probablity of one checker not entering from bar.
     1 - (1 - n/6)^2, where n is number of closed points in op home.
   */
  I_ENTER2,

  I_TIMING,
  
  I_BACKBONE,

  I_BACKG, 
  
  I_BACKG1,
  
  I_FREEPIP,
  
  I_BACKRESCAPES,
  
  MORE_INPUTS };

#define MINPPERPOINT 4

#define NUM_INPUTS ((25 * MINPPERPOINT + MORE_INPUTS) * 2)
#define NUM_RACE_INPUTS ( HALF_RACE_INPUTS * 2 )

#define DATABASE1_SIZE ( 54264 * 32 * 2 )
#define DATABASE2_SIZE ( 924 * 924 * 2 )
#define DATABASE_SIZE ( DATABASE1_SIZE + DATABASE2_SIZE )

static int anEscapes[ 0x1000 ];
static int anEscapes1[ 0x1000 ];

static neuralnet nnContact, nnRace, nnCrashed;

static neuralnet nnpContact, nnpRace, nnpCrashed;

bearoffcontext *pbcOS = NULL;
bearoffcontext *pbcTS = NULL;
bearoffcontext *pbc1 = NULL;
bearoffcontext *pbc2 = NULL;
bearoffcontext *apbcHyper[ 3 ] = { NULL, NULL, NULL };

static cache cEval;
#define PRUNE_CACHE
#if defined( PRUNE_CACHE )
static cache cpEval;
#endif
static int cCache;
volatile int fInterrupt = FALSE, fAction = FALSE;
void ( *fnAction )( void ) = NULL, ( *fnTick )( void ) = NULL;
static int iTick;

/* variation of backgammon used by gnubg */

bgvariation bgvDefault = VARIATION_STANDARD;

/* the number of chequers for the variations */

int anChequers[ NUM_VARIATIONS ] = { 15, 15, 1, 2, 3 };

const char *aszVariations[ NUM_VARIATIONS ] = {
  N_("Standard backgammon"),
  N_("Standard backgammon with Nackgammon starting position"),
  N_("1-chequer hypergammon"),
  N_("2-chequer hypergammon"),
  N_("3-chequer hypergammon") 
};

const char *aszVariationCommands[ NUM_VARIATIONS ] = {
  "standard", 
  "nackgammon", 
  "1-chequer-hypergammon",
  "2-chequer-hypergammon",
  "3-chequer-hypergammon"
};


cubeinfo ciCubeless = { 1, 0, 0, 0, { 0, 0 }, FALSE, FALSE, FALSE,
                        { 1.0, 1.0, 1.0, 1.0 }, VARIATION_STANDARD };

const char *aszEvalType[] = 
   { 
     N_ ("No evaluation"), 
     N_ ("Neural net evaluation"), 
     N_ ("Rollout")
   };

#if defined (REDUCTION_CODE)
static evalcontext ecBasic = { FALSE, 0, 0, TRUE, 0.0 };
#else
static evalcontext ecBasic = { FALSE, 0, FALSE, TRUE, 0.0 };
#endif

/* defaults for the filters  - 0 ply uses no filters */
movefilter
defaultFilters[MAX_FILTER_PLIES][MAX_FILTER_PLIES] = {
  { { 0,  8, 0.16f }, {  0, 0, 0 }, { 0, 0, 0    }, {  0, 0, 0 } } ,
  { { 0,  8, 0.16f }, { -1, 0, 0 }, { 0, 0, 0    }, {  0, 0, 0 } } , 
  { { 0,  8, 0.16f }, { -1, 0, 0 }, { 0, 2, 0.04f }, {  0, 0, 0 } }, 
  { { 0,  8, 0.16f }, { -1, 0, 0 }, { 0, 2, 0.04f }, { -1, 0, 0 } },
};

#if defined( REDUCTION_CODE )
static int nReductionGroup   = 0;

static int all_d1[] = { 1, 1, 1, 1, 1, 1, 
                        2, 2, 2, 2, 2, 
                        3, 3, 3, 3, 
                        4, 4, 4, 
                        5, 5, 
                        6 };
static int all_d2[] = { 1, 2, 3, 4, 5, 6,
                        2, 3, 4, 5, 6,
                        3, 4, 5, 6,
                        4, 5, 6,
                        5, 6,
                        6 };
static int all_wt[] = { 1, 2, 2, 2, 2, 2,
                        1, 2, 2, 2, 2,
                        1, 2, 2, 2, 
                        1, 2, 2,
                        1, 2,
                        1 };

static int half1_d1[] = { 6, 2, 6, 6, 5, 5, 5, 4, 4, 2 };
static int half1_d2[] = { 6, 2, 4, 3, 3, 2, 1, 3, 1, 1 };
static int half1_wt[] = { 1, 1, 2, 2, 2, 2, 2, 2, 2, 2 };
  
static int half2_d1[] = { 5, 4, 3, 1, 6, 6, 6, 5, 4, 3, 3 };
static int half2_d2[] = { 5, 4, 3, 1, 5, 2, 1, 4, 2, 2, 1 };
static int half2_wt[] = { 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2 };

static int third1_d1[] = { 2, 1, 6, 6, 5, 4, 4 };
static int third1_d2[] = { 2, 1, 5, 3, 1, 3, 2 };
static int third1_wt[] = { 1, 1, 2, 2, 2, 2, 2 };

static int third2_d1[] = { 6, 3, 6, 5, 5, 4, 2 };
static int third2_d2[] = { 6, 3, 4, 3, 2, 1, 1 };
static int third2_wt[] = { 1, 1, 2, 2, 2, 2, 2 };

static int third3_d1[] = { 5, 4, 6, 6, 5, 3, 3 };
static int third3_d2[] = { 5, 4, 2, 1, 4, 2, 1 };
static int third3_wt[] = { 1, 1, 2, 2, 2, 2, 2 };

static int quarter1_d1[] = { 6, 3, 1, 6, 5, 4 };
static int quarter1_d2[] = { 6, 3, 1, 1, 3, 2 };
static int quarter1_wt[] = { 1, 1, 1, 2, 2, 2 };
    
static int quarter2_d1[] = { 5, 6, 6, 5, 4 };
static int quarter2_d2[] = { 5, 3, 2, 2, 1 };
static int quarter2_wt[] = { 1, 2, 2, 2, 2 };

static int quarter3_d1[] = { 4, 6, 5, 3, 3 };
static int quarter3_d2[] = { 4, 4, 1, 2, 1 };
static int quarter3_wt[] = { 1, 2, 2, 2, 2 };
 
static int quarter4_d1[] = { 2, 6, 5, 4, 2 };
static int quarter4_d2[] = { 2, 5, 4, 3, 1 };
static int quarter4_wt[] = { 1, 2, 2, 2, 2 };

typedef struct {
    int numRolls;
    int *d1;
    int *d2;
    int *wt;
} laRollList_t;

static laRollList_t halfLists[ 2 ] = {
  { 10, half1_d1, half1_d2, half1_wt },
  { 11, half2_d1, half2_d2, half2_wt } 
};

static  laRollList_t thirdLists[3] = {
  {  7, third1_d1, third1_d2, third1_wt },
  {  7, third2_d1, third2_d2, third2_wt },
  {  7, third3_d1, third3_d2, third3_wt } 
};

static laRollList_t quarterLists[4] = {
  {  6, quarter1_d1, quarter1_d2, quarter1_wt },
  {  5, quarter2_d1, quarter2_d2, quarter2_wt },
  {  5, quarter3_d1, quarter3_d2, quarter3_wt },
  {  5, quarter4_d1, quarter4_d2, quarter4_wt } 
};

static  laRollList_t allLists[ 1 ] = { 
  { 21, all_d1, all_d2, all_wt } 
};

static laRollList_t *rollLists[] = {
  allLists, allLists, halfLists, thirdLists, quarterLists };

#endif

/* Random context, for generating non-deterministic noisy evaluations. */
static randctx rc;

/*
 * predefined settings 
 */

const char *aszSettings[ NUM_SETTINGS ] = {
  N_ ("beginner"), 
  N_ ("casual play"), 
  N_ ("intermediate"), 
  N_ ("advanced"), 
  N_ ("expert"), 
  N_ ("world class"),
  N_ ("supremo"),
  N_ ("grandmaster") };

/* which evaluation context does the predefined settings use */
#if defined (REDUCTION_CODE)
evalcontext aecSettings[ NUM_SETTINGS ] = {
  { TRUE, 0, 0, TRUE, 0.060f }, /* casual play */
  { TRUE, 0, 0, TRUE, 0.050f }, /* beginner */
  { TRUE, 0, 0, TRUE, 0.040f }, /* intermediate */
  { TRUE, 0, 0, TRUE, 0.015f }, /* advanced */
  { TRUE, 0, 0, TRUE, 0.0f }, /* expert */
  { TRUE, 2, 0, TRUE, 0.0f }, /* world class */
  { TRUE, 2, 0, TRUE, 0.0f }, /* supremo */
  { TRUE, 3, 0, TRUE, 0.0f }, /* grand master */
};

#else
evalcontext aecSettings[ NUM_SETTINGS ] = {
  { TRUE, 0, FALSE, TRUE, 0.060f }, /* casual play */
  { TRUE, 0, FALSE, TRUE, 0.050f }, /* beginner */
  { TRUE, 0, FALSE, TRUE, 0.040f }, /* intermediate */
  { TRUE, 0, FALSE, TRUE, 0.015f }, /* advanced */
  { TRUE, 0, FALSE, TRUE, 0.0f }, /* expert */
  { TRUE, 2, TRUE, TRUE, 0.0f }, /* world class */
  { TRUE, 2, TRUE, TRUE, 0.0f }, /* supremo */
  { TRUE, 3, TRUE, TRUE, 0.0f }, /* grand master */
};
#endif
/* which move filter does the predefined settings use */

int aiSettingsMoveFilter[ NUM_SETTINGS ] = {
  -1, /* beginner: n/a */
  -1, /* casual play: n/a */
  -1, /* intermediate: n/a */
  -1, /* advanced: n/a */
  -1, /* expoert: n/a */
  2,  /* wc: normal */
  3,  /* supremo: large */
  2,  /* grandmaster: normal */
};

/* the predefined move filters */

const char *aszMoveFilterSettings[ NUM_MOVEFILTER_SETTINGS ] = {
  N_("Tiny"),
  N_("Narrow"),
  N_("Normal"),
  N_("Large"),
  N_("Huge")
};

movefilter aaamfMoveFilterSettings[ NUM_MOVEFILTER_SETTINGS ][ MAX_FILTER_PLIES ][ MAX_FILTER_PLIES ] = {
  /* tiny */
  { { { 0,  5, 0.08f }, {  0, 0, 0 }, { 0, 0, 0    }, {  0, 0, 0 } } ,
    { { 0,  5, 0.08f }, { -1, 0, 0 }, { 0, 0, 0    }, {  0, 0, 0 } } , 
    { { 0,  5, 0.08f }, { -1, 0, 0 }, { 0, 2, 0.02f }, {  0, 0, 0 } }, 
    { { 0,  5, 0.08f }, { -1, 0, 0 }, { 0, 2, 0.02f }, { -1 , 0, 0 } } },
  /* narrow */
  { { { 0,  8, 0.12f }, {  0, 0, 0 }, { 0, 0, 0    }, {  0, 0, 0 } } ,
    { { 0,  8, 0.12f }, { -1, 0, 0 }, { 0, 0, 0    }, {  0, 0, 0 } } , 
    { { 0,  8, 0.12f }, { -1, 0, 0 }, { 0, 2, 0.03f }, {  0, 0, 0 } }, 
    { { 0,  8, 0.12f }, { -1, 0, 0 }, { 0, 2, 0.03f }, { -1, 0, 0 } } },
  /* normal */
  { { { 0,  8, 0.16f }, {  0, 0, 0 }, { 0, 0, 0    }, {  0, 0, 0 } } ,
    { { 0,  8, 0.16f }, { -1, 0, 0 }, { 0, 0, 0    }, {  0, 0, 0 } } , 
    { { 0,  8, 0.16f }, { -1, 0, 0 }, { 0, 2, 0.04f }, {  0, 0, 0 } }, 
    { { 0,  8, 0.16f }, { -1, 0, 0 }, { 0, 2, 0.04f }, { -1, 0, 0 } } },
  /* large */
  { { { 0, 16, 0.32f }, {  0, 0, 0 }, { 0, 0, 0    }, {  0, 0, 0 } } ,
    { { 0, 16, 0.32f }, { -1, 0, 0 }, { 0, 0, 0    }, {  0, 0, 0 } } , 
    { { 0, 16, 0.32f }, { -1, 0, 0 }, { 0, 4, 0.08f }, {  0, 0, 0 } }, 
    { { 0, 16, 0.32f }, { -1, 0, 0 }, { 0, 4, 0.08f }, { -1, 0, 0.0f } } },
  /* huge */
  { { { 0, 20, 0.44f }, {  0, 0, 0 }, { 0, 0, 0    }, {  0, 0, 0 } } ,
    { { 0, 20, 0.44f }, { -1, 0, 0 }, { 0, 0, 0    }, {  0, 0, 0 } } , 
    { { 0, 20, 0.44f }, { -1, 0, 0 }, { 0, 6, 0.11f }, {  0, 0, 0 } }, 
    { { 0, 20, 0.44f }, { -1, 0, 0 }, { 0, 6, 0.11f }, { -1, 0, 0.0 } } }
};


const char *aszDoubleTypes[ NUM_DOUBLE_TYPES ] = {
  N_("Double"),
  N_("Beaver"),
  N_("Raccoon")
};

/* parameters for EvalEfficiency */

float rOSCubeX = 0.6f;
float rRaceFactorX = 0.00125f;
float rRaceCoefficientX = 0.55f;
float rRaceMax = 0.7f;
float rRaceMin = 0.6f;
float rCrashedX = 0.68f;
float rContactX = 0.68f;


static void ComputeTable0( void )
{
  int i, c, n0, n1;

  for( i = 0; i < 0x1000; i++ ) {
    c = 0;
	
    for( n0 = 0; n0 <= 5; n0++ )
      for( n1 = 0; n1 <= n0; n1++ )
		if( !( i & ( 1 << ( n0 + n1 + 1 ) ) ) &&
		    !( ( i & ( 1 << n0 ) ) && ( i & ( 1 << n1 ) ) ) )
		  c += ( n0 == n1 ) ? 1 : 2;
	
    anEscapes[ i ] = c;
  }
}

static int Escapes( const int anBoard[ 25 ], int n ) {
    
    int i, af = 0;
    
    for( i = 0; i < 12 && i < n; i++ )
		if( anBoard[ 24 - n + i ] > 1 )
		    af |= ( 1 << i );
    
    return anEscapes[ af ];
}

static void ComputeTable1( void )
{
  int i, c, n0, n1, low;

  anEscapes1[ 0 ] = 0;
  
  for( i = 1; i < 0x1000; i++ ) {
    c = 0;

    low = 0;
    while( ! (i & (1 << low)) ) {
      ++low;
    }
    
    for( n0 = 0; n0 <= 5; n0++ )
      for( n1 = 0; n1 <= n0; n1++ ) {
	
		if( (n0 + n1 + 1 > low) &&
		    !( i & ( 1 << ( n0 + n1 + 1 ) ) ) &&
			!( ( i & ( 1 << n0 ) ) && ( i & ( 1 << n1 ) ) ) ) {
		  c += ( n0 == n1 ) ? 1 : 2;
		}
      }
	
    anEscapes1[ i ] = c;
  }
}

static int Escapes1( const int anBoard[ 25 ], int n ) {
    
    int i, af = 0;
    
    for( i = 0; i < 12 && i < n; i++ )
	if( anBoard[ 24 - n + i ] > 1 )
	    af |= ( 1 << i );
    
    return anEscapes1[ af ];
}


static void ComputeTable( void )
{
  ComputeTable0();
  ComputeTable1();
}


static NNState nnStatesStorage[3] = {{NNSTATE_NONE}, {NNSTATE_NONE}, {NNSTATE_NONE}};

static void
CreateWeights(int nSize)
{
  NeuralNetCreate( &nnContact, NUM_INPUTS, nSize,
		   NUM_OUTPUTS, BETA_HIDDEN, BETA_OUTPUT );
	
  NeuralNetCreate( &nnCrashed, NUM_INPUTS, nSize,
		   NUM_OUTPUTS, BETA_HIDDEN, BETA_OUTPUT );
  
  NeuralNetCreate( &nnRace, NUM_RACE_INPUTS, nSize,
		   NUM_OUTPUTS, BETA_HIDDEN, BETA_OUTPUT );
}

static void
DestroyWeights( void )
{
  NeuralNetDestroy( &nnContact );
  NeuralNetDestroy( &nnCrashed );
  NeuralNetDestroy( &nnRace );

  NeuralNetDestroy( &nnpContact );
  NeuralNetDestroy( &nnpCrashed );
  NeuralNetDestroy( &nnpRace );
}

extern int
EvalNewWeights(int nSize)
{
  DestroyWeights();
  CreateWeights( nSize );
    
  return 0;
}


extern int
EvalShutdown ( void ) {

  int i;

	for (i = 0; i < 3; i++)
	{
		free(nnStatesStorage[i].savedBase); 
		free(nnStatesStorage[i].savedIBase);
	}

  /* close bearoff databases */

  BearoffClose( &pbc1 );
  BearoffClose( &pbc2 );
  BearoffClose( &pbcOS );
  BearoffClose( &pbcTS );
  for ( i = 0; i < 3; ++i )
    BearoffClose( &apbcHyper[ i ] );

  /* destroy neural nets */

  DestroyWeights();

  /* destroy cache */

  CacheDestroy( &cEval );
#if defined( PRUNE_CACHE )
  CacheDestroy( &cpEval );
#endif

  return 0;

}

int binary_weights_failed(char * filename, FILE * weights)
{
	float r;

	if (!weights)
	{
		g_print("%s", filename);
		return -1;
	}
	if (fread(&r, sizeof r, 1, weights) < 1) {
		g_print("%s", filename);
		return -2;
	}
	if (r != WEIGHTS_MAGIC_BINARY) {
		g_print(_("%s: not a weights file\n"), filename);
		return -3;
	}
	if (fread(&r, sizeof r, 1, weights) < 1) {
		g_print("%s", filename);
		return -4;
	}
	if (r != WEIGHTS_VERSION_BINARY) {
		g_print(_("%s: incorrect weights version (version %s "
			     " is required, but these weights "
			     "are %.2f)\n"), filename, WEIGHTS_VERSION,
			   r);
		return -5;
	}

	return 0;
}

int weights_failed(char * filename, FILE * weights)
{
	char file_version[16];
	if (!weights)
	{
		g_print("%s", filename);
		return -1;
	}

	if( fscanf( weights, "GNU Backgammon %15s\n",
				file_version ) != 1 )
	{
		g_print(_("%s: not a weights file\n"), filename );
		return -2;
	}
	if( strcmp( file_version, WEIGHTS_VERSION ) )
	{
		g_print(_("%s: incorrect weights version (version "
					"%s is required,\nbut these weights "
					"are %s)\n"), 
				filename, WEIGHTS_VERSION, file_version );
		return -3;
	}
	return 0;
}

int (*NeuralNetEvaluateFn)( const neuralnet *pnn, float arInput[],
			      float arOutput[], NNState *pnState) = 0;

extern int EvalInitialise(char *szWeights, char *szWeightsBinary,
			  int fNoBearoff, int nSize,
			  void (*pfProgress) (int))
{
    FILE *pfWeights = NULL;
    int h, i, fReadWeights = FALSE;
    static int fInitialised = FALSE;
    int ret;
    char *gnubg_bearoff;
    char *gnubg_bearoff_os;

    if( !fInitialised ) {

		NeuralNetEvaluateFn = NeuralNetEvaluate;

      /* initialise table for sigmoid */

      ComputeSigTable();

		cCache = 0x1 << 16;
		if( CacheCreate( &cEval, cCache ) ) {
		return -1;
		}

#if defined( PRUNE_CACHE )
	if( CacheCreate( &cpEval, 0x1 << 16) ) {
	  return -1;
	}
#endif
	    
		ComputeTable();

		rc.randrsl[ 0 ] = time( NULL );
		for( i = 0; i < RANDSIZ; i++ )
			rc.randrsl[ i ] = rc.randrsl[ 0 ];
		irandinit( &rc, TRUE );
		
		fInitialised = TRUE;
    }

    if( ! fNoBearoff ) {
#if USE_BUILTIN_BEAROFF
      /* read one-sided db from gnubg.bd */
	pbc1 = BearoffInitBuiltin();
#endif
	gnubg_bearoff_os = g_build_filename(PKGDATADIR, "gnubg_os0.bd", NULL);
	if( !pbc1 )
	    pbc1 = BearoffInit( gnubg_bearoff_os, BO_IN_MEMORY, NULL );
	g_free(gnubg_bearoff_os);

	if( !pbc1 )
	    pbc1 = BearoffInit ( NULL, BO_HEURISTIC, pfProgress );
	
	/* read two-sided db from gnubg.bd */
	gnubg_bearoff = g_build_filename(PKGDATADIR, "gnubg_ts0.bd", NULL);
	pbc2 = BearoffInit ( gnubg_bearoff, BO_IN_MEMORY | BO_MUST_BE_TWO_SIDED, NULL );
        g_free(gnubg_bearoff);
	
	if ( ! pbc2 )
	    fprintf ( stderr, 
		      "\n***WARNING***\n\n" 
		      "Note that gnubg does not use the gnubg.bd file.\n"
		      "You should obtain the file gnubg_ts0.bd or generate\n"
		      "it yourself using the program 'makebearoff'.\n"
		      "You can generate the file with the command:\n"
		      "makebearoff -t 6x6 -f gnubg_ts0.bd\n"
		      "You can also generate other bearoff databases; see\n"
		      "README for more details\n\n" );
	
	/* init one-sided db */
	pbcOS = BearoffInit ( "gnubg_os.bd", BO_NONE, NULL );
	
	/* init two-sided db */
	pbcTS = BearoffInit ( "gnubg_ts.bd", BO_NONE, NULL );

        /* hyper-gammon databases */

        for ( i = 0; i < 3; ++i ) {
          char sz[ 10 ];
          sprintf( sz, "hyper%1d.bd", i + 1 );
          apbcHyper[ i ] = BearoffInit( sz, BO_NONE, NULL );
        }

    }

    if( szWeightsBinary)
    { 
	    h = open( szWeightsBinary, O_RDONLY | BINARY );
	    if (h)
		    pfWeights = fdopen( h, "rb" );
	    if (!binary_weights_failed(szWeightsBinary, pfWeights))
	    {
		    if( !fReadWeights && !( fReadWeights =
					    !NeuralNetLoadBinary(&nnContact, pfWeights ) &&
					    !NeuralNetLoadBinary(&nnRace, pfWeights ) &&
					    !NeuralNetLoadBinary(&nnCrashed, pfWeights ) &&

					    !NeuralNetLoadBinary(&nnpContact, pfWeights ) &&
					    !NeuralNetLoadBinary(&nnpCrashed, pfWeights ) &&
					    !NeuralNetLoadBinary(&nnpRace, pfWeights ) ) ) { 
			    perror( szWeightsBinary );
		    }
	    }
	    fclose( pfWeights );
    }

    if( !fReadWeights && szWeights ) {
	    h = open( szWeights, O_RDONLY);
	    if (h)
		    pfWeights = fdopen( h, "r" );
	    if (!binary_weights_failed(szWeights, pfWeights))
	    {
		    if( !( fReadWeights =
					    !NeuralNetLoad( &nnContact, pfWeights ) &&
					    !NeuralNetLoad( &nnRace, pfWeights ) &&
					    !NeuralNetLoad( &nnCrashed, pfWeights ) &&

					    !NeuralNetLoad( &nnpContact, pfWeights ) &&
					    !NeuralNetLoad( &nnpCrashed, pfWeights ) &&
					    !NeuralNetLoad( &nnpRace, pfWeights ) 
			 ) )
			    perror( szWeights );

	    }
	    fclose( pfWeights );
    }

    if( fReadWeights ) {
		if( nnContact.cInput != NUM_INPUTS ||
			nnContact.cOutput != NUM_OUTPUTS )
			if (NeuralNetResize( &nnContact, NUM_INPUTS, nnContact.cHidden,
					NUM_OUTPUTS ) == -1)
					return -1;
		
		if( nnCrashed.cInput != NUM_INPUTS ||
			nnCrashed.cOutput != NUM_OUTPUTS )
			if (NeuralNetResize( &nnCrashed, NUM_INPUTS, nnCrashed.cHidden,
					NUM_OUTPUTS ) == -1)
					return -1;
		
		if( nnRace.cInput != NUM_RACE_INPUTS ||
			nnRace.cOutput != NUM_OUTPUTS )
			if (NeuralNetResize( &nnRace, NUM_RACE_INPUTS, nnRace.cHidden,
					NUM_OUTPUTS ) == -1)
					return -1;

		ret = 0;
    } else {
		CreateWeights( nSize );

		ret = 1;
	}

	nnStatesStorage[CLASS_RACE - CLASS_RACE].savedBase = malloc( nnRace.cHidden * sizeof( float ) ); 
	nnStatesStorage[CLASS_RACE - CLASS_RACE].savedIBase = malloc( nnRace.cInput * sizeof( float ) ); 
	nnStatesStorage[CLASS_CRASHED - CLASS_RACE].savedBase = malloc( nnCrashed.cHidden * sizeof( float ) ); 
	nnStatesStorage[CLASS_CRASHED - CLASS_RACE].savedIBase = malloc( nnCrashed.cInput * sizeof( float ) ); 
	nnStatesStorage[CLASS_CONTACT - CLASS_RACE].savedBase = malloc( nnContact.cHidden * sizeof( float ) ); 
	nnStatesStorage[CLASS_CONTACT - CLASS_RACE].savedIBase = malloc( nnContact.cInput * sizeof( float ) ); 

	return ret;
}

extern int EvalSave( const char *szWeights ) {
    
  FILE *pfWeights;
    
  if( !( pfWeights = fopen( szWeights, "w" ) ) )
    return -1;
    
  fprintf( pfWeights, "GNU Backgammon %s\n", WEIGHTS_VERSION );

  if (NeuralNetSave( &nnContact, pfWeights ) == -1)
	  return -1;
  if (NeuralNetSave( &nnRace, pfWeights ) == -1)
	  return -1;
  if (NeuralNetSave( &nnCrashed, pfWeights ) == -1)
	  return -1;

  if (NeuralNetSave( &nnpContact, pfWeights ) == -1)
	  return -1;
  if (NeuralNetSave( &nnpCrashed, pfWeights ) == -1)
	  return -1;
  if (NeuralNetSave( &nnpRace, pfWeights ) == -1)
	  return -1;
  
  fclose( pfWeights );

  return 0;
}


/* Calculates inputs for any contact position, for one player only. */

static void
CalculateHalfInputs( int anBoard[ 25 ], int anBoardOpp[ 25 ], float afInput[] )
{
  int i, j, k, l, nOppBack, n, aHit[ 39 ], nBoard;
    
  /* aanCombination[n] -
     How many ways to hit from a distance of n pips.
     Each number is an index into aIntermediate below. 
  */
  static const int aanCombination[ 24 ][ 5 ] = {
    {  0, -1, -1, -1, -1 }, /*  1 */
    {  1,  2, -1, -1, -1 }, /*  2 */
    {  3,  4,  5, -1, -1 }, /*  3 */
    {  6,  7,  8,  9, -1 }, /*  4 */
    { 10, 11, 12, -1, -1 }, /*  5 */
    { 13, 14, 15, 16, 17 }, /*  6 */
    { 18, 19, 20, -1, -1 }, /*  7 */
    { 21, 22, 23, 24, -1 }, /*  8 */
    { 25, 26, 27, -1, -1 }, /*  9 */
    { 28, 29, -1, -1, -1 }, /* 10 */
    { 30, -1, -1, -1, -1 }, /* 11 */
    { 31, 32, 33, -1, -1 }, /* 12 */
    { -1, -1, -1, -1, -1 }, /* 13 */
    { -1, -1, -1, -1, -1 }, /* 14 */
    { 34, -1, -1, -1, -1 }, /* 15 */
    { 35, -1, -1, -1, -1 }, /* 16 */
    { -1, -1, -1, -1, -1 }, /* 17 */
    { 36, -1, -1, -1, -1 }, /* 18 */
    { -1, -1, -1, -1, -1 }, /* 19 */
    { 37, -1, -1, -1, -1 }, /* 20 */
    { -1, -1, -1, -1, -1 }, /* 21 */
    { -1, -1, -1, -1, -1 }, /* 22 */
    { -1, -1, -1, -1, -1 }, /* 23 */
    { 38, -1, -1, -1, -1 } /* 24 */
  };
    
  /* One way to hit */ 
  typedef struct _Inter {
    /* if true, all intermediate points (if any) are required;
       if false, one of two intermediate points are required.
       Set to true for a direct hit, but that can be checked with
       nFaces == 1,
    */
    int fAll;

    /* Intermediate points required */
    int anIntermediate[ 3 ];

    /* Number of faces used in hit (1 to 4) */
    int nFaces;

    /* Number of pips used to hit */
    int nPips;
  } Inter;
  
  const Inter *pi;
      /* All ways to hit */
  static const Inter aIntermediate[ 39 ] = {
	{ 1, { 0, 0, 0 }, 1, 1 }, /*  0: 1x hits 1 */
	{ 1, { 0, 0, 0 }, 1, 2 }, /*  1: 2x hits 2 */
	{ 1, { 1, 0, 0 }, 2, 2 }, /*  2: 11 hits 2 */
	{ 1, { 0, 0, 0 }, 1, 3 }, /*  3: 3x hits 3 */
	{ 0, { 1, 2, 0 }, 2, 3 }, /*  4: 21 hits 3 */
	{ 1, { 1, 2, 0 }, 3, 3 }, /*  5: 11 hits 3 */
	{ 1, { 0, 0, 0 }, 1, 4 }, /*  6: 4x hits 4 */
	{ 0, { 1, 3, 0 }, 2, 4 }, /*  7: 31 hits 4 */
	{ 1, { 2, 0, 0 }, 2, 4 }, /*  8: 22 hits 4 */
	{ 1, { 1, 2, 3 }, 4, 4 }, /*  9: 11 hits 4 */
	{ 1, { 0, 0, 0 }, 1, 5 }, /* 10: 5x hits 5 */
	{ 0, { 1, 4, 0 }, 2, 5 }, /* 11: 41 hits 5 */
	{ 0, { 2, 3, 0 }, 2, 5 }, /* 12: 32 hits 5 */
	{ 1, { 0, 0, 0 }, 1, 6 }, /* 13: 6x hits 6 */
	{ 0, { 1, 5, 0 }, 2, 6 }, /* 14: 51 hits 6 */
	{ 0, { 2, 4, 0 }, 2, 6 }, /* 15: 42 hits 6 */
	{ 1, { 3, 0, 0 }, 2, 6 }, /* 16: 33 hits 6 */
	{ 1, { 2, 4, 0 }, 3, 6 }, /* 17: 22 hits 6 */
	{ 0, { 1, 6, 0 }, 2, 7 }, /* 18: 61 hits 7 */
	{ 0, { 2, 5, 0 }, 2, 7 }, /* 19: 52 hits 7 */
	{ 0, { 3, 4, 0 }, 2, 7 }, /* 20: 43 hits 7 */
	{ 0, { 2, 6, 0 }, 2, 8 }, /* 21: 62 hits 8 */
	{ 0, { 3, 5, 0 }, 2, 8 }, /* 22: 53 hits 8 */
	{ 1, { 4, 0, 0 }, 2, 8 }, /* 23: 44 hits 8 */
	{ 1, { 2, 4, 6 }, 4, 8 }, /* 24: 22 hits 8 */
	{ 0, { 3, 6, 0 }, 2, 9 }, /* 25: 63 hits 9 */
	{ 0, { 4, 5, 0 }, 2, 9 }, /* 26: 54 hits 9 */
	{ 1, { 3, 6, 0 }, 3, 9 }, /* 27: 33 hits 9 */
	{ 0, { 4, 6, 0 }, 2, 10 }, /* 28: 64 hits 10 */
	{ 1, { 5, 0, 0 }, 2, 10 }, /* 29: 55 hits 10 */
	{ 0, { 5, 6, 0 }, 2, 11 }, /* 30: 65 hits 11 */
	{ 1, { 6, 0, 0 }, 2, 12 }, /* 31: 66 hits 12 */
	{ 1, { 4, 8, 0 }, 3, 12 }, /* 32: 44 hits 12 */
	{ 1, { 3, 6, 9 }, 4, 12 }, /* 33: 33 hits 12 */
	{ 1, { 5, 10, 0 }, 3, 15 }, /* 34: 55 hits 15 */
	{ 1, { 4, 8, 12 }, 4, 16 }, /* 35: 44 hits 16 */
	{ 1, { 6, 12, 0 }, 3, 18 }, /* 36: 66 hits 18 */
	{ 1, { 5, 10, 15 }, 4, 20 }, /* 37: 55 hits 20 */
	{ 1, { 6, 12, 18 }, 4, 24 }  /* 38: 66 hits 24 */
      };

  /* aaRoll[n] - All ways to hit with the n'th roll
     Each entry is an index into aIntermediate above.
  */
    
  const static int aaRoll[ 21 ][ 4 ] = {
    {  0,  2,  5,  9 }, /* 11 */
    {  0,  1,  4, -1 }, /* 21 */
    {  1,  8, 17, 24 }, /* 22 */
    {  0,  3,  7, -1 }, /* 31 */
    {  1,  3, 12, -1 }, /* 32 */
    {  3, 16, 27, 33 }, /* 33 */
    {  0,  6, 11, -1 }, /* 41 */
    {  1,  6, 15, -1 }, /* 42 */
    {  3,  6, 20, -1 }, /* 43 */
    {  6, 23, 32, 35 }, /* 44 */
    {  0, 10, 14, -1 }, /* 51 */
    {  1, 10, 19, -1 }, /* 52 */
    {  3, 10, 22, -1 }, /* 53 */
    {  6, 10, 26, -1 }, /* 54 */
    { 10, 29, 34, 37 }, /* 55 */
    {  0, 13, 18, -1 }, /* 61 */
    {  1, 13, 21, -1 }, /* 62 */
    {  3, 13, 25, -1 }, /* 63 */
    {  6, 13, 28, -1 }, /* 64 */
    { 10, 13, 30, -1 }, /* 65 */
    { 13, 31, 36, 38 }  /* 66 */
  };

  /* One roll stat */
  
  struct {
    /* count of pips this roll hits */
    int nPips;
      
    /* number of chequers this roll hits */
    int nChequers;
  } aRoll[ 21 ];

  for(nOppBack = 24; nOppBack >= 0; --nOppBack) {
    if( anBoardOpp[nOppBack] ) {
      break;
    }
  }
    
  nOppBack = 23 - nOppBack;

  n = 0;
  for( i = nOppBack + 1; i < 25; i++ )
    if( anBoard[ i ] )
      n += ( i + 1 - nOppBack ) * anBoard[ i ];

	  g_assert( n );
    
  afInput[ I_BREAK_CONTACT ] = n / (15 + 152.0);

  {
    unsigned int p  = 0;
    
    for( i = 0; i < nOppBack; i++ ) {
      if( anBoard[i] )
		p += (i+1) * anBoard[i];
    }
    
    afInput[I_FREEPIP] = p / 100.0;
  }

  {
    int t = 0;
    
    int no = 0;
      
    t += 24 * anBoard[24];
    no += anBoard[24];
      
    for( i = 23;  i >= 12 && i > nOppBack; --i ) {
      if( anBoard[i] && anBoard[i] != 2 ) {
		int n = ((anBoard[i] > 2) ? (anBoard[i] - 2) : 1);
		no += n;
		t += i * n;
      }
    }

    for( ; i >= 6; --i ) {
      if( anBoard[i] ) {
	int n = anBoard[i];
	no += n;
	t += i * n;
      }
    }
    
    for( i = 5;  i >= 0; --i ) {
      if( anBoard[i] > 2 ) {
	t += i * (anBoard[i] - 2);
	no += (anBoard[i] - 2);
      } else if( anBoard[i] < 2 ) {
	int n = (2 - anBoard[i]);

	if( no >= n ) {
	  t -= i * n;
	  no -= n;
	}
      }
    }

    if( t < 0 ) {
      t = 0;
    }

    afInput[ I_TIMING ] = t / 100.0;
  }

  /* Back chequer */

  {
    int nBack;
    
    for( nBack = 24; nBack >= 0; --nBack ) {
      if( anBoard[nBack] ) {
	break;
      }
    }
    
    afInput[ I_BACK_CHEQUER ] = nBack / 24.0;

    /* Back anchor */

    for( i = nBack == 24 ? 23 : nBack; i >= 0; --i ) {
      if( anBoard[i] >= 2 ) {
	break;
      }
    }
    
    afInput[ I_BACK_ANCHOR ] = i / 24.0;
    
    /* Forward anchor */

    n = 0;
    for( j = 18; j <= i; ++j ) {
      if( anBoard[j] >= 2 ) {
	n = 24 - j;
	break;
      }
    }

    if( n == 0 ) {
      for( j = 17; j >= 12 ; --j ) {
	if( anBoard[j] >= 2 ) {
	  n = 24 - j;
	  break;
	}
      }
    }
	
    afInput[ I_FORWARD_ANCHOR ] = n == 0 ? 2.0 : n / 6.0;
  }
    

  /* Piploss */
    
  nBoard = 0;
  for( i = 0; i < 6; i++ )
    if( anBoard[ i ] )
      nBoard++;

    memset(aHit, 0, sizeof(aHit));
    
    /* for every point we'd consider hitting a blot on, */
    
  for( i = ( nBoard > 2 ) ? 23 : 21; i >= 0; i-- )
    /* if there's a blot there, then */
      
    if( anBoardOpp[ i ] == 1 )
      /* for every point beyond */
	
      for( j = 24 - i; j < 25; j++ )
	/* if we have a hitter and are willing to hit */
	  
	if( anBoard[ j ] && !( j < 6 && anBoard[ j ] == 2 ) )
	  /* for every roll that can hit from that point */
	    
	  for( n = 0; n < 5; n++ ) {
	    if( aanCombination[ j - 24 + i ][ n ] == -1 )
	      break;

	    /* find the intermediate points required to play */
	      
	    pi = aIntermediate + aanCombination[ j - 24 + i ][ n ];

	    if( pi->fAll ) {
	      /* if nFaces is 1, there are no intermediate points */
		
	      if( pi->nFaces > 1 ) {
		/* all the intermediate points are required */
		  
		for( k = 0; k < 3 && pi->anIntermediate[k] > 0; k++ )
		  if( anBoardOpp[ i - pi->anIntermediate[ k ] ] > 1 )
		    /* point is blocked; look for other hits */
		    goto cannot_hit;
	      }
	    } else {
	      /* either of two points are required */
		
	      if( anBoardOpp[ i - pi->anIntermediate[ 0 ] ] > 1
		  && anBoardOpp[ i - pi->anIntermediate[ 1 ] ] > 1 ) {
				/* both are blocked; look for other hits */
		goto cannot_hit;
	      }
	    }
	      
	    /* enter this shot as available */
	      
	    aHit[ aanCombination[ j - 24 + i ][ n ] ] |= 1 << j;
	  cannot_hit: ;
	  }

  memset(aRoll, 0, sizeof(aRoll));
    
  if( !anBoard[ 24 ] ) {
    /* we're not on the bar; for each roll, */
      
    for( i = 0; i < 21; i++ ) {
      n = -1; /* (hitter used) */
	
      /* for each way that roll hits, */
      for( j = 0; j < 4; j++ ) {
	int r = aaRoll[ i ][ j ];
	
	if( r < 0 )
	  break;

	if( !aHit[ r ] )
	  continue;

	pi = aIntermediate + r;
		
	if( pi->nFaces == 1 ) {
	  /* direct shot */
	  for( k = 23; k > 0; k-- ) {
	    if( aHit[ r ] & ( 1 << k ) ) {
	      /* select the most advanced blot; if we still have
		 a chequer that can hit there */
		      
	      if( n != k || anBoard[ k ] > 1 )
		aRoll[ i ].nChequers++;

	      n = k;

	      if( k - pi->nPips + 1 > aRoll[ i ].nPips )
		aRoll[ i ].nPips = k - pi->nPips + 1;
		
	      /* if rolling doubles, check for multiple
		 direct shots */
		      
	      if( aaRoll[ i ][ 3 ] >= 0 &&
		  aHit[ r ] & ~( 1 << k ) )
		aRoll[ i ].nChequers++;
			    
	      break;
	    }
	  }
	} else {
	  /* indirect shot */
	  if( !aRoll[ i ].nChequers )
	    aRoll[ i ].nChequers = 1;

	  /* find the most advanced hitter */
	    
	  for( k = 23; k >= 0; k-- )
	    if( aHit[ r ] & ( 1 << k ) )
	      break;

	  if( k - pi->nPips + 1 > aRoll[ i ].nPips )
	    aRoll[ i ].nPips = k - pi->nPips + 1;

	  /* check for blots hit on intermediate points */
		    
	  for( l = 0; l < 3 && pi->anIntermediate[ l ] > 0; l++ )
	    if( anBoardOpp[ 23 - k + pi->anIntermediate[ l ] ] == 1 ) {
		
	      aRoll[ i ].nChequers++;
	      break;
	    }
	}
      }
    }
  } else if( anBoard[ 24 ] == 1 ) {
    /* we have one on the bar; for each roll, */
      
    for( i = 0; i < 21; i++ ) {
      n = 0; /* (free to use either die to enter) */
	
      for( j = 0; j < 4; j++ ) {
	int r = aaRoll[ i ][ j ];
	
	if( r < 0 )
	  break;
		
	if( !aHit[ r ] )
	  continue;

	pi = aIntermediate + r;
		
	if( pi->nFaces == 1 ) {
	  /* direct shot */
	  
	  for( k = 24; k > 0; k-- ) {
	    if( aHit[ r ] & ( 1 << k ) ) {
	      /* if we need this die to enter, we can't hit elsewhere */
	      
	      if( n && k != 24 )
		break;
			    
	      /* if this isn't a shot from the bar, the
		 other die must be used to enter */
	      
	      if( k != 24 ) {
		int npip = aIntermediate[aaRoll[ i ][ 1 - j ] ].nPips;
		
		if( anBoardOpp[npip - 1] > 1 )
		  break;
				
		n = 1;
	      }

	      aRoll[ i ].nChequers++;

	      if( k - pi->nPips + 1 > aRoll[ i ].nPips )
		aRoll[ i ].nPips = k - pi->nPips + 1;
	    }
	  }
	} else {
	  /* indirect shot -- consider from the bar only */
	  if( !( aHit[ r ] & ( 1 << 24 ) ) )
	    continue;
		    
	  if( !aRoll[ i ].nChequers )
	    aRoll[ i ].nChequers = 1;
		    
	  if( 25 - pi->nPips > aRoll[ i ].nPips )
	    aRoll[ i ].nPips = 25 - pi->nPips;
		    
	  /* check for blots hit on intermediate points */
	  for( k = 0; k < 3 && pi->anIntermediate[ k ] > 0; k++ )
	    if( anBoardOpp[ pi->anIntermediate[ k ] + 1 ] == 1 ) {
		
	      aRoll[ i ].nChequers++;
	      break;
	    }
	}
      }
    }
  } else {
    /* we have more than one on the bar --
       count only direct shots from point 24 */
      
    for( i = 0; i < 21; i++ ) {
      /* for the first two ways that hit from the bar */
	
      for( j = 0; j < 2; j++ ) {
	int r = aaRoll[ i ][ j ];
	
	if( !( aHit[r] & ( 1 << 24 ) ) )
	  continue;

	pi = aIntermediate + r;

	/* only consider direct shots */
	
	if( pi->nFaces != 1 )
	  continue;

	aRoll[ i ].nChequers++;

	if( 25 - pi->nPips > aRoll[ i ].nPips )
	  aRoll[ i ].nPips = 25 - pi->nPips;
      }
    }
  }

  {
    int np = 0;
    int n1 = 0;
    int n2 = 0;
      
    for(i = 0; i < 21; i++) {
      int w = aaRoll[i][3] > 0 ? 1 : 2;
      int nc = aRoll[i].nChequers;
	
      np += aRoll[i].nPips * w;
	
      if( nc > 0 ) {
	n1 += w;

	if( nc > 1 ) {
	  n2 += w;
	}
      }
    }

    afInput[ I_PIPLOSS ] = np / ( 12.0 * 36.0 );
      
    afInput[ I_P1 ] = n1 / 36.0;
    afInput[ I_P2 ] = n2 / 36.0;
  }

  afInput[ I_BACKESCAPES ] = Escapes( anBoard, 23 - nOppBack ) / 36.0;

  afInput[ I_BACKRESCAPES ] = Escapes1( anBoard, 23 - nOppBack ) / 36.0;
  
  for( n = 36, i = 15; i < 24 - nOppBack; i++ )
    if( ( j = Escapes( anBoard, i ) ) < n )
      n = j;

  afInput[ I_ACONTAIN ] = ( 36 - n ) / 36.0;
  afInput[ I_ACONTAIN2 ] = afInput[ I_ACONTAIN ] * afInput[ I_ACONTAIN ];

  if( nOppBack < 0 ) {
    /* restart loop, point 24 should not be included */
    i = 15;
    n = 36;
  }
    
  for( ; i < 24; i++ )
    if( ( j = Escapes( anBoard, i ) ) < n )
      n = j;

    
  afInput[ I_CONTAIN ] = ( 36 - n ) / 36.0;
  afInput[ I_CONTAIN2 ] = afInput[ I_CONTAIN ] * afInput[ I_CONTAIN ];
    
  for( n = 0, i = 6; i < 25; i++ )
    if( anBoard[ i ] )
      n += ( i - 5 ) * anBoard[ i ] * Escapes( anBoardOpp, i );

  afInput[ I_MOBILITY ] = n / 3600.00;

  j = 0;
  n = 0; 
  for(i = 0; i < 25; i++ ) {
    int ni = anBoard[ i ];
      
    if( ni ) {
      j += ni;
      n += i * ni;
    }
  }

  if( j ) {
    n = (n + j - 1) / j;
  }

  j = 0;
  for(k = 0, i = n + 1; i < 25; i++ ) {
    int ni = anBoard[ i ];

    if( ni ) {
      j += ni;
      k += ni * ( i - n ) * ( i - n );
    }
  }

  if( j ) {
    k = (k + j - 1) / j;
  }

  afInput[ I_MOMENT2 ] = k / 400.0;

  if( anBoard[ 24 ] > 0 ) {
    int loss = 0;
    int two = anBoard[ 24 ] > 1;
      
    for(i = 0; i < 6; ++i) {
      if( anBoardOpp[ i ] > 1 ) {
	/* any double loses */
	  
	loss += 4*(i+1);

	for(j = i+1; j < 6; ++j) {
	  if( anBoardOpp[ j ] > 1 ) {
	    loss += 2*(i+j+2);
	  } else {
	    if( two ) {
	      loss += 2*(i+1);
	    }
	  }
	}
      } else {
	if( two ) {
	  for(j = i+1; j < 6; ++j) {
	    if( anBoardOpp[ j ] > 1 ) {
	      loss += 2*(j+1);
	    }
	  }
	}
      }
    }
      
    afInput[ I_ENTER ] = loss / (36.0 * (49.0/6.0));
  } else {
    afInput[ I_ENTER ] = 0.0;
  }

  n = 0;
  for(i = 0; i < 6; i++ ) {
    n += anBoardOpp[ i ] > 1;
  }
    
  afInput[ I_ENTER2 ] = ( 36 - ( n - 6 ) * ( n - 6 ) ) / 36.0; 

  {
    int pa = -1;
    int w = 0;
    int tot = 0;
    int np;
    
    for(np = 23; np > 0; --np) {
      if( anBoard[np] >= 2 ) {
	if( pa == -1 ) {
	  pa = np;
	  continue;
	}

	{
	  int d = pa - np;
	  int c = 0;
	
	  if( d <= 6 ) {
	    c = 11;
	  } else if( d <= 11 ) {
	    c = 13 - d;
	  }

	  w += c * anBoard[pa];
	  tot += anBoard[pa];
	}
      }
    }

    if( tot ) {
      afInput[I_BACKBONE] = 1 - (w / (tot * 11.0));
    } else {
      afInput[I_BACKBONE] = 0;
    }
  }

  {
    unsigned int nAc = 0;
    
    for( i = 18; i < 24; ++i ) {
      if( anBoard[i] > 1 ) {
	++nAc;
      }
    }
    
    afInput[I_BACKG] = 0.0;
    afInput[I_BACKG1] = 0.0;

    if( nAc >= 1 ) {
      unsigned int tot = 0;
      for( i = 18; i < 25; ++i ) {
	tot += anBoard[i];
      }

      if( nAc > 1 ) {
	/* g_assert( tot >= 4 ); */
      
	afInput[I_BACKG] = (tot - 3) / 4.0;
      } else if( nAc == 1 ) {
	afInput[I_BACKG1] = tot / 8.0;
      }
    }
  }
}


extern void 
CalculateRaceInputs(int anBoard[2][25], float inputs[])
{
  unsigned int side;
  
  for(side = 0; side < 2; ++side) {
    unsigned int i, k;

    const int* const board = anBoard[side];
    float* const afInput = inputs + side * HALF_RACE_INPUTS;

    unsigned int menOff = 15;
    
    {                             g_assert( board[23] == 0 && board[24] == 0 ); }
    
    /* Points */
    for(i = 0; i < 23; ++i) {
      unsigned int const nc = board[i];

      k = i * 4;

      menOff -= nc;
      
	  afInput[ k++ ] = (nc == 1) ? 1.0f : 0.0f;
      afInput[ k++ ] = (nc == 2) ? 1.0f : 0.0f;
      afInput[ k++ ] = (nc >= 3) ? 1.0f : 0.0f;
      afInput[ k ] = nc > 3 ? ( nc - 3 ) / 2.0f : 0.0f;
    }

    /* Men off */
    for(k = 0; k < 14; ++k) {
      afInput[ RI_OFF + k ] = (menOff == (k+1)) ? 1.0 : 0.0;
    }
    
    {
      unsigned int nCross = 0;
      
      for(k = 1; k < 4; ++k) {
	for(i = 6*k; i < 6*k + 6; ++i) {
	  unsigned int const nc = board[i];

	  if( nc ) {
	    nCross += nc * k;
	  }
	}
      }
      
      afInput[RI_NCROSS] = nCross / 10.0;
    }
  }
}

#if 0
float inpvec[16][4] = { 
/*  0 */				{ 0.0, 0.0, 0.0, 0.0 },
/*  1 */				{ 1.0, 0.0, 0.0, 0.0 },
/*  2 */				{ 0.0, 1.0, 0.0, 0.0 },
/*  3 */				{ 0.0, 0.0, 1.0, 0.0 },
/*  4 */				{ 0.0, 0.0, 1.0, 0.5 },
/*  5 */				{ 0.0, 0.0, 1.0, 1.0 },
/*  6 */				{ 0.0, 0.0, 1.0, 1.5 },
/*  7 */				{ 0.0, 0.0, 1.0, 2.0 },
/*  8 */				{ 0.0, 0.0, 1.0, 2.5 },
/*  9 */				{ 0.0, 0.0, 1.0, 3.0 },
/* 10 */				{ 0.0, 0.0, 1.0, 3.5 },
/* 11 */				{ 0.0, 0.0, 1.0, 4.0 },
/* 12 */				{ 0.0, 0.0, 1.0, 4.5 },
/* 13 */				{ 0.0, 0.0, 1.0, 5.0 },
/* 14 */				{ 0.0, 0.0, 1.0, 5.5 },
/* 15 */				{ 0.0, 0.0, 1.0, 6.0 } };

float inpvecb[16][4] = { 
/*  0 */				{ 0.0, 0.0, 0.0, 0.0 },
/*  1 */				{ 1.0, 0.0, 0.0, 0.0 },
/*  2 */				{ 1.0, 1.0, 0.0, 0.0 },
/*  3 */				{ 1.0, 1.0, 1.0, 0.0 },
/*  4 */				{ 1.0, 1.0, 1.0, 0.5 },
/*  5 */				{ 1.0, 1.0, 1.0, 1.0 },
/*  6 */				{ 1.0, 1.0, 1.0, 1.5 },
/*  7 */				{ 1.0, 1.0, 1.0, 2.0 },
/*  8 */				{ 1.0, 1.0, 1.0, 2.5 },
/*  9 */				{ 1.0, 1.0, 1.0, 3.0 },
/* 10 */				{ 1.0, 1.0, 1.0, 3.5 },
/* 11 */				{ 1.0, 1.0, 1.0, 4.0 },
/* 12 */				{ 1.0, 1.0, 1.0, 4.5 },
/* 13 */				{ 1.0, 1.0, 1.0, 5.0 },
/* 14 */				{ 1.0, 1.0, 1.0, 5.5 },
/* 15 */				{ 1.0, 1.0, 1.0, 6.0 } };

extern void
baseInputs(int anBoard[2][25], float arInput[])
{
  int i = 3;

	int *pB = &anBoard[0][0];
	float *pInput = &arInput[0];
	register __m128 vec0;
	register __m128 vec1;
	register __m128 vec2;
	register __m128 vec3;
	register __m128 vec4;
	register __m128 vec5;
	register __m128 vec6;
	register __m128 vec7;
	
	while ( i-- ){
					vec0 = _mm_load_ps(inpvec[*pB++]);
					_mm_store_ps(pInput , vec0 );
					vec1 = _mm_load_ps(inpvec[*pB++]);
					_mm_store_ps(pInput += 4 , vec1 );
					vec2 = _mm_load_ps(inpvec[*pB++]);
					_mm_store_ps(pInput += 4 , vec2 );
					vec3 = _mm_load_ps(inpvec[*pB++]);
					_mm_store_ps(pInput += 4 , vec3 );
					vec4 = _mm_load_ps(inpvec[*pB++]);
					_mm_store_ps(pInput += 4 , vec4 );
					vec5 = _mm_load_ps(inpvec[*pB++]);
					_mm_store_ps(pInput += 4 , vec5 );
					vec6 = _mm_load_ps(inpvec[*pB++]);
					_mm_store_ps(pInput += 4 , vec6 );
					vec7 = _mm_load_ps(inpvec[*pB++]);
					_mm_store_ps(pInput += 4 , vec7 );
					pInput += 4;
	}

	/* bar */
	vec0 = _mm_load_ps(inpvecb[*pB++]);
	_mm_store_ps(pInput, vec0 );
	pInput += 4;

	i = 3;
	while ( i-- ){
					vec0 = _mm_load_ps(inpvec[*pB++]);
					_mm_store_ps(pInput , vec0 );
					vec1 = _mm_load_ps(inpvec[*pB++]);
					_mm_store_ps(pInput += 4, vec1 );
					vec2 = _mm_load_ps(inpvec[*pB++]);
					_mm_store_ps(pInput += 4, vec2 );
					vec3 = _mm_load_ps(inpvec[*pB++]);
					_mm_store_ps(pInput += 4, vec3 );
					vec4 = _mm_load_ps(inpvec[*pB++]);
					_mm_store_ps(pInput += 4, vec4 );
					vec5 = _mm_load_ps(inpvec[*pB++]);
					_mm_store_ps(pInput += 4, vec5 );
					vec6 = _mm_load_ps(inpvec[*pB++]);
					_mm_store_ps(pInput += 4, vec6 );
					vec7 = _mm_load_ps(inpvec[*pB++]);
					_mm_store_ps(pInput += 4, vec7 );
					pInput += 4;
	}
	
	/* bar */
	vec0 = _mm_load_ps(inpvecb[*pB]);
	_mm_store_ps(pInput, vec0 );
	
	return;
}
#else
extern void
baseInputs(int anBoard[2][25], float arInput[])
{
  int j, i;
    
  for(j = 0; j < 2; ++j ) {
    float* afInput = arInput + j * 25*4;
    int* board = anBoard[j];
    
    /* Points */
    for( i = 0; i < 24; i++ ) {
      int nc = board[ i ];
      
      afInput[ i * 4 + 0 ] = (nc == 1) ? 1.0f : 0.0f;
      afInput[ i * 4 + 1 ] = (nc == 2) ? 1.0f : 0.0f;
      afInput[ i * 4 + 2 ] = (nc >= 3) ? 1.0f : 0.0f;
      afInput[ i * 4 + 3 ] = nc > 3 ? ( nc - 3 ) / 2.0f : 0.0f;
    }

    /* Bar */
    {
      int nc = board[ 24 ];
      
      afInput[ 24 * 4 + 0 ] = (nc >= 1) ? 1.0f : 0.0f;
      afInput[ 24 * 4 + 1 ] = (nc >= 2) ? 1.0f : 0.0f;
      afInput[ 24 * 4 + 2 ] = (nc >= 3) ? 1.0f : 0.0f;
      afInput[ 24 * 4 + 3 ] = nc > 3 ? ( nc - 3 ) / 2.0f : 0.0f;
    }
  }
}
#endif 

static void
menOffAll(const int* anBoard, float* afInput)
{
  /* Men off */
  int menOff = 15;
  int i;
  
  for(i = 0; i < 25; i++ ) {
    menOff -= anBoard[i];
  }

  if( menOff > 10 ) {
    afInput[ 0 ] = 1.0;
    afInput[ 1 ] = 1.0;
    afInput[ 2 ] = ( menOff - 10 ) / 5.0;
  } else if( menOff > 5 ) {
    afInput[ 0 ] = 1.0;
    afInput[ 1 ] = ( menOff - 5 ) / 5.0;
    afInput[ 2 ] = 0.0;
  } else {
    afInput[ 0 ] = menOff ? menOff / 5.0 : 0.0;
    afInput[ 1 ] = 0.0;
    afInput[ 2 ] = 0.0;
  }
}

static void
menOffNonCrashed(const int* anBoard, float* afInput)
{
  int menOff = 15;
  int i;
  
  for(i = 0; i < 25; ++i) {
    menOff -= anBoard[i];
  }
  {                                                   g_assert( menOff <= 8 ); }
    
  if( menOff > 5 ) {
    afInput[ 0 ] = 1.0;
    afInput[ 1 ] = 1.0;
    afInput[ 2 ] = ( menOff - 6 ) / 3.0;
  } else if( menOff > 2 ) {
    afInput[ 0 ] = 1.0;
    afInput[ 1 ] = ( menOff - 3 ) / 3.0;
    afInput[ 2 ] = 0.0;
  } else {
    afInput[ 0 ] = menOff ? menOff / 3.0 : 0.0;
    afInput[ 1 ] = 0.0;
    afInput[ 2 ] = 0.0;
  }
}

/* Calculates contact neural net inputs from the board position. */

static void
CalculateContactInputs(int anBoard[2][25], float arInput[])
{
  baseInputs(anBoard, arInput);

  {
    float* b = arInput + 4 * 25 * 2;
    
    /* I accidentally switched sides (0 and 1) when I trained the net */
    menOffNonCrashed(anBoard[0], b + I_OFF1);
  
    CalculateHalfInputs(anBoard[1], anBoard[0], b);
  }

  {
    float* b = arInput + (4 * 25 * 2 + MORE_INPUTS);

    menOffNonCrashed(anBoard[1], b + I_OFF1);
  
    CalculateHalfInputs( anBoard[0], anBoard[1], b);
  }
}

/* Calculates crashed neural net inputs from the board position. */

static void
CalculateCrashedInputs(int anBoard[2][25], float arInput[])
{
  baseInputs(anBoard, arInput);

  {
    float* b = arInput + 4 * 25 * 2;
    
    menOffAll(anBoard[1], b + I_OFF1);
  
    CalculateHalfInputs(anBoard[1], anBoard[0], b);
  }

  {
    float* b = arInput + (4 * 25 * 2 + MORE_INPUTS);

    menOffAll(anBoard[0], b + I_OFF1);
  
    CalculateHalfInputs( anBoard[0], anBoard[1], b);
  }
}

extern void swap_us( unsigned int *p0, unsigned int *p1 ) {
    unsigned int n = *p0;

    *p0 = *p1;
    *p1 = n;
}

extern void swap( int *p0, int *p1 ) {
    int n = *p0;

    *p0 = *p1;
    *p1 = n;
}

extern void SwapSides( int anBoard[ 2 ][ 25 ] ) {

    int i, n;

    for( i = 0; i < 25; i++ ) {
	n = anBoard[ 0 ][ i ];
	anBoard[ 0 ][ i ] = anBoard[ 1 ][ i ];
	anBoard[ 1 ][ i ] = n;
    }
}

extern void
SanityCheck( int anBoard[ 2 ][ 25 ], float arOutput[] )
{
  int i, j, ac[ 2 ], anBack[ 2 ], anCross[ 2 ], anGammonCross[ 2 ],
    anBackgammonCross[ 2 ], anMaxTurns[ 2 ], fContact;

  if( arOutput[ OUTPUT_WIN ] < 0.0f )
    arOutput[ OUTPUT_WIN ] = 0.0f;
  else if( arOutput[ OUTPUT_WIN ] > 1.0f )
    arOutput[ OUTPUT_WIN ] = 1.0f;
    
  ac[ 0 ] = ac[ 1 ] = anBack[ 0 ] = anBack[ 1 ] = anCross[ 0 ] =
    anCross[ 1 ] = anBackgammonCross[ 0 ] = anBackgammonCross[ 1 ] = 0;
  anGammonCross[ 0 ] = anGammonCross[ 1 ] = 1;
	
  for( j = 0; j < 2; j++ )
	for( i = 0; i < 25; i++ )
	    if( anBoard[ j ][ i ] ) {
		anBack[ j ] = i;
		ac[ j ] += anBoard[ j ][ i ];
		anCross[ j ] += ( i / 6 + 1 ) * anBoard[ j ][ i ];
		anGammonCross[ j ] += i / 6 * anBoard[ j ][ i ];
		if( i >= 18 )
		    anBackgammonCross[ j ] += ( i - 12 ) / 6 *
			anBoard[ j ][ i ];
	    }

  fContact = anBack[ 0 ] + anBack[ 1 ] >= 24;

  if( !fContact ) {
    for( i = 0; i < 2; i++ ) 
      if( anBack[ i ] < 6 && pbc1 )
	anMaxTurns[ i ] = 
	  MaxTurns( PositionBearoff( anBoard[ i ], 6, 15 ) );
      else
	anMaxTurns[ i ] = anCross[ i ] * 2;
      
    if ( ! anMaxTurns[ 1 ] ) anMaxTurns[ 1 ] = 1;

  }
    
    if( !fContact && anCross[ 0 ] > 4 * ( anMaxTurns[ 1 ] - 1 ) )
	/* Certain win */
	arOutput[ OUTPUT_WIN ] = 1.0f;
    
    if( ac[ 0 ] < 15 )
	/* Opponent has borne off; no gammons or backgammons possible */
	arOutput[ OUTPUT_WINGAMMON ] = arOutput[ OUTPUT_WINBACKGAMMON ] = 0.0f;
    else if( !fContact ) {
	if( anCross[ 1 ] > 8 * anGammonCross[ 0 ] )
	    /* Gammon impossible */
	    arOutput[ OUTPUT_WINGAMMON ] = 0.0f;
	else if( anGammonCross[ 0 ] > 4 * ( anMaxTurns[ 1 ] - 1 ) )
	    /* Certain gammon */
	    arOutput[ OUTPUT_WINGAMMON ] = 1.0f;
	
	if( anCross[ 1 ] > 8 * anBackgammonCross[ 0 ] )
	    /* Backgammon impossible */
	    arOutput[ OUTPUT_WINBACKGAMMON ] = 0.0f;
	else if( anBackgammonCross[ 0 ] > 4 * ( anMaxTurns[ 1 ] - 1 ) )
	    /* Certain backgammon */
	    arOutput[ OUTPUT_WINGAMMON ] =
		arOutput[ OUTPUT_WINBACKGAMMON ] = 1.0f;
    }

    if( !fContact && anCross[ 1 ] > 4 * anMaxTurns[ 0 ] )
	/* Certain loss */
	arOutput[ OUTPUT_WIN ] = 0.0f;
    
    if( ac[ 1 ] < 15 )
	/* Player has borne off; no gammon or backgammon losses possible */
	arOutput[ OUTPUT_LOSEGAMMON ] = arOutput[ OUTPUT_LOSEBACKGAMMON ] =
	    0.0f;
    else if( !fContact ) {
	if( anCross[ 0 ] > 8 * anGammonCross[ 1 ] - 4 )
	    /* Gammon loss impossible */
	    arOutput[ OUTPUT_LOSEGAMMON ] = 0.0f;
	else if( anGammonCross[ 1 ] > 4 * anMaxTurns[ 0 ] )
	    /* Certain gammon loss */
	    arOutput[ OUTPUT_LOSEGAMMON ] = 1.0f;
	
	if( anCross[ 0 ] > 8 * anBackgammonCross[ 1 ] - 4 )
	    /* Backgammon loss impossible */
	    arOutput[ OUTPUT_LOSEBACKGAMMON ] = 0.0f;
	else if( anBackgammonCross[ 1 ] > 4 * anMaxTurns[ 0 ] )
	    /* Certain backgammon loss */
	    arOutput[ OUTPUT_LOSEGAMMON ] =
		arOutput[ OUTPUT_LOSEBACKGAMMON ] = 1.0f;
    }

    /* gammons must be less than wins */    
    if( arOutput[ OUTPUT_WINGAMMON ] > arOutput[ OUTPUT_WIN ] ) {
      arOutput[ OUTPUT_WINGAMMON ] = arOutput[ OUTPUT_WIN ];
    }

    {
      float lose = 1.0 - arOutput[ OUTPUT_WIN ];
      if( arOutput[ OUTPUT_LOSEGAMMON ] > lose ) {
	arOutput[ OUTPUT_LOSEGAMMON ] = lose;
      }
    }

    /* Backgammons cannot exceed gammons */
    if( arOutput[ OUTPUT_WINBACKGAMMON ] > arOutput[ OUTPUT_WINGAMMON ] )
	arOutput[ OUTPUT_WINBACKGAMMON ] = arOutput[ OUTPUT_WINGAMMON ];
    
    if( arOutput[ OUTPUT_LOSEBACKGAMMON ] > arOutput[ OUTPUT_LOSEGAMMON ] )
	arOutput[ OUTPUT_LOSEBACKGAMMON ] = arOutput[ OUTPUT_LOSEGAMMON ];

    {
      float noise = 1/10000.0f;

      for(i = OUTPUT_WINGAMMON; i < 5; ++i) {
	if( arOutput[i] < noise ) {
	  arOutput[i] = 0.0;
	}
      }
    }
}


extern positionclass
ClassifyPosition( int anBoard[ 2 ][ 25 ], const bgvariation bgv )
{
  int nOppBack = -1, nBack = -1;

  for(nOppBack = 24; nOppBack >= 0; --nOppBack) {
    if( anBoard[0][nOppBack] ) {
      break;
    }
  }

  for(nBack = 24; nBack >= 0; --nBack) {
    if( anBoard[1][nBack] ) {
      break;
    }
  }

  if( nBack < 0 || nOppBack < 0 )
    return CLASS_OVER;

  /* special classes for hypergammon variants */

  switch ( bgv ) {
  case VARIATION_HYPERGAMMON_1:
    return CLASS_HYPERGAMMON1;
    break;

  case VARIATION_HYPERGAMMON_2:
    return CLASS_HYPERGAMMON2;
    break;

  case VARIATION_HYPERGAMMON_3:
    return CLASS_HYPERGAMMON3;
    break;

  case VARIATION_STANDARD:
  case VARIATION_NACKGAMMON:

    /* normal backgammon */

    if( nBack + nOppBack > 22 ) {

      /* contact position */

      unsigned int const N = 6;
      unsigned int i;
      unsigned int side;
    
      for(side = 0; side < 2; ++side) {
        unsigned int tot = 0;
      
        const int* board = anBoard[side];
      
        for(i = 0;  i < 25; ++i) {
          tot += board[i];
        }

        if( tot <= N ) {
          return CLASS_CRASHED;
        } else {
          if( board[0] > 1 ) {
            if( (tot - board[0]) <= N ) {
              return CLASS_CRASHED;
            } else {
              if( board[1] > 1 && (1 + tot - (board[0] + board[1])) <= N ) {
                return CLASS_CRASHED;
              }
            }
          } else {
            if( ((int)tot - (board[1] - 1)) <= (int)N ) {
              return CLASS_CRASHED;
            }
          }
        }
      }

      return CLASS_CONTACT;
    }
    else {
    
      if (  isBearoff ( pbc2, anBoard ) )
        return CLASS_BEAROFF2;

      if ( isBearoff ( pbcTS, anBoard ) )
        return CLASS_BEAROFF_TS;

      if ( isBearoff ( pbc1, anBoard ) )
        return CLASS_BEAROFF1;

      if ( isBearoff ( pbcOS, anBoard ) )
        return CLASS_BEAROFF_OS;

      return CLASS_RACE;

    }

    break;

  default:

    g_assert ( FALSE );
    break;

  }

  return 0;   /* for fussy compilers */
}

static int
EvalBearoff2( int anBoard[ 2 ][ 25 ], float arOutput[], const bgvariation bgv, NNState *nnStates )
{
  g_assert ( pbc2 );

  return BearoffEval ( pbc2, anBoard, arOutput );
}

/* An upper bound on the number of turns it can take to complete a bearoff
   from bearoff position ID i. */
static int
MaxTurns( int id )
{
  unsigned short int aus[ 32 ];
  int i;
    
  BearoffDist ( pbc1, id, NULL, NULL, NULL, aus, NULL );

  for( i = 31; i >= 0; i-- )
  {
    if( aus[i] )
      return i;
  }

  abort();
}

static int
EvalBearoffOS( int anBoard[ 2 ][ 25 ], 
               float arOutput[], const bgvariation bgv, NNState *nnStates ) {

  return BearoffEval ( pbcOS, anBoard, arOutput );

}


static int
EvalBearoffTS( int anBoard[ 2 ][ 25 ], 
               float arOutput[], const bgvariation bgv, NNState *nnStates ) {

  return BearoffEval ( pbcTS, anBoard, arOutput );

}

static int
EvalHypergammon1( int anBoard[ 2 ][ 25 ],
                  float arOutput[], const bgvariation bgv, NNState *nnStates ) {

  return BearoffEval ( apbcHyper[ 0 ], anBoard, arOutput );

}

static int
EvalHypergammon2( int anBoard[ 2 ][ 25 ],
                  float arOutput[], const bgvariation bgv, NNState *nnStates ) {

  return BearoffEval ( apbcHyper[ 1 ], anBoard, arOutput );

}

static int
EvalHypergammon3( int anBoard[ 2 ][ 25 ],
                  float arOutput[], const bgvariation bgv, NNState *nnStates ) {

  return BearoffEval ( apbcHyper[ 2 ], anBoard, arOutput );

}



extern int
EvalBearoff1Full( int anBoard[ 2 ][ 25 ], float arOutput[] ) {

  return BearoffEval ( pbc1, anBoard, arOutput );

}

extern int
EvalBearoff1( int anBoard[ 2 ][ 25 ], float arOutput[], 
              const bgvariation bgv, NNState *nnStates ) {

  return BearoffEval( pbc1, anBoard, arOutput );

}

enum {
  /* gammon possible by side on roll */
  G_POSSIBLE = 0x1,
  /* backgammon possible by side on roll */
  BG_POSSIBLE = 0x2,
  
  /* gammon possible by side not on roll */
  OG_POSSIBLE = 0x4,
  
  /* backgammon possible by side not on roll */
  OBG_POSSIBLE = 0x8
};

/* side - side that potentially can win a backgammon */
/* Return - Probablity that side will win a backgammon */

static float
raceBGprob(int anBoard[2][25], int side, const bgvariation bgv)
{
  int totMenHome = 0;
  int totPipsOp = 0;
  int i;
  int dummy[2][25];
  
  for(i = 0; i < 6; ++i) {
    totMenHome += anBoard[side][i];
  }
      
  for(i = 22; i >= 18; --i) {
    totPipsOp += anBoard[1-side][i] * (i-17);
  }

  if(! ((totMenHome + 3) / 4 - (side == 1 ? 1 : 0) <= (totPipsOp + 2) / 3) ) {
    return 0.0;
  }

  for(i = 0; i < 25; ++i) {
    dummy[side][i] = anBoard[side][i];
  }

  for(i = 0; i < 6; ++i) {
    dummy[1-side][i] = anBoard[1-side][18+i];
  }

  for(i = 6; i < 25; ++i) {
    dummy[1-side][i] = 0;
  }

  {
    const long* bgp = getRaceBGprobs(dummy[1-side]);
    if( bgp ) {
      int k = PositionBearoff(anBoard[side], 6, 15 );
      unsigned short int aProb[32];

      float p = 0.0;
      unsigned int j;

      unsigned long scale = (side == 0) ? 36 : 1;

      BearoffDist ( pbc1, k, NULL, NULL, NULL, aProb, NULL );


      for(j = 1-side; j < RBG_NPROBS; j++) {
	unsigned long sum = 0;
	scale *= 36;
	for(i = 1; i <= j + side; ++i) {
	  sum += aProb[i];
	}
	p += ((float)bgp[j])/scale * sum;
      }

      p /= 65535.0;
	
      return p;
	  
    } else {
      float p[5];
      
      if( PositionBearoff( dummy[0], 6, 15 ) > 923 ||
	  PositionBearoff( dummy[1], 6, 15 ) > 923 ) {
	EvalBearoff1(dummy, p, bgv, NULL);
      } else {
	EvalBearoff2(dummy, p, bgv, NULL);
      }

      return side == 1 ? p[0] : 1 - p[0];
    }
  }
}  

static int
EvalRace(int anBoard[ 2 ][ 25 ], float arOutput[], const bgvariation bgv, NNState *nnStates )
{
  SSE_ALIGN(float arInput[ NUM_INPUTS ]);

  CalculateRaceInputs( anBoard, arInput );

	if ( NeuralNetEvaluateFn( &nnRace, arInput, arOutput, nnStates ? nnStates + (CLASS_RACE - CLASS_RACE) : NULL) )
    return -1;
  
  /* anBoard[1] is on roll */
  {
    /* total men for side not on roll */
    int totMen0 = 0;
    
    /* total men for side on roll */
    int totMen1 = 0;

    /* a set flag for every possible outcome */
    int any = 0;
    
    int i;
    
    for(i = 23; i >= 0; --i) {
      totMen0 += anBoard[0][i];
      totMen1 += anBoard[1][i];
    }

    if( totMen1 == 15 ) {
      any |= OG_POSSIBLE;
    }
    
    if( totMen0 == 15 ) {
      any |= G_POSSIBLE;
    }

    if( any ) {
      if( any & OG_POSSIBLE ) {
	for(i = 23; i >= 18; --i) {
	  if( anBoard[1][i] > 0 ) {
	    break;
	  }
	}

	if( i >= 18 ) {
	  any |= OBG_POSSIBLE;
	}
      }

      if( any & G_POSSIBLE ) {
	for(i = 23; i >= 18; --i) {
	  if( anBoard[0][i] > 0 ) {
	    break;
	  }
	}

	if( i >= 18 ) {
	  any |= BG_POSSIBLE;
	}
      }
    }
    
    if( any & (BG_POSSIBLE | OBG_POSSIBLE) ) {
      /* side that can have the backgammon */
      
      int side = (any & BG_POSSIBLE) ? 1 : 0;

      float pr = raceBGprob(anBoard, side, bgv);

      if( pr > 0.0 ) {
	if( side == 1 ) {
	  arOutput[OUTPUT_WINBACKGAMMON] = pr;

	  if( arOutput[OUTPUT_WINGAMMON] < arOutput[OUTPUT_WINBACKGAMMON] ) {
	    arOutput[OUTPUT_WINGAMMON] = arOutput[OUTPUT_WINBACKGAMMON];
	  }
	} else {
	  arOutput[OUTPUT_LOSEBACKGAMMON] = pr;

	  if(arOutput[OUTPUT_LOSEGAMMON] < arOutput[OUTPUT_LOSEBACKGAMMON]) {
	    arOutput[OUTPUT_LOSEGAMMON] = arOutput[OUTPUT_LOSEBACKGAMMON];
	  }
	}
      } else {
	if( side == 1 ) {
	  arOutput[OUTPUT_WINBACKGAMMON] = 0.0;
	} else {
	  arOutput[OUTPUT_LOSEBACKGAMMON] = 0.0;
	}
      }
    }  
  }
  
  /* sanity check will take care of rest */

  return 0;

}


static int
EvalContact(int anBoard[ 2 ][ 25 ], float arOutput[], const bgvariation bgv, NNState *nnStates)
{
  SSE_ALIGN(float arInput[ NUM_INPUTS ]);
    
  CalculateContactInputs( anBoard, arInput );
    
  return NeuralNetEvaluateFn(&nnContact, arInput, arOutput, nnStates ? nnStates + (CLASS_CONTACT - CLASS_RACE) : NULL);
}

static int
EvalCrashed(int anBoard[ 2 ][ 25 ], float arOutput[], const bgvariation bgv, NNState *nnStates)
{
  SSE_ALIGN(float arInput[ NUM_INPUTS ]);

  CalculateCrashedInputs( anBoard, arInput );
    
  return NeuralNetEvaluateFn( &nnCrashed, arInput, arOutput, nnStates ? nnStates + (CLASS_CRASHED - CLASS_RACE) : NULL);
}

extern int
EvalOver( int anBoard[ 2 ][ 25 ], float arOutput[], const bgvariation bgv, NNState *nnStates )
{
  int i, c;
  int n = anChequers[ bgv ];

  for( i = 0; i < 25; i++ )
    if( anBoard[ 0 ][ i ] )
      break;

  if( i == 25 ) {
    /* opponent has no pieces on board; player has lost */
    arOutput[ OUTPUT_WIN ] = arOutput[ OUTPUT_WINGAMMON ] =
      arOutput[ OUTPUT_WINBACKGAMMON ] = 0.0;

    for( i = 0, c = 0; i < 25; i++ )
      c += anBoard[ 1 ][ i ];

    if( c == n ) {
      /* player still has all pieces on board; loses gammon */
      arOutput[ OUTPUT_LOSEGAMMON ] = 1.0;

      for( i = 18; i < 25; i++ )
	if( anBoard[ 1 ][ i ] ) {
	  /* player still has pieces in opponent's home board;
	     loses backgammon */
	  arOutput[ OUTPUT_LOSEBACKGAMMON ] = 1.0;

	  return 0;
	}
	    
      arOutput[ OUTPUT_LOSEBACKGAMMON ] = 0.0;

      return 0;
    }

    arOutput[ OUTPUT_LOSEGAMMON ] =
      arOutput[ OUTPUT_LOSEBACKGAMMON ] = 0.0;

    return 0;
  }
    
  for( i = 0; i < 25; i++ )
    if( anBoard[ 1 ][ i ] )
      break;

  if( i == 25 ) {
    /* player has no pieces on board; wins */
    arOutput[ OUTPUT_WIN ] = 1.0;
    arOutput[ OUTPUT_LOSEGAMMON ] =
      arOutput[ OUTPUT_LOSEBACKGAMMON ] = 0.0;

    for( i = 0, c = 0; i < 25; i++ )
      c += anBoard[ 0 ][ i ];

    if( c == n ) {
      /* opponent still has all pieces on board; win gammon */
      arOutput[ OUTPUT_WINGAMMON ] = 1.0;

      for( i = 18; i < 25; i++ )
	if( anBoard[ 0 ][ i ] ) {
	  /* opponent still has pieces in player's home board;
	     win backgammon */
	  arOutput[ OUTPUT_WINBACKGAMMON ] = 1.0;

	  return 0;
	}
	    
      arOutput[ OUTPUT_WINBACKGAMMON ] = 0.0;

      return 0;
    }

    arOutput[ OUTPUT_WINGAMMON ] =
      arOutput[ OUTPUT_WINBACKGAMMON ] = 0.0;
  }
  
  return 0;

}

static classevalfunc acef[ N_CLASSES ] = {
    EvalOver, 
    EvalHypergammon1,
    EvalHypergammon2,
    EvalHypergammon3,
    EvalBearoff2, EvalBearoffTS,
    EvalBearoff1, EvalBearoffOS, 
    EvalRace, EvalCrashed, EvalContact
};

static float Noise( const evalcontext* pec, int anBoard[ 2 ][ 25 ],
		    int iOutput ) {

    float r;
    
    if( pec->fDeterministic ) {
	char auchBoard[ 50 ], auch[ 16 ];
	int i;

	for( i = 0; i < 25; i++ ) {
	    auchBoard[ i << 1 ] = anBoard[ 0 ][ i ];
	    auchBoard[ ( i << 1 ) + 1 ] = anBoard[ 1 ][ i ];
	}

	auchBoard[ 0 ] += iOutput;
	
	md5_buffer( auchBoard, 50, auch );

	/* We can't use a Box-Muller transform here, because generating
	   a point in the unit circle requires a potentially unbounded
	   number of integers, and all we have is the board.  So we
	   just take the sum of the bytes in the hash, which (by the
	   central limit theorem) should have a normal-ish distribution. */

	r = 0.0f;
	for( i = 0; i < 16; i++ )
	    r += auch[ i ];

	r -= 2040.0f;
	r /= 295.6f;
    } else {
	/* Box-Muller transform of a point in the unit circle. */
	float x, y;
	
	do {
	    x = (float) irand( &rc ) * 2.0f / UB4MAXVAL - 1.0f;
	    y = (float) irand( &rc ) * 2.0f / UB4MAXVAL - 1.0f;
	    r = x * x + y * y;
	} while( r > 1.0f || r == 0.0f );

	r = y * sqrt( -2.0f * log( r ) / r );
    }

    r *= pec->rNoise;

    if( iOutput == OUTPUT_WINGAMMON || iOutput == OUTPUT_LOSEGAMMON )
	r *= 0.25f;
    else if( iOutput == OUTPUT_WINBACKGAMMON ||
	     iOutput == OUTPUT_LOSEBACKGAMMON )
	r *= 0.01f;

    return r;
}

static int 
EvaluatePositionCache( NNState *nnStates, int anBoard[ 2 ][ 25 ], float arOutput[],
                       const cubeinfo* pci, const evalcontext* pecx,
		       int nPlies, positionclass pc );

static int 
FindBestMovePlied( int anMove[ 8 ], int nDice0, int nDice1,
                   int anBoard[ 2 ][ 25 ], const cubeinfo* pci,
                   const evalcontext* pec, int nPlies,
                   movefilter aamf[ MAX_FILTER_PLIES ][ MAX_FILTER_PLIES ] );


static int
ScoreMoves( movelist *pml, const cubeinfo* pci, const evalcontext* pec,
	    int nPlies );

#if !defined(REDUCTION_CODE)

#define nPruneMoves 10
static const int cubefullPrune = 1;

static void
FindBestMoveInEval(NNState *nnStates, int const nDice0, int const nDice1, int anBoard[2][25],
		   const cubeinfo* const pci, const evalcontext* pec)
{
  unsigned int i;
  float rScore, rBestScore;
  movelist ml;
  GenerateMoves(&ml, anBoard, nDice0, nDice1, FALSE);
    
  if( ml.cMoves == 0 ) {
    /* no legal moves */
    return;
  }

  if( ml.cMoves == 1 ) {
    /* forced move */
    ml.iMoveBest = 0;
  } else {
    int use = ml.cMoves > nPruneMoves;
    int bmovesi[nPruneMoves];
    float arOutput[5];
    
    ((cubeinfo*)pci)->fMove = !pci->fMove;
    if( use ) {
      positionclass evalClass = 0;
      float arInput[200];
      
      for(i = 0; (int)i < ml.cMoves; i++) {
	move* const pm = &ml.amMoves[i];
	
	PositionFromKey(anBoard, pm->auch);
	SwapSides(anBoard);

	{
	  positionclass pc = ClassifyPosition(anBoard, VARIATION_STANDARD);
	  if( i == 0 ) {
	    if( pc < CLASS_RACE ) {
	      break;
	    }
	    evalClass = pc;
	  } else {
	    if( pc != evalClass ) {
	      break;
	    }
	  }

#if defined(PRUNE_CACHE)
{
	  evalcache ec;
	  unsigned long l;
	  memcpy(ec.auchKey, pm->auch, sizeof(ec.auchKey));
	  ec.nEvalContext = 0;
	  if ( ( l = CacheLookup( &cpEval, &ec, arOutput, NULL ) ) != CACHEHIT ) {
   
#endif
	    baseInputs(anBoard, arInput);
	    {
	      neuralnet* nets[] = {&nnpRace, &nnpCrashed, &nnpContact};
	      neuralnet* n = nets[pc - CLASS_RACE];
		  if (nnStates)
			  nnStates[pc - CLASS_RACE].state = (i == 0) ?  NNSTATE_INCREMENTAL : NNSTATE_DONE;
	      NeuralNetEvaluate(n, arInput, arOutput, nnStates);
	      SanityCheck(anBoard, arOutput);
	    }
#if defined(PRUNE_CACHE)
	    memcpy( ec.ar, arOutput, sizeof(float) * NUM_OUTPUTS );
	    CacheAdd(&cpEval, &ec, l);
	  }
}
#endif
	  pm->rScore = UtilityME(arOutput, pci);
	  if( i < nPruneMoves ) {
	    bmovesi[i] = i;
	    if( pm->rScore > ml.amMoves[ bmovesi[0] ].rScore ) {
	      bmovesi[i] = bmovesi[0];
	      bmovesi[0] = i;
	    }
	  } else if( pm->rScore < ml.amMoves[ bmovesi[0] ].rScore ) {
	    int m = 0, k;
	    bmovesi[0] = i;
	    for(k = 1; k < nPruneMoves; ++k) {
	      if( ml.amMoves[ bmovesi[k] ].rScore >
		  ml.amMoves[ bmovesi[m] ].rScore ) {
		m = k;
	      }
	    }
	    bmovesi[0] = bmovesi[m];
	    bmovesi[m] = i;
	  }
	}
      }

      if( i == ml.cMoves ) {
	ml.cMoves = nPruneMoves;
      } else {
	use  = 0;
      }
    }

    /* See if this is the problem */
	if (cubefullPrune)
	{
	((cubeinfo*)pci)->fMove = !pci->fMove;
	if( use ) {
	move *amMoves = (move*) g_alloca(ml.cMoves * sizeof(move));
	for(i = 0; (int)i < ml.cMoves; i++) {
	int const j = bmovesi[i];
	memcpy(&amMoves[i], &ml.amMoves[j], sizeof(amMoves[0]));
	bmovesi[i] = i;
	}
	memcpy(&ml.amMoves[0], amMoves, ml.cMoves * sizeof(amMoves[0]));
	}
	ScoreMoves(&ml, pci, pec, 0);

	/*
	((cubeinfo*)pci)->fMove = !pci->fMove;
	int c = ml.iMoveBest;
	*/
	} else {

    nnStates[0].state = nnStates[1].state = nnStates[2].state = NNSTATE_INCREMENTAL;
    rBestScore = 99999.9f;
    for(i = 0; (int)i < ml.cMoves; i++) {
      int const j = use ? bmovesi[i] : i;
      const move* const pm = &ml.amMoves[j];
	
      PositionFromKey(anBoard, pm->auch);
      SwapSides(anBoard);
      {
	evalcache ec;
	unsigned long l;
	memcpy(ec.auchKey, pm->auch, sizeof(ec.auchKey));
	ec.nEvalContext =  pci->fMove << 14;

	if ( ( l = CacheLookup( &cpEval, &ec, arOutput, NULL ) ) != CACHEHIT ) {
	  positionclass pc = ClassifyPosition(anBoard, VARIATION_STANDARD);

	  acef[pc](anBoard, arOutput, VARIATION_STANDARD, nnStates);
	  if ( pc > CLASS_PERFECT )
	    SanityCheck(anBoard, arOutput);

	  memcpy( ec.ar, arOutput, sizeof(float) * NUM_OUTPUTS );
	  CacheAdd(&cEval, &ec, l);
	}
	rScore = UtilityME(arOutput, pci);
	if( rScore < rBestScore ) {
	  rBestScore = rScore;
	  ml.iMoveBest = j;
	}
      }
    }
    nnStates[0].state = nnStates[1].state = nnStates[2].state = NNSTATE_NONE;

    ((cubeinfo*)pci)->fMove = !pci->fMove;
  }
  }
  
  PositionFromKey(anBoard, ml.amMoves[ml.iMoveBest].auch);
}
#endif

static int 
EvaluatePositionFull( NNState *nnStates, int anBoard[ 2 ][ 25 ], float arOutput[],
                      const cubeinfo* pci, const evalcontext* pec, int nPlies,
                      positionclass pc ) {
  int i, n0, n1;
#if defined( REDUCTION_CODE )
  int fUseReduction, r;
  laRollList_t *rolls = NULL;
  laRollList_t *rollList = NULL;
#endif
  float arVariationOutput[ NUM_OUTPUTS ];
  float rTemp;
  int w
#if defined( REDUCTION_CODE )
    , sumW
#endif
    ;
  
  if( pc > CLASS_PERFECT && nPlies > 0 ) {
    /* internal node; recurse */

    int anBoardNew[ 2 ][ 25 ];
    /* int anMove[ 8 ]; */
    cubeinfo ciOpp;
#if !defined(REDUCTION_CODE)
    int const  usePrune =
      pec->fUsePrune && !pec->rNoise && pci->bgv == VARIATION_STANDARD;
#endif 
      
    for( i = 0; i < NUM_OUTPUTS; i++ )
      arOutput[ i ] = 0.0;

#if defined( REDUCTION_CODE )
    /* reset reduction group */

    if ( pec->nReduced && ( nPlies == pec->nPlies ) )
      nReductionGroup = 0;

    fUseReduction = pec->nReduced && ( nPlies == 1 ) && ( pec->nPlies > 0 );

    if ( fUseReduction ) {
      nReductionGroup = (nReductionGroup + 1) % pec->nReduced;
      rollList = rollLists[ pec->nReduced ];
      rolls = &rollList[ nReductionGroup ];
    }
    else
      rolls = &allLists[ 0 ];
#endif
    
    /* loop over rolls */

    
#if defined( REDUCTION_CODE )
    sumW = 0;
    for ( r=0; r < rolls->numRolls; r++ ) {
      n0 = rolls->d1[r];
      n1 = rolls->d2[r];
      w  = rolls->wt[r];
#else
      for( n0 = 1; n0 <= 6; n0++ ) {
	for( n1 = 1; n1 <= n0; n1++ ) {
	  w = (n0 == n1) ? 1 : 2;
#endif

      for( i = 0; i < 25; i++ ) {
        anBoardNew[ 0 ][ i ] = anBoard[ 0 ][ i ];
        anBoardNew[ 1 ][ i ] = anBoard[ 1 ][ i ];
      }

      if( fAction )
        fnAction();

      if( fInterrupt ) {
        errno = EINTR;
        return -1;
      }

#if !defined(REDUCTION_CODE)
      if( usePrune ) {
	FindBestMoveInEval(nnStates, n0, n1, anBoardNew, pci, pec);
      } else {
#endif
	FindBestMovePlied( NULL, n0, n1, anBoardNew, pci, pec, 0,
			   defaultFilters );
#if !defined(REDUCTION_CODE)
      }
#endif

      SwapSides( anBoardNew );

      SetCubeInfo ( &ciOpp, pci->nCube, pci->fCubeOwner, !pci->fMove,
                    pci->nMatchTo, pci->anScore, pci->fCrawford,
                    pci->fJacoby, pci->fBeavers, pci->bgv );

      /* Evaluate at 0-ply */
      if( EvaluatePositionCache( nnStates, anBoardNew, arVariationOutput,
                                 &ciOpp, pec, nPlies - 1, 
                                 ClassifyPosition( anBoardNew, ciOpp.bgv ) ) )
        return -1;

      for( i = 0; i < NUM_OUTPUTS; i++ )
        arOutput[ i ] += w * arVariationOutput[ i ];
#if defined( REDUCTION_CODE )
      sumW += w;
#endif
    }

#if defined( REDUCTION_CODE )
    /* reset reduction group */

    if ( pec->nReduced && ( nPlies == pec->nPlies ) )
      nReductionGroup = 0;
#else
      }
#endif
      
    /* normalize */
    for ( i = 0; i < NUM_OUTPUTS; i++ )
      arOutput[ i ] /=
#if defined( REDUCTION_CODE )
	sumW
#else
	36
#endif
	;
    
    /* flop eval */
    arOutput[ OUTPUT_WIN ] = 1.0 - arOutput[ OUTPUT_WIN ];

    rTemp = arOutput[ OUTPUT_WINGAMMON ];
    arOutput[ OUTPUT_WINGAMMON ] = arOutput[ OUTPUT_LOSEGAMMON ];
    arOutput[ OUTPUT_LOSEGAMMON ] = rTemp;

    rTemp = arOutput[ OUTPUT_WINBACKGAMMON ];
    arOutput[ OUTPUT_WINBACKGAMMON ] = arOutput[ OUTPUT_LOSEBACKGAMMON ];
    arOutput[ OUTPUT_LOSEBACKGAMMON ] = rTemp;

  } 
  else {
    /* at leaf node; use static evaluation */
    
    if( acef[ pc ]( anBoard, arOutput, pci->bgv, nnStates ) )
      return -1;

    if( pec->rNoise )
	for( i = 0; i < NUM_OUTPUTS; i++ )
	    arOutput[ i ] += Noise( pec, anBoard, i );
    
    if ( pc > CLASS_PERFECT )
      /* no sanity check needed for exact evaluations */
      SanityCheck( anBoard, arOutput );
  }

  return 0;
}

static int
EvalKey ( const evalcontext *pec, const int nPlies,
          const cubeinfo *pci, int fCubefulEquity ) {

  int iKey;
#if defined( REDUCTION_CODE )
  /*
   * Bit 00-02: nReduced
   * Bit 03-04: nPlies
   * Bit 05   : fCubeful
   * Bit 06-13: rNoise
   * Bit 14-19: anScore[ 0 ]
   * Bit 20-24: anScore[ 1 ]
   * Bit 25-28: log2(nCube)
   * Bit 29-30: fCubeOwner
   * Bit 31   : fCrawford
   */

  /* Record the signature of important evaluation settings. */
  iKey = (
	   ( pec->nReduced ) | 
           ( nPlies << 3 ) |
           ( pec->fCubeful << 6 ) | 
           ( ( ( (int) ( pec->rNoise * 1000 ) ) && 0x00FF ) << 7 ) |
           ( pci->fMove << 14 ) );

  if ( nPlies || fCubefulEquity ) {

    /* 
     * match score is only interesting for cubeful evaluations or
     * for higher plies.
     *
     * Similarly for money play.
     *
     */

    /* In match play, the score and cube value and position are important. */
    if( pci->nMatchTo )
      iKey ^=
        ( ( pci->nMatchTo - pci->anScore[ pci->fMove ] ) << 15 ) ^
        ( ( pci->nMatchTo - pci->anScore[ !pci->fMove ] ) << 20 ) ^
        ( LogCube( pci->nCube ) << 25 ) ^
        ( ( pci->fCubeOwner < 0 ? 2 :
            pci->fCubeOwner == pci->fMove ) << 29 ) ^
        ( pci->fCrawford << 31 );
    else if( pec->fCubeful || fCubefulEquity )
      /* in cubeful money games the cube position and rules are important. */
      iKey ^=
        ( ( pci->fCubeOwner < 0 ? 2 :
            pci->fCubeOwner == pci->fMove ) << 29 ) ^
	( pci->fJacoby << 31 ) ^ ( pci->fBeavers << 28 );
    
    if( fCubefulEquity )
      iKey ^= 0x6a47b47e;

  }
#else
  /*
   * Bit 00-01: nPlies
   * Bit 02   : fCubeful
   * Bit 03-10: rNoise
   * Bit 11   : fMove
   * Bit 12   : fUsePrune
   * Bit 13-17: anScore[ 0 ]
   * Bit 18-22: anScore[ 1 ]
   * Bit 23-26: log2(nCube)
   * Bit 27-28: fCubeOwner
   * Bit 29   : fCrawford
   */

  iKey = (
           ( nPlies ) |
           ( pec->fCubeful << 2 ) | 
           ( ( ( (int) ( pec->rNoise * 1000 ) ) && 0x00FF ) << 3 ) |
           ( pci->fMove << 11 ) );

  if( nPlies )
	  iKey ^= (( pec->fUsePrune ) << 12 );

  
  if ( nPlies || fCubefulEquity ) {

    /* In match play, the score and cube value and position are important. */
    if( pci->nMatchTo )
      iKey ^=
        ( ( pci->nMatchTo - pci->anScore[ pci->fMove ] ) << 13 ) ^
        ( ( pci->nMatchTo - pci->anScore[ !pci->fMove ] ) << 18 ) ^
        ( LogCube( pci->nCube ) << 23 ) ^
        ( ( pci->fCubeOwner < 0 ? 2 :
            pci->fCubeOwner == pci->fMove ) << 27 ) ^
        ( pci->fCrawford << 29 );
    else if( pec->fCubeful || fCubefulEquity )
      /* in cubeful money games the cube position and rules are important. */
      iKey ^=
        ( ( pci->fCubeOwner < 0 ? 2 :
            pci->fCubeOwner == pci->fMove ) << 27 ) ^
	( pci->fJacoby << 29 ) ^ ( pci->fBeavers << 30 );
    
    if( fCubefulEquity )
      iKey ^= 0x6a47b47e;
  }
#endif
    
  return iKey;

}


static int 
EvaluatePositionCache( NNState *nnStates, int anBoard[ 2 ][ 25 ], float arOutput[],
                       const cubeinfo* pci, const evalcontext* pecx,
		       int nPlies, positionclass pc ) {
    evalcache ec;
    unsigned long l;
    /* This should be a part of the code that is called in all
       time-consuming operations at a relatively steady rate, so is a
       good choice for a callback function. */
    if( ++iTick >= 0x400 ) {
	iTick = 0;
	if( fnTick )
	    fnTick();
    }

    if( !cCache || ( pecx->rNoise != 0.0f && !pecx->fDeterministic ) )
	/* non-deterministic noisy evaluations; cannot cache */
	return EvaluatePositionFull( nnStates, anBoard, arOutput, pci, pecx, nPlies,
				     pc );
    
    PositionKey( anBoard, ec.auchKey );

    ec.nEvalContext = EvalKey ( pecx, nPlies, pci, FALSE );
    
	if ( ( l = CacheLookup( &cEval, &ec, arOutput, NULL ) ) == CACHEHIT ) {
	return 0;
    }

	if( EvaluatePositionFull( nnStates, anBoard, arOutput, pci, pecx, nPlies, pc ) )
	return -1;

    memcpy( ec.ar, arOutput, sizeof ( float ) * NUM_OUTPUTS );
    CacheAdd(&cEval, &ec, l);
    return 0;
}


extern int
PerfectCubeful ( bearoffcontext *pbc, 
                 int anBoard[ 2 ][ 25 ], float arEquity[] ) {

  unsigned short int nUs = 
    PositionBearoff ( anBoard[ 1 ], pbc->nPoints, pbc->nChequers );
  unsigned short int nThem = 
    PositionBearoff ( anBoard[ 0 ], pbc->nPoints, pbc->nChequers );
  int n = Combination ( pbc->nPoints + pbc->nChequers, pbc->nPoints );
  unsigned int iPos = nUs * n + nThem;

  return BearoffCubeful ( pbc, iPos, arEquity, NULL );

}


static int
EvaluatePerfectCubeful ( int anBoard[ 2 ][ 25 ], float arEquity[],
                         const bgvariation bgv ) {

  positionclass pc = ClassifyPosition ( anBoard, bgv );
 
  g_assert ( pc <= CLASS_PERFECT );

  switch ( pc ) {
  case CLASS_BEAROFF2:
    return PerfectCubeful( pbc2, anBoard, arEquity );
    break;
  case CLASS_BEAROFF_TS:
    return PerfectCubeful( pbcTS, anBoard, arEquity );
    break;
  default:
    g_assert ( FALSE );
    break;
  }

  return -1;

}

extern int 
EvaluatePosition( NNState *nnStates, int anBoard[ 2 ][ 25 ], float arOutput[],
		  const cubeinfo* pci, const evalcontext* pec ) {
    
  positionclass pc = ClassifyPosition( anBoard, pci->bgv );
    
  return EvaluatePositionCache( nnStates, anBoard, arOutput, pci, 
				pec ? pec : &ecBasic,
				pec ? pec->nPlies : 0, pc );
}

extern void InvertEvaluation( float ar[ NUM_OUTPUTS ] ) {		

	float r;
    
	ar[ OUTPUT_WIN ] = 1.0 - ar[ OUTPUT_WIN ];
	
	r = ar[ OUTPUT_WINGAMMON ];
	ar[ OUTPUT_WINGAMMON ] = ar[ OUTPUT_LOSEGAMMON ];
	ar[ OUTPUT_LOSEGAMMON ] = r;
	
	r = ar[ OUTPUT_WINBACKGAMMON ];
	ar[ OUTPUT_WINBACKGAMMON ] = ar[ OUTPUT_LOSEBACKGAMMON ];
	ar[ OUTPUT_LOSEBACKGAMMON ] = r;
}


extern void InvertEvaluationCf( float ar[ 4 ] ) {		

  int i;

  for ( i = 0; i < 4; i++ ) {

    ar[ i ] = -ar[ i ];

  }
  
}


extern void
InvertEvaluationR ( float ar[ NUM_ROLLOUT_OUTPUTS], const cubeinfo* pci )
{
  /* invert win, gammon etc. */

  InvertEvaluation ( ar );

  /* invert equities */

  ar [ OUTPUT_EQUITY ] = - ar[ OUTPUT_EQUITY ];

  if ( pci->nMatchTo )
    ar [ OUTPUT_CUBEFUL_EQUITY ] = 1.0 - ar[ OUTPUT_CUBEFUL_EQUITY ];
  else
    ar [ OUTPUT_CUBEFUL_EQUITY ] = - ar[ OUTPUT_CUBEFUL_EQUITY ];


}


extern int 
GameStatus( int anBoard[ 2 ][ 25 ], const bgvariation bgv ) {

  float ar[ NUM_OUTPUTS ] = { 0, 0, 0, 0, 0 };  /* NUM_OUTPUTS are 5 */
    
  if( ClassifyPosition( anBoard, bgv ) != CLASS_OVER )
    return 0;

  EvalOver( anBoard, ar, bgv, NULL );

  if( ar[ OUTPUT_WINBACKGAMMON ] || ar[ OUTPUT_LOSEBACKGAMMON ] )
    return 3;

  if( ar[ OUTPUT_WINGAMMON ] || ar[ OUTPUT_LOSEGAMMON ] )
    return 2;

  return 1;

}

extern int
TrainPosition(int anBoard[ 2 ][ 25 ], float arDesired[],
	      float rAlpha, float rAnneal,
	      const bgvariation bgv )
{
  float arInput[ NUM_INPUTS ], arOutput[ NUM_OUTPUTS ];

  int pc = ClassifyPosition( anBoard, bgv );
  
  neuralnet* nn;
  
  switch( pc ) {
  case CLASS_CONTACT:
  {
    nn = &nnContact;
    CalculateContactInputs(anBoard, arInput);
    break;
  }
  case CLASS_RACE:
  {
    nn = &nnRace;
    CalculateRaceInputs(anBoard, arInput);
    break;
  }
  case CLASS_CRASHED:
    CalculateCrashedInputs(anBoard, arInput);
    nn = &nnCrashed;
    break;
  default:
    errno = EDOM;
    return -1;
  }

  SanityCheck(anBoard, arDesired);

  NeuralNetTrain( nn, arInput, arOutput, arDesired, rAlpha /
		  pow( nn->nTrained / 1000.0 + 1.0, rAnneal ) );
    
  return 0;
}

/*
 * Utility returns the "correct" cubeless equity based on the current
 * gammon values.
 *
 * Use UtilityME to get the "true" money equity.
 */

extern float
Utility( float ar[ NUM_OUTPUTS ], const cubeinfo* pci ) {

  if ( ! pci->nMatchTo ) {

    /* equity calculation for money game */

    /* For money game the gammon price is the same for both
       players, so there is no need to use pci->fMove. */

    return 
      ar[ OUTPUT_WIN ] * 2.0 - 1.0 +
      ( ar[ OUTPUT_WINGAMMON ] - ar[ OUTPUT_LOSEGAMMON ] ) * 
      pci -> arGammonPrice[ 0 ] +
      ( ar[ OUTPUT_WINBACKGAMMON ] - ar[ OUTPUT_LOSEBACKGAMMON ] ) *
      pci -> arGammonPrice[ 1 ];

  } 
  else {

    /* equity calculation for match play */

    return
      ar [ OUTPUT_WIN ] * 2.0 - 1.0
      + ar[ OUTPUT_WINGAMMON ] *
      pci -> arGammonPrice[ pci -> fMove ] 
      - ar[ OUTPUT_LOSEGAMMON ] *
      pci -> arGammonPrice[ ! pci -> fMove ] 
      + ar[ OUTPUT_WINBACKGAMMON ] *
      pci -> arGammonPrice[ 2 + pci -> fMove ] 
      - ar[ OUTPUT_LOSEBACKGAMMON ] *
      pci -> arGammonPrice[ 2 + ! pci -> fMove ];

  }
		
}

/*
 * UtilityME is identical to Utility for match play.
 * For money play it returns the money equity instead of the 
 * correct cubeless equity.
 */

extern float
UtilityME( float ar[ NUM_OUTPUTS ], const cubeinfo* pci ) {

  if ( ! pci->nMatchTo )

    /* calculate money equity */

    return 
      ar[ OUTPUT_WIN ] * 2.0 - 1.0 +
      ( ar[ OUTPUT_WINGAMMON ] - ar[ OUTPUT_LOSEGAMMON ] ) +
      ( ar[ OUTPUT_WINBACKGAMMON ] - ar[ OUTPUT_LOSEBACKGAMMON ] );

  else 

    return Utility( ar, pci );

}


extern float 
mwc2eq ( const float rMwc, const cubeinfo *pci ) {

  /* mwc if I win/lose */

  float rMwcWin, rMwcLose;

  rMwcWin = getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo,
                    pci->fMove, pci->nCube, pci->fMove, pci->fCrawford,
                    aafMET, aafMETPostCrawford );

  rMwcLose = getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo,
                     pci->fMove, pci->nCube, ! pci->fMove, pci->fCrawford,
                     aafMET, aafMETPostCrawford );

  /* 
   * make linear inter- or extrapolation:
   * equity       mwc
   *  -1          rMwcLose
   *  +1          rMwcWin
   *
   * Interpolation formula:
   *
   *       2 * rMwc - ( rMwcWin + rMwcLose )
   * rEq = ---------------------------------
   *            rMwcWin - rMwcLose
   *
   * FIXME: numerical problems?
   * If you are trailing 30-away, 1-away the difference between
   * 29-away, 1-away and 30-away, 0-away is not very large, and it may
   * give numerical problems.
   *
   */

  return ( 2.0 * rMwc - ( rMwcWin + rMwcLose ) ) / 
    ( rMwcWin - rMwcLose );

}

extern float 
eq2mwc ( const float rEq, const cubeinfo *pci ) {

  /* mwc if I win/lose */

  float rMwcWin, rMwcLose;

  rMwcWin = getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo,
                    pci->fMove, pci->nCube, pci->fMove, pci->fCrawford,
                    aafMET, aafMETPostCrawford );

  rMwcLose = getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo,
                     pci->fMove, pci->nCube, ! pci->fMove, pci->fCrawford,
                     aafMET, aafMETPostCrawford );

  /*
   * Linear inter- or extrapolation.
   * Solve the formula in the routine above (mwc2eq):
   *
   *        rEq * ( rMwcWin - rMwcLose ) + ( rMwcWin + rMwcLose )
   * rMwc = -----------------------------------------------------
   *                                   2
   */

  return 
    0.5 * ( rEq * ( rMwcWin - rMwcLose ) + ( rMwcWin + rMwcLose ) );

}

/*
 * Convert standard error MWC to standard error equity
 *
 */

extern float 
se_mwc2eq ( const float rMwc, const cubeinfo *pci ) {

  /* mwc if I win/lose */

  float rMwcWin, rMwcLose;

  rMwcWin = getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo,
                    pci->fMove, pci->nCube, pci->fMove, pci->fCrawford,
                    aafMET, aafMETPostCrawford );

  rMwcLose = getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo,
                     pci->fMove, pci->nCube, ! pci->fMove, pci->fCrawford,
                     aafMET, aafMETPostCrawford );

  return 2.0 / ( rMwcWin - rMwcLose ) * rMwc;

}

/*
 * Convert standard error equity to standard error mwc
 *
 */

extern float 
se_eq2mwc ( const float rEq, const cubeinfo *pci ) {

  /* mwc if I win/lose */

  float rMwcWin, rMwcLose;

  rMwcWin = getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo,
                    pci->fMove, pci->nCube, pci->fMove, pci->fCrawford,
                    aafMET, aafMETPostCrawford );

  rMwcLose = getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo,
                     pci->fMove, pci->nCube, ! pci->fMove, pci->fCrawford,
                     aafMET, aafMETPostCrawford );

  /*
   * Linear inter- or extrapolation.
   * Solve the formula in the routine above (mwc2eq):
   *
   *        rEq * ( rMwcWin - rMwcLose ) + ( rMwcWin + rMwcLose )
   * rMwc = -----------------------------------------------------
   *                                   2
   */

  return 
    0.5 * rEq * ( rMwcWin - rMwcLose );

}





static int 
ApplySubMove( int anBoard[ 2 ][ 25 ], 
              const int iSrc, const int nRoll,
              const int fCheckLegal ) {

    int iDest = iSrc - nRoll;

    if( fCheckLegal && ( nRoll < 1 || nRoll > 6 ) ) {
	/* Invalid dice roll */
	errno = EINVAL;
	return -1;
    }
    
    if( iSrc < 0 || iSrc > 24 || iDest > 24 || anBoard[ 1 ][ iSrc ] < 1 ) {
	/* Invalid point number, or source point is empty */
	errno = EINVAL;
	return -1;
    }
    
    anBoard[ 1 ][ iSrc ]--;

    if( iDest < 0 )
	return 0;
    
    if( anBoard[ 0 ][ 23 - iDest ] ) {
	if( anBoard[ 0 ][ 23 - iDest ] > 1 ) {
	    /* Trying to move to a point already made by the opponent */
	    errno = EINVAL;
	    return -1;
	}
	anBoard[ 1 ][ iDest ] = 1;
	anBoard[ 0 ][ 23 - iDest ] = 0;
	anBoard[ 0 ][ 24 ]++;
    } else
	anBoard[ 1 ][ iDest ]++;

    return 0;
}

extern int 
ApplyMove( int anBoard[ 2 ][ 25 ], const int anMove[ 8 ],
           const int fCheckLegal ) {
    int i;
    
    for( i = 0; i < 8 && anMove[ i ] >= 0; i += 2 )
	if( ApplySubMove( anBoard, anMove[ i ],
			  anMove[ i ] - anMove[ i + 1 ], fCheckLegal ) )
	    return -1;
    
    return 0;
}

static void SaveMoves( movelist *pml, int cMoves, int cPip, int anMoves[],
		       int anBoard[ 2 ][ 25 ], int fPartial ) {
    int i, j;
    move *pm;
    unsigned char auch[ 10 ];

	if( fPartial ) {
	/* Save all moves, even incomplete ones */
	if( cMoves > pml->cMaxMoves )
	    pml->cMaxMoves = cMoves;
	
	if( cPip > pml->cMaxPips )
	    pml->cMaxPips = cPip;
    } else {
	/* Save only legal moves: if the current move moves plays less
	   chequers or pips than those already found, it is illegal; if
	   it plays more, the old moves are illegal. */
	if( cMoves < pml->cMaxMoves || cPip < pml->cMaxPips )
	    return;

	if( cMoves > pml->cMaxMoves || cPip > pml->cMaxPips )
	    pml->cMoves = 0;
	
	pml->cMaxMoves = cMoves;
	pml->cMaxPips = cPip;
    }
    
    pm = pml->amMoves + pml->cMoves;
    
    PositionKey( anBoard, auch );
    
    for( i = 0; i < pml->cMoves; i++ )
	{
		if( EqualKeys( auch, pml->amMoves[ i ].auch ) )
		{
			if( cMoves > pml->amMoves[ i ].cMoves ||
				cPip > pml->amMoves[ i ].cPips )
			{
				for( j = 0; j < cMoves * 2; j++ )
					pml->amMoves[ i ].anMove[ j ] = anMoves[ j ] > -1 ? anMoves[ j ] : -1;
			
				if( cMoves < 4 )
					pml->amMoves[ i ].anMove[ cMoves * 2 ] = -1;

				pml->amMoves[ i ].cMoves = cMoves;
				pml->amMoves[ i ].cPips = cPip;
			}
		    
			return;
		}
	}
    
    for( i = 0; i < cMoves * 2; i++ )
		pm->anMove[ i ] = anMoves[ i ] > -1 ? anMoves[ i ] : -1;
    
    if( cMoves < 4 )
		pm->anMove[ cMoves * 2 ] = -1;
    
    for( i = 0; i < 10; i++ )
		pm->auch[ i ] = auch[ i ];

    pm->cMoves = cMoves;
    pm->cPips = cPip;

    for ( i = 0; i < NUM_OUTPUTS; i++ )
      pm->arEvalMove[ i ] = 0.0;
    
    pml->cMoves++;

    g_assert( pml->cMoves < MAX_INCOMPLETE_MOVES );
}

static int LegalMove( int anBoard[ 2 ][ 25 ], int iSrc, int nPips ) {

    int i, nBack = 0, iDest = iSrc - nPips;
	
	if (iDest >= 0)
	{ /* Here we can do the Chris rule check */
		return ( anBoard[ 0 ][ 23 - iDest ] < 2 );
    }
    /* otherwise, attempting to bear off */

    for( i = 1; i < 25; i++ )
	if( anBoard[ 1 ][ i ] > 0 )
	    nBack = i;

    return ( nBack <= 5 && ( iSrc == nBack || iDest == -1 ) );
}

static int GenerateMovesSub( movelist *pml, int anRoll[], int nMoveDepth,
			     int iPip, int cPip, int anBoard[ 2 ][ 25 ],
			     int anMoves[], int fPartial ) {
    int i, fUsed = 0;
    int anBoardNew[ 2 ][ 25 ];

    if( nMoveDepth > 3 || !anRoll[ nMoveDepth ] )
	return TRUE;

    if( anBoard[ 1 ][ 24 ] ) { /* on bar */
	if( anBoard[ 0 ][ anRoll[ nMoveDepth ] - 1 ] >= 2 )
	    return TRUE;

	anMoves[ nMoveDepth * 2 ] = 24;
	anMoves[ nMoveDepth * 2 + 1 ] = 24 - anRoll[ nMoveDepth ];

	for( i = 0; i < 25; i++ ) {
	    anBoardNew[ 0 ][ i ] = anBoard[ 0 ][ i ];
	    anBoardNew[ 1 ][ i ] = anBoard[ 1 ][ i ];
	}
	
	ApplySubMove( anBoardNew, 24, anRoll[ nMoveDepth ], TRUE );
	
	if( GenerateMovesSub( pml, anRoll, nMoveDepth + 1, 23, cPip +
			      anRoll[ nMoveDepth ], anBoardNew, anMoves,
			      fPartial ) )
	    SaveMoves( pml, nMoveDepth + 1, cPip + anRoll[ nMoveDepth ],
		       anMoves, anBoardNew, fPartial );

	return fPartial;
    } else {
	for( i = iPip; i >= 0; i-- )
	    if( anBoard[ 1 ][ i ] && LegalMove( anBoard, i,
						anRoll[ nMoveDepth ] ) ) {
		anMoves[ nMoveDepth * 2 ] = i;
		anMoves[ nMoveDepth * 2 + 1 ] = i -
		    anRoll[ nMoveDepth ];
		
		memcpy(anBoardNew, anBoard, sizeof(anBoardNew));

		ApplySubMove( anBoardNew, i, anRoll[ nMoveDepth ], TRUE );
		
		if( GenerateMovesSub( pml, anRoll, nMoveDepth + 1,
				   anRoll[ 0 ] == anRoll[ 1 ] ? i : 23,
				   cPip + anRoll[ nMoveDepth ],
				   anBoardNew, anMoves, fPartial ) )
		    SaveMoves( pml, nMoveDepth + 1, cPip +
			       anRoll[ nMoveDepth ], anMoves, anBoardNew,
			       fPartial );
		
		fUsed = 1;
	    }
    }

    return !fUsed || fPartial;
}

static int CompareMoves( const move *pm0, const move *pm1 ) {

    return ( pm1->rScore > pm0->rScore ||
	     ( pm1->rScore == pm0->rScore && pm1->rScore2 > pm0->rScore2 ) ) ?
	1 : -1;
}

static int CompareMovesGeneral( const move *pm0, const move *pm1 ) {

  int i = cmp_evalsetup ( &pm0->esMove, &pm1->esMove );

  if ( i )
    return -i; /* sort descending */
  else
    return CompareMoves ( pm0, pm1 );

}

extern int 
ScoreMove(NNState *nnStates, move *pm, const cubeinfo *pci, const evalcontext *pec, int nPlies )
{
    int anBoardTemp[ 2 ][ 25 ];
    float arEval[ NUM_ROLLOUT_OUTPUTS ];
    cubeinfo ci;

    PositionFromKey( anBoardTemp, pm->auch );
      
    SwapSides( anBoardTemp );

    /* swap fMove in cubeinfo */
    memcpy ( &ci, pci, sizeof (ci) );
    ci.fMove = ! ci.fMove;

    if ( GeneralEvaluationEPlied (nnStates, arEval, anBoardTemp, &ci, 
                                   pec, nPlies ) )
      return -1;

    InvertEvaluationR ( arEval, &ci );

    if ( ci.nMatchTo )
      arEval[ OUTPUT_CUBEFUL_EQUITY ] =
        mwc2eq ( arEval[ OUTPUT_CUBEFUL_EQUITY ], pci );

    /* Save evaluations */  
    memcpy( pm->arEvalMove, arEval, NUM_ROLLOUT_OUTPUTS * sizeof ( float ) );
    memset( pm->arEvalStdDev, 0, NUM_ROLLOUT_OUTPUTS * sizeof ( float ) );
    
    /* Save evaluation setup */
    pm->esMove.et = EVAL_EVAL;
    pm->esMove.ec = *pec;
    pm->esMove.ec.nPlies = nPlies;
    
    /* Score for move:
       rScore is the primary score (cubeful/cubeless)
       rScore2 is the secondary score (cubeless) */
    pm->rScore =  (pec->fCubeful) ?
      arEval[ OUTPUT_CUBEFUL_EQUITY ] : arEval[ OUTPUT_EQUITY ];
    pm->rScore2 = arEval[ OUTPUT_EQUITY ];

    return 0;
}

static int
ScoreMoves( movelist *pml, const cubeinfo* pci, const evalcontext* pec,
	    int nPlies )
{
	int i;
	int r = 0;	/* return value */
	NNState *nnStates;
	nnStates = nnStatesStorage;

  pml->rBestScore = -99999.9f;

  if( nPlies == 0 ) {
    /* start incremental evaluations */
	  nnStates[0].state = nnStates[1].state = nnStates[2].state = NNSTATE_INCREMENTAL;
  }


  for( i = 0; i < pml->cMoves; i++ ) {
    if( ScoreMove(nnStates, pml->amMoves + i, pci, pec, nPlies ) < 0 ) {
      r = -1;
      break;
    }

    if( ( pml->amMoves[ i ].rScore > pml->rBestScore ) || 
	( ( pml->amMoves[ i ].rScore == pml->rBestScore ) 
	  && ( pml->amMoves[ i ].rScore2 > 
	       pml->amMoves[ pml->iMoveBest ].rScore2 ) ) ) {
      pml->iMoveBest = i;
      pml->rBestScore = pml->amMoves[ i ].rScore;
    }
  }

  if( nPlies == 0 ) {
    /* reset to none */
	
	  nnStates[0].state = nnStates[1].state = nnStates[2].state = NNSTATE_NONE;
  }
    
  return r;
}

extern int 
GenerateMoves( movelist *pml, int anBoard[ 2 ][ 25 ],
               int n0, int n1, int fPartial ) {

  int anRoll[ 4 ], anMoves[ 8 ];
  static move amMoves[ MAX_INCOMPLETE_MOVES ];

    anRoll[ 0 ] = n0;
    anRoll[ 1 ] = n1;

    anRoll[ 2 ] = anRoll[ 3 ] = ( ( n0 == n1 ) ? n0 : 0 );

    pml->cMoves = pml->cMaxMoves = pml->cMaxPips = pml->iMoveBest = 0;
    pml->amMoves = amMoves; /* use static array for top-level search, since
			       it doesn't need to be re-entrant */
    GenerateMovesSub( pml, anRoll, 0, 23, 0, anBoard, anMoves,fPartial );

    if( anRoll[ 0 ] != anRoll[ 1 ] ) {
	swap( anRoll, anRoll + 1 );

	GenerateMovesSub( pml, anRoll, 0, 23, 0, anBoard, anMoves, fPartial );
    }

	return pml->cMoves;
}

static movefilter NullFilter = {0, 0, 0.0};

static int 
FindBestMovePlied( int anMove[ 8 ], int nDice0, int nDice1,
                   int anBoard[ 2 ][ 25 ],
		   const cubeinfo* pci, const evalcontext* pec, int nPlies,
                   movefilter aamf[ MAX_FILTER_PLIES ][ MAX_FILTER_PLIES ] ) {

  evalcontext ec;
  movelist ml;
  int i;

  memcpy( &ec, pec, sizeof ( evalcontext ) );
  ec.nPlies = nPlies;

  if ( anMove )
    for ( i = 0; i < 8; ++i )
      anMove[ i ] = -1;

  if( FindnSaveBestMoves( &ml, nDice0, nDice1, anBoard, NULL, 0.0f,
                          pci, &ec, aamf ) < 0 )
    return -1;

  if( anMove ) {
    for( i = 0; i < ml.cMaxMoves * 2; i++ ) 
      anMove[ i ] = ml.amMoves[ ml.iMoveBest ].anMove[ i ];
  }
	
  if ( ml.cMoves )
    PositionFromKey( anBoard, ml.amMoves[ ml.iMoveBest ].auch );

  if ( ml.amMoves )
    free( ml.amMoves );

  return ml.cMaxMoves * 2;
}


extern 
int FindBestMove( int anMove[ 8 ], int nDice0, int nDice1,
                  int anBoard[ 2 ][ 25 ], cubeinfo *pci,
                  evalcontext *pec,
                  movefilter aamf[ MAX_FILTER_PLIES ][ MAX_FILTER_PLIES ] ) { 

  return FindBestMovePlied( anMove, nDice0, nDice1, anBoard, 
                            pci, pec ? pec :
                            &ecBasic, pec ? pec->nPlies : 0, aamf );
}

extern int 
FindnSaveBestMoves( movelist *pml,
                    int nDice0, int nDice1, int anBoard[ 2 ][ 25 ],
                    unsigned char *auchMove, const float rThr,
                    const cubeinfo* pci, const evalcontext* pec,
                    movefilter aamf[ MAX_FILTER_PLIES ][ MAX_FILTER_PLIES ] ) {

  /* Find best moves. 
     Ensure that auchMove is evaluated at the deepest ply. */

  int i, nMoves, iPly;
  move *pm;
  movefilter* mFilters;
  int nMaxPly = 0;
  int cOldMoves;
    
  /* Find all moves -- note that pml contains internal pointers to static
     data, so we can't call GenerateMoves again (or anything that calls
     it, such as ScoreMoves at more than 0 plies) until we have saved
     the moves we want to keep in amCandidates. */
  GenerateMoves( pml, anBoard, nDice0, nDice1, FALSE );

  if ( pml->cMoves == 0 ) {
      /* no legal moves */
      pml->amMoves = NULL;
      return 0;
  }
 
  /* Save moves */
  pm = (move *) malloc ( pml->cMoves * sizeof ( move ) );
  memcpy( pm, pml->amMoves, pml->cMoves * sizeof( move ) );    
  pml->amMoves = pm;
  nMoves = pml->cMoves;

  mFilters = ( pec->nPlies > 0 && pec->nPlies <= MAX_FILTER_PLIES) ?
      aamf[ pec->nPlies-1] : aamf[MAX_FILTER_PLIES-1];

  for ( iPly = 0; iPly < pec->nPlies; iPly++ ) {

      movefilter* mFilter =
	(iPly < MAX_FILTER_PLIES) ? &mFilters[iPly] : &NullFilter;
	 
      unsigned int k;

      if( mFilter->Accept < 0 ) {
	continue;
      }

      if( ScoreMoves( pml, pci, pec, iPly ) < 0 ) {
	return -1;
      }

      qsort( pml->amMoves, pml->cMoves, sizeof(move), (cfunc)CompareMoves);
      pml->iMoveBest = 0;
      
      k = pml->cMoves;
      pml->cMoves = MIN(mFilter->Accept, pml->cMoves );

      {
	unsigned int limit = MIN(k, pml->cMoves + mFilter->Extra);
      
	for( /**/ ; pml->cMoves < limit; ++pml->cMoves ) {
	  if( pml->amMoves[ pml->cMoves ].rScore <
	      pml->amMoves[0].rScore - mFilter->Threshold ) {
	    break;
	  }
	}
      }

      nMaxPly = iPly;

    if ( pml->cMoves == 1 && mFilter->Accept != 1 )
      /* if there is only one move to evaluate there is no need to continue */
      goto finished;


  }

  /* evaluate moves on top ply */

  if( ScoreMoves( pml, pci, pec, pec->nPlies ) < 0 ) {
    free( pm );
    pml->cMoves = 0;
    pml->amMoves = NULL;
    return -1;
  }

  nMaxPly = pec->nPlies;
  
  /* Resort the moves, in case the new evaluation reordered them. */
  qsort( pml->amMoves, pml->cMoves, sizeof( move ), (cfunc) CompareMoves );
  pml->iMoveBest = 0;
  
  /* set the proper size of the movelist */
  
 finished:

  cOldMoves = pml->cMoves;
  pml->cMoves = nMoves;

  /* Make sure that auchMove and top move are both  
     evaluated at the deepest ply. */
  if( auchMove ) {

    int fResort = FALSE;

    for( i = 0; i < pml->cMoves; i++ )
      if( EqualKeys( auchMove, pml->amMoves[ i ].auch ) ) {

        /* ensure top move is evaluted at deepest ply */

        if( pml->amMoves[ i ].esMove.ec.nPlies < nMaxPly ) {
          ScoreMove( NULL, pml->amMoves + i, pci, pec, nMaxPly );
          fResort = TRUE;
        }

        if ( ( fabs( pml->amMoves[ i ].rScore - 
                     pml->amMoves[ 0 ].rScore ) > rThr ) &&
             ( nMaxPly < pec->nPlies ) ) {

          /* this is en error/blunder: re-analyse at top-ply */
          
          ScoreMove( NULL, pml->amMoves, pci, pec, pec->nPlies );
          ScoreMove( NULL, pml->amMoves + i, pci, pec, pec->nPlies );
          cOldMoves = 1; /* only one move scored at deepest ply */
          fResort = TRUE;
          
        }

        /* move it up to the other moves evaluated on nMaxPly */
        
        if ( fResort && pec->nPlies ) {
          move m;
          int j;

          memcpy( &m, pml->amMoves + i, sizeof m );

          for ( j = i - 1; j >= cOldMoves; --j )
            memcpy( pml->amMoves+j+1, pml->amMoves+j, sizeof( move ) );

          memcpy( pml->amMoves + cOldMoves, &m, sizeof ( m ) );
          
            /* reorder moves evaluated on nMaxPly */
          
          qsort( pml->amMoves, cOldMoves + 1, 
                 sizeof( move ), (cfunc) CompareMoves );
          
        }
        break;
      }
  }

  return 0;

}


extern float
KleinmanCount (int nPipOnRoll, int nPipNotOnRoll)
{
  int nDiff, nSum;
  double rK;

  nDiff = nPipNotOnRoll - nPipOnRoll;
  nSum = nPipNotOnRoll + nPipOnRoll;

  rK = (double) (nDiff + 4) / (2 * sqrt( nSum - 4 ));

  return 0.5f * (1.0f + (float)erf( rK ));
}


extern int KeithCount(int anBoard[2][25], int pn[2])
{
    unsigned int anPips[2];
    int i, x;
    PipCount(anBoard, anPips);
    for (i = 0; i < 2; i++) {
	pn[i] = anPips[i];
	pn[i] += MAX(0, (anBoard[i][0] - 1) * 2);
	pn[i] += MAX(0, (anBoard[i][1] - 1));
	pn[i] += MAX(0, (anBoard[i][2] - 3));
	for (x = 3; x < 6; x++)
	    if (!anBoard[i][x])
		pn[i]++;
    }
    return 0;
}

extern int
ThorpCount( int anBoard[ 2 ][ 25 ], int *pnLeader, float *adjusted, int *pnTrailer ) {
  
  int anCovered[2], anMenLeft[2];
  int x;
  unsigned int anPips[ 2 ];

  PipCount( anBoard, anPips );

  anMenLeft[0] = 0;
  anMenLeft[1] = 0;
  for (x = 0; x < 25; x++)
    {
      anMenLeft[0] += anBoard[0][x];
      anMenLeft[1] += anBoard[1][x];
    }

  anCovered[0] = 0;
  anCovered[1] = 0;
  for (x = 0; x < 6; x++) {
    if (anBoard[0][x])
      anCovered[0]++;
    if (anBoard[1][x])
      anCovered[1]++;
  }

  *pnLeader = anPips[1];
  *pnLeader += 2*anMenLeft[1];
  *pnLeader += anBoard[1][0];
  *pnLeader -= anCovered[1];
  if (*pnLeader > 30)
      *adjusted = (float)(*pnLeader * 1.1f);
  else
      *adjusted = (float)*pnLeader;

  *pnTrailer = anPips[0];
  *pnTrailer += 2*anMenLeft[0];
  *pnTrailer += anBoard[0][0];
  *pnTrailer -= anCovered[0];
  
  return 0;

}
  
  
extern int PipCount( int anBoard[ 2 ][ 25 ], unsigned int anPips[ 2 ] ) {

    int i;
    
    anPips[ 0 ] = 0;
    anPips[ 1 ] = 0;
    
    for( i = 0; i < 25; i++ ) {
      anPips[ 0 ] += anBoard[ 0 ][ i ] * ( i + 1 );
      anPips[ 1 ] += anBoard[ 1 ][ i ] * ( i + 1 );
    }
    
    return 0;
}

static int DumpOver( int anBoard[ 2 ][ 25 ], char *pchOutput, 
                      const bgvariation bgv ) {

    float ar[ NUM_OUTPUTS ] = { 0, 0, 0, 0, 0}; /* NUM_OUTPUTS is 5 */
    
    if ( EvalOver( anBoard, ar, bgv, NULL ) )
      return -1;

    if( ar[ OUTPUT_WIN ] > 0.0 )
	strcpy( pchOutput, _("Win ") );
    else
	strcpy( pchOutput, _("Loss ") );

    if( ar[ OUTPUT_WINBACKGAMMON ] > 0.0 ||
	ar[ OUTPUT_LOSEBACKGAMMON ] > 0.0 )
	strcat( pchOutput, _("(backgammon)\n") );
    else if( ar[ OUTPUT_WINGAMMON ] > 0.0 ||
	ar[ OUTPUT_LOSEGAMMON ] > 0.0 )
	strcat( pchOutput, _("(gammon)\n") );
    else
	strcat( pchOutput, _("(single)\n") );

    return 0;

}


static int 
DumpBearoff1( int anBoard[ 2 ][ 25 ], char *szOutput,
              const bgvariation bgv ) {

  g_assert ( pbc1 );
  return BearoffDump ( pbc1, anBoard, szOutput );

}

static int 
DumpBearoff2( int anBoard[ 2 ][ 25 ], char *szOutput,
              const bgvariation bgv ) {

  g_assert( pbc2 );

  if ( BearoffDump ( pbc2, anBoard, szOutput ) )
    return -1;

  if ( pbc1 )
    if ( BearoffDump ( pbc1, anBoard, szOutput ) )
      return -1;

  return 0;

}


static int 
DumpBearoffOS ( int anBoard[ 2 ][ 25 ], 
                char *szOutput, const bgvariation bgv ) {

  g_assert ( pbcOS );
  return BearoffDump ( pbcOS, anBoard, szOutput );

}


static int 
DumpBearoffTS ( int anBoard[ 2 ][ 25 ], 
                char *szOutput, const bgvariation bgv ) {

  g_assert ( pbcTS );
  return BearoffDump ( pbcTS, anBoard, szOutput );

}


static int DumpRace( int anBoard[ 2 ][ 25 ], char *szOutput,
                      const bgvariation bgv ) {

  /* no-op -- nothing much we can say, really (pip count?) */
  return 0;

}

static void
DumpAnyContact(int anBoard[ 2 ][ 25 ], char* szOutput,
	       const bgvariation bgv, int isCrashed )
{
#if 0
  float arInput[ NUM_INPUTS ], arOutput[ NUM_OUTPUTS ],
    arDerivative[ NUM_INPUTS * NUM_OUTPUTS ],
    ardEdI[ NUM_INPUTS ], *p;
  int i, j;

  if( isCrashed ) {
    CalculateCrashedInputs( anBoard, arInput );
  } else {
    CalculateContactInputs( anBoard, arInput );
  }
    
  NeuralNetDifferentiate( &nnContact, arInput, arOutput, arDerivative );

  for( i = 0; i < NUM_INPUTS; i++ ) {
    for( j = 0, p = arDerivative + i; j < NUM_OUTPUTS; p += NUM_INPUTS )
	    arOutput[ j++ ] = *p;

    ardEdI[ i ] = Utility( arOutput, &ciCubeless ) + 1.0f; 
    /* FIXME this is a bit grotty -- need to
       eliminate the constant 1 added by Utility */
  }

  {
    float* player = arInput + (25 * MINPPERPOINT + MORE_INPUTS);
    float* dPlayer = ardEdI + (25 * MINPPERPOINT + MORE_INPUTS);
    
  sprintf( szOutput,
           "Input          \tValue             \t dE/dI\n"
           "OFF1           \t%5.3f             \t%6.3f\n"
           "OFF2           \t%5.3f             \t%6.3f\n"
           "OFF3           \t%5.3f             \t%6.3f\n"
           "BREAK_CONTACT  \t%5.3f             \t%6.3f\n"
           "BACK_CHEQUER   \t%5.3f             \t%6.3f\n"
           "BACK_ANCHOR    \t%5.3f             \t%6.3f\n"
           "FORWARD_ANCHOR \t%5.3f             \t%6.3f\n"
           "PIPLOSS        \t%5.3f (%5.3f avg)\t%6.3f\n"
           "P1             \t%5.3f (%5.3f/36) \t%6.3f\n"
           "P2             \t%5.3f (%5.3f/36) \t%6.3f\n"
           "BACKESCAPES    \t%5.3f (%5.3f/36) \t%6.3f\n"
           "ACONTAIN       \t%5.3f (%5.3f/36) \t%6.3f\n"
           "CONTAIN        \t%5.3f (%5.3f/36) \t%6.3f\n"
           "MOBILITY       \t%5.3f             \t%6.3f\n"
           "MOMENT2        \t%5.3f             \t%6.3f\n"
           "ENTER          \t%5.3f (%5.3f/12) \t%6.3f\n"
	   "ENTER2         \t%5.3f             \t%6.3f\n"
	   "TIMING         \t%5.3f             \t%6.3f\n"
	   "BACKBONE       \t%5.3f             \t%6.3f\n"
	   "BACKGAME       \t%5.3f             \t%6.3f\n"
	   "BACKGAME1      \t%5.3f             \t%6.3f\n"
	   "FREEPIP        \t%5.3f             \t%6.3f\n",
           player[ I_OFF1 ], dPlayer[ I_OFF1 ],
           player[ I_OFF2 ], dPlayer[ I_OFF2 ],
           player[ I_OFF3 ], dPlayer[ I_OFF3 ],
           player[ I_BREAK_CONTACT ], dPlayer[ I_BREAK_CONTACT ],
           player[ I_BACK_CHEQUER ], dPlayer[ I_BACK_CHEQUER ],
           player[ I_BACK_ANCHOR ], dPlayer[ I_BACK_ANCHOR ],
           player[ I_FORWARD_ANCHOR ], dPlayer[ I_FORWARD_ANCHOR ],
           player[ I_PIPLOSS ], 
           player[ I_P1 ] ? player[ I_PIPLOSS ] / player[ I_P1 ] * 12.0 : 0.0,
	   dPlayer[ I_PIPLOSS ],
           player[ I_P1 ], player[ I_P1 ] * 36.0, dPlayer[ I_P1 ],
           player[ I_P2 ], player[ I_P2 ] * 36.0, dPlayer[ I_P2 ],
           player[ I_BACKESCAPES ], player[I_BACKESCAPES] * 36.0, dPlayer[ I_BACKESCAPES ],
           player[ I_ACONTAIN ], player[ I_ACONTAIN ] * 36.0, dPlayer[ I_ACONTAIN ],
           player[ I_CONTAIN ], player[ I_CONTAIN ] * 36.0, dPlayer[ I_CONTAIN ],
           player[ I_MOBILITY ], dPlayer[ I_MOBILITY ],
           player[ I_MOMENT2 ], dPlayer[ I_MOMENT2 ],
           player[ I_ENTER ], player[ I_ENTER ] * 12.0, dPlayer[ I_ENTER ],
	   player[ I_ENTER2 ], dPlayer[ I_ENTER2 ],
	   player[ I_TIMING ], dPlayer[ I_TIMING ],
	   player[ I_BACKBONE ], dPlayer[ I_BACKBONE ],
	   player[ I_BACKG ], dPlayer[ I_BACKG ],
	   player[ I_BACKG1 ], dPlayer[ I_BACKG1 ],
	   player[ I_FREEPIP ], dPlayer[ I_FREEPIP ] );
  }
#endif
}

static int
DumpContact( int anBoard[ 2 ][ 25 ], char* szOutput, const bgvariation bgv )
{
  DumpAnyContact(anBoard, szOutput, bgv, 0);
  return 0;
}

static int
DumpCrashed( int anBoard[ 2 ][ 25 ], char* szOutput, const bgvariation bgv )
{
  DumpAnyContact(anBoard, szOutput, bgv, 1);
  return 0;
}

static int
DumpHypergammon1 ( int anBoard[ 2 ][ 25 ], char *szOutput,
                   const bgvariation bgv ) {

  g_assert ( apbcHyper[ 0 ] );
  return BearoffDump ( apbcHyper[ 0 ], anBoard, szOutput );

}

static int
DumpHypergammon2 ( int anBoard[ 2 ][ 25 ], char *szOutput,
                   const bgvariation bgv ) {

  g_assert ( apbcHyper[ 1 ] );
  return BearoffDump ( apbcHyper[ 1 ], anBoard, szOutput );

}

static int
DumpHypergammon3 ( int anBoard[ 2 ][ 25 ], char *szOutput,
                   const bgvariation bgv ) {

  g_assert ( apbcHyper[ 2 ] );
  return BearoffDump ( apbcHyper[ 2 ], anBoard, szOutput );

}

static classdumpfunc acdf[ N_CLASSES ] = {
  DumpOver, 
  DumpHypergammon1, DumpHypergammon2, DumpHypergammon3,
  DumpBearoff2, DumpBearoffTS,
  DumpBearoff1, DumpBearoffOS,
  DumpRace, DumpCrashed, DumpContact
};

extern int
DumpPosition( int anBoard[ 2 ][ 25 ], char* szOutput,
	      const evalcontext* pec, cubeinfo* pci, int fOutputMWC,
	      int fOutputWinPC, int fOutputInvert, 
              const char *szMatchID ) {

  float aarOutput[ 2 ][ NUM_ROLLOUT_OUTPUTS ], arDouble[ 4 ];
  positionclass pc = ClassifyPosition( anBoard, pci->bgv );
  int i, nPlies;
  int j;
  cubedecision cd;
  evalcontext ec;
  static char *aszEvaluator[] = {
    N_("OVER"),
    N_("HYPERGAMMON-1"),
    N_("HYPERGAMMON-2"),
    N_("HYPERGAMMON-3"),
    N_("BEAROFF2"),
    N_("BEAROFF-TS"),
    N_("BEAROFF1"),
    N_("BEAROFF-OS"),
    N_("RACE"),
    N_("CRASHED"),
    N_("CONTACT")
  };

  strcpy( szOutput, "" );

  strcat( szOutput, _("Position ID:\t") );
  strcat( szOutput, PositionID( anBoard ) );
  strcat( szOutput, "\n" );
  if ( szMatchID ) {
    strcat( szOutput, _("Match ID:\t") );
    strcat( szOutput, szMatchID );
    strcat( szOutput, "\n" );
  }
  strcat( szOutput, "\n" );
    
  strcat( szOutput, _("Evaluator: \t") );
  strcat( szOutput, gettext( aszEvaluator[ pc ] ) );
  strcat( szOutput, "\n\n" );
  acdf[ pc ]( anBoard, strchr( szOutput, 0 ), pci->bgv );
  szOutput = strchr( szOutput, 0 );    

  sprintf( strchr( szOutput, 0 ),
           "\n"
           "        %-7s %-7s %-7s %-7s %-7s %-9s %-9s\n",
           _("Win"), _("W(g)"), _("W(bg)"), _("L(g)"), _("L(bg)"),
           ( ! pci->nMatchTo || ( pci->nMatchTo && ! fOutputMWC ) ) ? 
           _("Equity") : _("MWC"), _("Cubeful") );
           
  nPlies = pec->nPlies > 9 ? 9 : pec->nPlies;

  memcpy ( &ec, pec, sizeof ( evalcontext ) );

  for( i = 0; i <= nPlies; i++ ) {
    szOutput = strchr( szOutput, 0 );
	

    ec.nPlies = i;

    if ( GeneralCubeDecisionE ( aarOutput, anBoard, pci, &ec, 0 ) < 0 )
      return -1;

    if( !i )
	    strcpy( szOutput, _("static") );
    else
	    sprintf( szOutput, _("%2d ply"), i );

    szOutput = strchr( szOutput, 0 );

    if( fOutputInvert ) {
      InvertEvaluationR( aarOutput[ 0 ], pci );
      InvertEvaluationR( aarOutput[ 1 ], pci );
      pci->fMove = !pci->fMove;
    }

    /* Calculate cube decision */

    cd = FindCubeDecision(arDouble,  aarOutput, pci);
    
    /* Print %'s and equities */

    strcat( szOutput, ": " );

    for ( j = 0; j < 5; ++j ) {
      sprintf( strchr( szOutput, 0 ), "%-7s ",
               OutputPercent( aarOutput[ 0 ][ j ] ) );
    }

    if ( pci->nMatchTo )
      sprintf( strchr( szOutput, 0 ), "%-9s ",
               OutputEquity( Utility( aarOutput[ 0 ], pci ), pci, TRUE ) );
    else
      sprintf( strchr( szOutput, 0 ), "%-9s ",
               OutputMoneyEquity( aarOutput[ 0 ], TRUE ) );

    sprintf( strchr( szOutput, 0 ), "%-9s ",
             OutputMWC( aarOutput[ 0 ][ 6 ], pci, TRUE ) );
    
    strcat( szOutput, "\n" );

    if( fOutputInvert ) {
      pci->fMove = !pci->fMove;
    }
  }

  /* if cube is available, output cube action */
  if ( GetDPEq ( NULL, NULL, pci ) ) {

    evalsetup es;

    es.et = EVAL_EVAL;
    es.ec = *pec;

    strcat( szOutput, "\n\n" );
    strcat( szOutput,
	    OutputCubeAnalysis(  aarOutput, NULL, &es, pci ) );

  }

  return 0;
}


static void StatusHypergammon1( char *sz ) {

  BearoffStatus ( apbcHyper[ 0 ], sz );

}

static void StatusHypergammon2( char *sz ) {

  BearoffStatus ( apbcHyper[ 1 ], sz );

}

static void StatusHypergammon3( char *sz ) {

  BearoffStatus ( apbcHyper[ 2 ], sz );

}


static void StatusBearoff2( char *sz ) {

  BearoffStatus ( pbc2, sz );
  
}

static void StatusBearoff1( char *sz ) {

  BearoffStatus ( pbc1, sz );

}

static void StatusNeuralNet( neuralnet *pnn, char *szTitle, char *sz ) {

  sprintf( sz, _(" * %s neural network evaluator:\n"
                 "   - version %s, %d inputs, %d hidden units"),
           szTitle, WEIGHTS_VERSION, pnn->cInput, pnn->cHidden );
  sz = strchr( sz, 0 );
  
  if( pnn->nTrained > 1 )
      sprintf( sz, _("trained on %d positions"), pnn->nTrained );

  strcat( sz, ".\n\n" );

}

static void StatusRace( char *sz ) {

    StatusNeuralNet( &nnRace, _("Race"), sz );
}

static void StatusCrashed( char *sz ) {

    StatusNeuralNet( &nnContact, _("Crashed"), sz );
}

static void StatusContact( char *sz ) {

    StatusNeuralNet( &nnContact, _("Contact"), sz );
}

static void StatusOS ( char *sz ) {
  BearoffStatus ( pbcOS, sz );
}

static void StatusTS ( char *sz ) {
  BearoffStatus ( pbcTS, sz );
}

static classstatusfunc acsf[ N_CLASSES ] = {
  NULL, 
  StatusHypergammon1, StatusHypergammon2, StatusHypergammon3,
  StatusBearoff2, StatusTS,
  StatusBearoff1, StatusOS, 
  StatusRace, StatusCrashed, StatusContact
};

extern void EvalStatus( char *szOutput ) {

    int i;

    *szOutput = 0;
    
    for( i = N_CLASSES - 1; i >= 0; i-- )
	if( acsf[ i ] )
	    acsf[ i ]( strchr( szOutput, 0 ) );
}


extern char 
*GetCubeRecommendation ( const cubedecision cd ) {

  switch ( cd ) {

  case DOUBLE_TAKE:
    return _("Double, take");
  case DOUBLE_PASS:
    return _("Double, pass");
  case NODOUBLE_TAKE:
    return _("No double, take");
  case TOOGOOD_TAKE:
    return _("Too good to double, take");
  case TOOGOOD_PASS:
    return _("Too good to double, pass");
  case DOUBLE_BEAVER:
    return _("Double, beaver");
  case NODOUBLE_BEAVER:
    return _("No double, beaver");
  case REDOUBLE_TAKE:
    return _("Redouble, take");
  case REDOUBLE_PASS:
    return _("Redouble, pass");
  case NO_REDOUBLE_TAKE:
    return _("No redouble, take");
  case TOOGOODRE_TAKE:
    return _("Too good to redouble, take");
  case TOOGOODRE_PASS:
    return _("Too good to redouble, pass");
  case NO_REDOUBLE_BEAVER:
    return _("No redouble, beaver");
  case NODOUBLE_DEADCUBE:
    return _("Never double, take (dead cube)");
  case NO_REDOUBLE_DEADCUBE:
    return _("Never redouble, take (dead cube)");
  case OPTIONAL_DOUBLE_BEAVER:
    return _("Optional double, beaver");
  case OPTIONAL_DOUBLE_TAKE:
    return _("Optional double, take");
  case OPTIONAL_REDOUBLE_TAKE:
    return _("Optional redouble, take");
  case OPTIONAL_DOUBLE_PASS:
    return _("Optional double, pass");
  case OPTIONAL_REDOUBLE_PASS:
    return _("Optional redouble, pass");
  default:
    return _("I have no idea!");
  }

}

extern void
EvalCacheFlush(void)
{
  CacheFlush( & cEval );
}

extern int EvalCacheResize( unsigned int cNew ) {

    cCache = cNew;
    
    return CacheResize( &cEval, cNew );
}

extern int EvalCacheStats( unsigned int *pcUsed, unsigned int *pcSize, unsigned int *pcLookup,
			   unsigned int *pcHit ) {
    if( pcSize )
	*pcSize = cCache;
	    
    CacheStats( &cEval, pcLookup, pcHit, pcUsed );
    return 0;
}

extern int FindPubevalMove( int nDice0, int nDice1, int anBoard[ 2 ][ 25 ],
			    int anMove[ 8 ], const bgvariation bgv ) {

  movelist ml;
  int i, j, anBoardTemp[ 2 ][ 25 ], anPubeval[ 28 ], fRace;

  for( i = 0; i < 8; i++ )
      anMove[ i ] = -1;
  
  fRace = ClassifyPosition( anBoard, bgv ) <= CLASS_RACE;
    
  GenerateMoves( &ml, anBoard, nDice0, nDice1, FALSE );

  if( !ml.cMoves )
    /* no legal moves */
    return 0;
  else if( ml.cMoves == 1 )
    /* forced move */
    ml.iMoveBest = 0;
  else {
    /* choice of moves */
    ml.rBestScore = -99999.9f;

    for( i = 0; i < ml.cMoves; i++ ) {
	    PositionFromKey( anBoardTemp, ml.amMoves[ i ].auch );

	    for( j = 0; j < 24; j++ )
        if( anBoardTemp[ 1 ][ j ] )
          anPubeval[ j + 1 ] = anBoardTemp[ 1 ][ j ];
        else
          anPubeval[ j + 1 ] = -anBoardTemp[ 0 ][ 23 - j ];

	    anPubeval[ 0 ] = -anBoardTemp[ 0 ][ 24 ];
	    anPubeval[ 25 ] = anBoardTemp[ 1 ][ 24 ];

	    for( anPubeval[ 26 ] = 15, j = 0; j < 24; j++ )
        anPubeval[ 26 ] -= anBoardTemp[ 1 ][ j ];

	    for( anPubeval[ 27 ] = -15, j = 0; j < 24; j++ )
        anPubeval[ 27 ] += anBoardTemp[ 0 ][ j ];

	    if( ( ml.amMoves[ i ].rScore = pubeval( fRace, anPubeval ) ) >
          ml.rBestScore ) {
        ml.iMoveBest = i;
        ml.rBestScore = ml.amMoves[ i ].rScore;
	    }
    }
  }

  if( anMove )
      for( i = 0; i < ml.cMaxMoves * 2; i++ )
	  anMove[ i ] = ml.amMoves[ ml.iMoveBest ].anMove[ i ];
  
  return 0;
}

extern int 
SetCubeInfoMoney( cubeinfo *pci, const int nCube, const int fCubeOwner,
                  const int fMove, const int fJacoby, const int fBeavers,
                  const bgvariation bgv ) {

    if( nCube < 1 || fCubeOwner < -1 || fCubeOwner > 1 || fMove < 0 ||
	fMove > 1 ) /* FIXME also illegal if nCube is not a power of 2 */
    {
	memset(pci, 0, sizeof(cubeinfo));
	return -1;
    }

    pci->nCube = nCube;
    pci->fCubeOwner = fCubeOwner;
    pci->fMove = fMove;
    pci->fJacoby = fJacoby;
    pci->fBeavers = fBeavers;
    pci->nMatchTo = pci->anScore[ 0 ] = pci->anScore[ 1 ] = pci->fCrawford = 0;
    pci->bgv = bgv;
    
    pci->arGammonPrice[ 0 ] = pci->arGammonPrice[ 1 ] =
	pci->arGammonPrice[ 2 ] = pci->arGammonPrice[ 3 ] =
	    ( fJacoby && fCubeOwner == -1 ) ? 0.0 : 1.0;

    return 0;
}

extern int 
SetCubeInfoMatch( cubeinfo *pci, const int nCube, const int fCubeOwner,
                  const int fMove, const int nMatchTo, const int anScore[ 2 ],
                  const int fCrawford, const bgvariation bgv ) {
    
    if( nCube < 1 || fCubeOwner < -1 || fCubeOwner > 1 || fMove < 0 ||
	fMove > 1 || nMatchTo < 1 || anScore[ 0 ] >= nMatchTo ||
	anScore[ 1 ] >= nMatchTo ) /* FIXME also illegal if nCube is not a power of 2 */
    {
	memset(pci, 0, sizeof(cubeinfo));
	return -1;
    }
    
    pci->nCube = nCube;
    pci->fCubeOwner = fCubeOwner;
    pci->fMove = fMove;
    pci->fJacoby = pci->fBeavers = FALSE;
    pci->nMatchTo = nMatchTo;
    pci->anScore[ 0 ] = anScore[ 0 ];
    pci->anScore[ 1 ] = anScore[ 1 ];
    pci->fCrawford = fCrawford;
    pci->bgv = bgv;
    
    /*
     * FIXME: calculate gammon price when initializing program
     * instead of recalculating it again and again, or cache it.
     */
              
    {

      int nAway0 = pci->nMatchTo - pci->anScore[ 0 ] - 1;
      int nAway1 = pci->nMatchTo - pci->anScore[ 1 ] - 1;

      if ( ( ! nAway0 || ! nAway1 ) && ! fCrawford ) {
        if ( ! nAway0 )
          memcpy ( pci->arGammonPrice, 
                   aaaafGammonPricesPostCrawford[ LogCube ( pci->nCube ) ]
                   [ nAway1 ][ 0 ], 4 * sizeof ( float ) );
        else
          memcpy ( pci->arGammonPrice, 
                   aaaafGammonPricesPostCrawford[ LogCube ( pci->nCube ) ]
                   [ nAway0 ][ 1 ], 4 * sizeof ( float ) );
      }
      else
        memcpy ( pci->arGammonPrice, 
                 aaaafGammonPrices[ LogCube ( pci->nCube ) ]
                 [ nAway0 ][ nAway1 ], 4 * sizeof ( float ) );

    }
            
    return 0;
}

extern int 
SetCubeInfo ( cubeinfo *pci, const int nCube, const int fCubeOwner, 
              const int fMove, const int nMatchTo, const int anScore[ 2 ], 
              const int fCrawford, const int fJacoby, const int fBeavers, 
              const bgvariation bgv ) {

    return nMatchTo ? SetCubeInfoMatch( pci, nCube, fCubeOwner, fMove,
					nMatchTo, anScore, fCrawford, bgv ) :
	SetCubeInfoMoney( pci, nCube, fCubeOwner, fMove, 
                          fJacoby, fBeavers, bgv );
}


static int
isOptional ( const float r1, const float r2 ) {

  const float epsilon = 1.0e-5f;

  return ( fabs ( r1 - r2 ) <= epsilon );

}

static int
winGammon ( const float arOutput[ NUM_ROLLOUT_OUTPUTS ] ) {

  return ( arOutput[ OUTPUT_WINGAMMON ] > 0.0f );

}
 
extern cubedecision
FindBestCubeDecision ( float arDouble[], 
                       float aarOutput[ 2 ][ NUM_ROLLOUT_OUTPUTS ],
                       const cubeinfo *pci ) {

/*
 * FindBestCubeDecision:
 *
 *    Calculate optimal cube decision and equity/mwc for this.
 *
 * Input:
 *    arDouble    - array with equities or mwc's:
 *                      arDouble[ 1 ]: no double,
 *                      arDouble[ 2 ]: double take
 *                      arDouble[ 3 ]: double pass
 *    pci         - pointer to cube info
 *
 * Output:
 *    arDouble    - array with equities or mwc's
 *                      arDouble[ 0 ]: equity for optimal cube decision
 *
 * Returns:
 *    cube decision 
 *
 */

  int f;

  /* Check if cube is avaiable */

  if ( ! GetDPEq ( NULL, NULL, pci ) ) {

    arDouble[ OUTPUT_OPTIMAL ] = arDouble[ OUTPUT_NODOUBLE ];

    /* for match play distinguish between dead cube and not available cube */

    if ( pci->nMatchTo && 
         ( pci->fCubeOwner < 0 || pci->fCubeOwner == pci->fMove ) )
      return ( pci->fCubeOwner == -1 ) ? 
        NODOUBLE_DEADCUBE : NO_REDOUBLE_DEADCUBE;
    else
      return NOT_AVAILABLE;

  }


  /* Cube is available: find optimal cube action */

  if ( ( arDouble[ OUTPUT_TAKE ] >= arDouble[ OUTPUT_NODOUBLE ] ) &&
       ( arDouble[ OUTPUT_DROP ] >= arDouble[ OUTPUT_NODOUBLE ] ) ) {

    /* DT >= ND and DP >= ND */

    /* we have a double */

    if ( arDouble[ OUTPUT_DROP ] > arDouble[ OUTPUT_TAKE ] ) {

      /* 6. DP > DT >= ND: Double, take */

      f = isOptional ( arDouble[ OUTPUT_TAKE ], arDouble[ OUTPUT_NODOUBLE ] );

      arDouble[ OUTPUT_OPTIMAL ] = arDouble[ OUTPUT_TAKE ];

      if ( ! pci->nMatchTo &&
           arDouble[ OUTPUT_TAKE ] >= -2.0 &&
           arDouble[ OUTPUT_TAKE ] <= 0.0 
           && pci->fBeavers )
        /* beaver (jacoby paradox) */
        return f ? OPTIONAL_DOUBLE_BEAVER : DOUBLE_BEAVER;
      else {
        /* ...take */
        if ( f ) 
          return ( pci->fCubeOwner == -1 ) ? 
            OPTIONAL_DOUBLE_TAKE : OPTIONAL_REDOUBLE_TAKE;
        else
          return ( pci->fCubeOwner == -1 ) ? DOUBLE_TAKE : REDOUBLE_TAKE;
      }
      
    }
    else {

      /* 4. DT >= DP >= ND: Double, pass */

      /* 
       * the double is optional iff:
       * (1) equity(no double) = equity(drop)
       * (2) the player can win gammon
       * (3a) it's match play
       * or if it's money play
       * (3b) it's not a centered cube
       * or
       * (3c) the Jacoby rule is not in effect
       */

      arDouble[ OUTPUT_OPTIMAL ] = arDouble[ OUTPUT_DROP ];

      if ( isOptional ( arDouble[ OUTPUT_NODOUBLE ], 
                        arDouble[ OUTPUT_DROP ] ) &&
           ( winGammon ( aarOutput[ 0 ] ) && 
             ( pci->nMatchTo || pci->fCubeOwner != -1 || ! pci->fJacoby ) ) ) 
        return ( pci->fCubeOwner == -1 ) ? 
          OPTIONAL_DOUBLE_PASS : OPTIONAL_REDOUBLE_PASS;
      else
        return ( pci->fCubeOwner == -1 ) ? DOUBLE_PASS : REDOUBLE_PASS;
      
    }
  }
  else {
    
    /* no double */

    /* ND > DT or ND > DP */

    arDouble [ OUTPUT_OPTIMAL ] = arDouble[ OUTPUT_NODOUBLE ];

    if ( arDouble [ OUTPUT_NODOUBLE ] > arDouble [ OUTPUT_TAKE ] ) {

      /* ND > DT */

      if ( arDouble [ OUTPUT_TAKE ] > arDouble [ OUTPUT_DROP ] ) {

        /* 1. ND > DT > DP: Too good, pass */

        /* sanety check: don't play on gammon if none is possible... */

        if ( winGammon ( aarOutput[ 0 ] ) )
          return ( pci->fCubeOwner == -1 ) ? TOOGOOD_PASS : TOOGOODRE_PASS;
        else
          return ( pci->fCubeOwner == -1 ) ? DOUBLE_PASS : REDOUBLE_PASS;

      }
      else if ( arDouble[ OUTPUT_NODOUBLE ] > arDouble[ OUTPUT_DROP ] ) {

        /* 2. ND > DP > DT: Too good, take */

        if ( winGammon ( aarOutput[ 0 ] ) )
          return ( pci->fCubeOwner == -1 ) ? TOOGOOD_TAKE : TOOGOODRE_TAKE;
        else
          return ( pci->fCubeOwner == -1 ) ? NODOUBLE_TAKE : NO_REDOUBLE_TAKE;

      }
      else {

        /* 5. DP > ND > DT: No double, {take, beaver} */
      
        if ( arDouble[ OUTPUT_TAKE ] >= -2.0 &&
             arDouble[ OUTPUT_TAKE ] <= 0.0 && ! pci->nMatchTo 
             && pci->fBeavers )
          return ( pci->fCubeOwner == -1 ) ?
            NODOUBLE_BEAVER : NO_REDOUBLE_BEAVER; 
        else
          return ( pci->fCubeOwner == -1 ) ?
            NODOUBLE_TAKE : NO_REDOUBLE_TAKE; 

      }

    } 
    else {

      /* 3. DT >= ND > DP: Too good, pass */

      if ( winGammon ( aarOutput[ 0 ] ) )
        return ( pci->fCubeOwner == -1 ) ? TOOGOOD_PASS : TOOGOODRE_PASS;
      else
        return ( pci->fCubeOwner == -1 ) ? DOUBLE_PASS : REDOUBLE_PASS;

    }

  }
}


extern cubedecision
FindCubeDecision ( float arDouble[],
                   float aarOutput[][ NUM_ROLLOUT_OUTPUTS ],
                   const cubeinfo* pci )
{
  GetDPEq ( NULL, &arDouble[ OUTPUT_DROP ], pci );
  arDouble[ OUTPUT_NODOUBLE ] = aarOutput[ 0 ][ OUTPUT_CUBEFUL_EQUITY ];
  arDouble[ OUTPUT_TAKE ] = aarOutput[ 1 ][ OUTPUT_CUBEFUL_EQUITY ];

  if ( pci->nMatchTo ) {
    /* convert to normalized money equity */

    int i;

    for ( i = 1; i < 4; i++ )
      arDouble[ i ] = mwc2eq ( arDouble[ i ], pci );
  }

  return FindBestCubeDecision ( arDouble, aarOutput, pci );
}
  


static int
fDoCubeful ( cubeinfo *pci ) {

    if( pci->anScore[ 0 ] + pci->nCube >= pci->nMatchTo &&
	pci->anScore[ 1 ] + pci->nCube >= pci->nMatchTo )
	/* cube is dead */
	return FALSE;

    if( pci->anScore[ 0 ] == pci->nMatchTo - 2 &&
	pci->anScore[ 1 ] == pci->nMatchTo - 2 )
	/* score is -2,-2 */
	return FALSE;

    if ( pci->fCrawford )
      /* cube is dead in Crawford game */
      return FALSE;

    return TRUE;
}

    
extern int
GetDPEq ( int *pfCube, float *prDPEq, const cubeinfo *pci ) {

  int fCube, fPostCrawford;

  if ( ! pci->nMatchTo ) {

    /* Money game:
       Double, pass equity for money game is 1.0 points, since we always
       calculate equity normed to a 1-cube.
       Take the double branch if the cube is centered or I own the cube. */

    if ( prDPEq ) 
      *prDPEq = 1.0;

    fCube = 
      ( pci -> fCubeOwner == -1 ) || ( pci -> fCubeOwner == pci -> fMove );

    if ( pfCube )
      *pfCube = fCube;

  }
  else {

    /* Match play:
       Equity for double, pass is found from the match equity table.
       Take the double branch is I can/will use cube:
       - if it is not the Crawford game,
       - and if the cube is not dead,
       - and if it is post-Crawford and I'm trailing
       - and if I have access to the cube.
    */

    /* FIXME: equity for double, pass */
      fPostCrawford = !pci->fCrawford &&
	  ( pci->anScore[ 0 ] == pci->nMatchTo - 1 ||
	    pci->anScore[ 1 ] == pci->nMatchTo - 1 );
      
      fCube = ( !pci->fCrawford ) &&
	  ( pci->anScore[ pci->fMove ] + pci->nCube < pci->nMatchTo ) &&
	  ( !( fPostCrawford &&
	       ( pci->anScore[ pci->fMove ] == pci->nMatchTo - 1 ) ) )
	  && ( ( pci->fCubeOwner == -1 ) ||
	       ( pci->fCubeOwner == pci->fMove ) );   

    if ( prDPEq )
      *prDPEq =
        getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo,
                pci->fMove, pci->nCube, pci->fMove, pci->fCrawford,
                aafMET, aafMETPostCrawford );

    if ( pfCube )
      *pfCube = fCube;
      
  }

  return fCube;

}


static float
MoneyLive( const float rW, const float rL, const float p,
           const cubeinfo *pci ) {

  if ( pci->fCubeOwner == -1 ) {

    /* centered cube */
    float rTP = ( rL - 0.5 ) / ( rW + rL + 0.5 );
    float rCP = ( rL + 1.0 ) / ( rW + rL + 0.5 ); 

    if ( p < rTP )
      /* linear interpolation between
         (0,-rL) and ( rTP,-1) */
      return ( pci->fJacoby ) ? -1.0f : ( -rL + ( -1.0f + rL ) * p / rTP );
    else if ( p < rCP )
      /* linear interpolation between
         (rTP,-1) and (rCP,+1) */
      return -1.0f + 2.0f * ( p - rTP ) / ( rCP - rTP );
    else
      /* linear interpolation between
         (rCP,+1) and (1,+rW) */
      return ( pci->fJacoby ) ? 1.0f : ( +1.0f + ( rW - 1.0f ) * ( p - rCP ) / ( 1.0f - rCP ) );

  }
  else if ( pci->fCubeOwner == pci->fMove ) {

    /* owned cube */

    /* cash point */
    float rCP = ( rL + 1.0 ) / ( rW + rL + 0.5 ); 

    if ( p < rCP )
      /* linear interpolation between
         (0,-rL) and (rCP,+1) */
      return -rL + ( 1.0f + rL ) * p / rCP;
    else
      /* linear interpolation between
         (rCP,+1) and (1,+rW) */
      return +1.0f + ( rW - 1.0f ) * ( p - rCP ) / ( 1.0f - rCP );

  }
  else {

    /* unavailable cube */

    /* take point */
    float rTP = ( rL - 0.5 ) / ( rW + rL + 0.5 );

    if ( p < rTP )
      /* linear interpolation between
         (0,-rL) and ( rTP,-1) */
      return -rL + ( -1.0f + rL ) * p / rTP;
    else
      /* linear interpolation between
         (rTP,-1) and (1,rW) */
      return -1.0f + ( rW + 1.0f ) * ( p - rTP ) / ( 1.0f - rTP );

  }

  g_assert ( FALSE );
  return 0;

}


static float
Cl2CfMoney ( float arOutput [ NUM_OUTPUTS ], cubeinfo *pci, float rCubeX ) {

  const float epsilon   = 0.0000001f;
  const float omepsilon = 0.9999999f;

  float rW, rL;
  float rEqDead, rEqLive;

  /* money game */

  /* Transform cubeless 0-ply equity to cubeful 0-ply equity using
     Rick Janowski's formulas [insert ref here]. */

  /* First calculate average win and loss W and L: */

  if ( arOutput[ 0 ] > epsilon )
    rW = 1.0 + ( arOutput[ 1 ] + arOutput[ 2 ] ) / arOutput[ 0 ];
  else {
    /* basically a dead cube */
    return Utility ( arOutput, pci );
  }

  if ( arOutput[ 0 ] < omepsilon )
    rL = 1.0 + ( arOutput[ 3 ] + arOutput[ 4 ] ) /
      ( 1.0 - arOutput [ 0 ] );
  else {
    /* basically a dead cube */
    return Utility ( arOutput, pci );
  }

  
  rEqDead = Utility( arOutput, pci );
  rEqLive = MoneyLive( rW, rL, arOutput[ 0 ], pci );

  return rEqDead * ( 1.0 - rCubeX ) + rEqLive * rCubeX;

}


static float
Cl2CfMatch ( float arOutput [ NUM_OUTPUTS ], cubeinfo *pci, float rCubeX ) {

  /* Check if this requires a cubeful evaluation */

  if ( ! fDoCubeful ( pci ) ) {

    /* cubeless eval */

    return eq2mwc ( Utility ( arOutput, pci ), pci );

  } /* fDoCubeful */
  else {

    /* cubeful eval */

    if ( pci->fCubeOwner == -1 ) 
      return Cl2CfMatchCentered ( arOutput, pci, rCubeX );
    else if ( pci->fCubeOwner == pci->fMove )
      return Cl2CfMatchOwned ( arOutput, pci, rCubeX );
    else
      return Cl2CfMatchUnavailable ( arOutput, pci, rCubeX );

  }

}
  

static float
Cl2CfMatchOwned ( float arOutput [ NUM_OUTPUTS ], cubeinfo *pci, float rCubeX ) {

  /* normalized score */

  float rG0, rBG0, rG1, rBG1;
  float arCP[ 2 ];

  float rMWCDead, rMWCLive, rMWCWin, rMWCLose;
  float rMWCCash, rTG;
  float aarMETResult[2][DTLBP1 + 1];

  /* I own cube */

  /* Calculate normal, gammon, and backgammon ratios */

  if ( arOutput[ 0 ] > 0.0 ) {
    rG0 = ( arOutput[ 1 ] - arOutput[ 2 ] ) / arOutput[ 0 ];
    rBG0 = arOutput[ 2 ] / arOutput[ 0 ];
  }
  else {
    rG0 = 0.0;
    rBG0 = 0.0;
  }

  if ( arOutput[ 0 ] < 1.0 ) {
    rG1 = ( arOutput[ 3 ] - arOutput[ 4 ] ) / ( 1.0 - arOutput[ 0 ] );
    rBG1 = arOutput[ 4 ] / ( 1.0 - arOutput[ 0 ] );
  }
  else {
    rG1 = 0.0;
    rBG1 = 0.0;
  }

  /* MWC(dead cube) = cubeless equity */

  rMWCDead = eq2mwc ( Utility ( arOutput, pci ), pci );

  /* Get live cube cash points */

  GetPoints ( arOutput, pci, arCP );

  getMEMultiple ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo,
				  pci->nCube, -1, -1, pci->fCrawford,
				  aafMET, aafMETPostCrawford,
				  aarMETResult[0], aarMETResult[1]);

  rMWCCash = aarMETResult[pci->fMove][NDW];

  rTG = arCP[ pci->fMove ];

  if ( arOutput[ 0 ] <= rTG ) {
    
    /* MWC(live cube) linear interpolation between the
       points:

       p = 0, MWC = I lose (normal, gammon, or backgammon)
       p = TG, MWC = I win 1 point
	 
    */

    rMWCLose = ( 1.0 - rG1 - rBG1 ) * aarMETResult[pci->fMove][NDL]
      + rG1 * aarMETResult[pci->fMove][NDLG]
      + rBG1 * aarMETResult[pci->fMove][NDLB];

    if ( rTG > 0.0 )
      rMWCLive = rMWCLose + 
        ( rMWCCash - rMWCLose ) * arOutput[ 0 ] / rTG;
    else
      rMWCLive = rMWCLose;

    /* (1-x) MWC(dead) + x MWC(live) */

    return  rMWCDead * ( 1.0 - rCubeX ) + rMWCLive * rCubeX;

  } 
  else {

    /* we are too good to double */

    /* MWC(live cube) linear interpolation between the
       points:

       p = TG, MWC = I win 1 point
       p = 1, MWC = I win (normal, gammon, or backgammon)
	 
    */

    rMWCWin = 
      ( 1.0 - rG0 - rBG0 ) * aarMETResult[pci->fMove][NDW]
      + rG0 * aarMETResult[pci->fMove][NDWG]
      + rBG0 * aarMETResult[pci->fMove][NDWB];

    if ( rTG < 1.0 )
      rMWCLive = rMWCCash + 
        ( rMWCWin - rMWCCash ) * ( arOutput[ 0 ] - rTG ) / ( 1.0 - rTG );
    else
      rMWCLive = rMWCWin;
      
    /* (1-x) MWC(dead) + x MWC(live) */

    return  rMWCDead * ( 1.0 - rCubeX ) + rMWCLive * rCubeX;

  }

}


static float
Cl2CfMatchUnavailable ( float arOutput [ NUM_OUTPUTS ], cubeinfo *pci, float rCubeX ) {

  /* normalized score */

  float rG0, rBG0, rG1, rBG1;
  float arCP[ 2 ];

  float rMWCDead, rMWCLive, rMWCWin, rMWCLose;
  float rMWCOppCash, rOppTG;
  float aarMETResult[2][DTLBP1 + 1];

  /* I own cube */

  /* Calculate normal, gammon, and backgammon ratios */

  if ( arOutput[ 0 ] > 0.0 ) {
    rG0 = ( arOutput[ 1 ] - arOutput[ 2 ] ) / arOutput[ 0 ];
    rBG0 = arOutput[ 2 ] / arOutput[ 0 ];
  }
  else {
    rG0 = 0.0;
    rBG0 = 0.0;
  }

  if ( arOutput[ 0 ] < 1.0 ) {
    rG1 = ( arOutput[ 3 ] - arOutput[ 4 ] ) / ( 1.0 - arOutput[ 0 ] );
    rBG1 = arOutput[ 4 ] / ( 1.0 - arOutput[ 0 ] );
  }
  else {
    rG1 = 0.0;
    rBG1 = 0.0;
  }

  /* MWC(dead cube) = cubeless equity */

  rMWCDead = eq2mwc ( Utility ( arOutput, pci ), pci );

  /* Get live cube cash points */

  GetPoints ( arOutput, pci, arCP );

  getMEMultiple ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo,
				  pci->nCube, -1, -1, pci->fCrawford,
				  aafMET, aafMETPostCrawford,
				  aarMETResult[0], aarMETResult[1]);

  rMWCOppCash = aarMETResult[pci->fMove][NDL];

  rOppTG = 1.0 - arCP[ ! pci->fMove ];

  if ( arOutput[ 0 ] <= rOppTG ) {

    /* Opponent is too good to double.

       MWC(live cube) linear interpolation between the
       points:

       p = 0, MWC = opp win normal, gammon, backgammon
       p = OppTG, MWC = opp cashes
	 
    */

    rMWCLose = ( 1.0 - rG1 - rBG1 ) * aarMETResult[pci->fMove][NDL]
      + rG1 * aarMETResult[pci->fMove][NDLG]
      + rBG1 * aarMETResult[pci->fMove][NDLB];

    if ( rOppTG > 0.0 ) 
      /* avoid division by zero */
      rMWCLive = rMWCLose + 
        ( rMWCOppCash - rMWCLose ) * arOutput[ 0 ] / rOppTG;
    else
      rMWCLive = rMWCLose;
      
    /* (1-x) MWC(dead) + x MWC(live) */

    return  rMWCDead * ( 1.0 - rCubeX ) + rMWCLive * rCubeX;

  }
  else {

    /* MWC(live cube) linear interpolation between the
       points:

       p = OppTG, MWC = opponent cashes
       p = 1, MWC = I win (normal, gammon, or backgammon)
	 
    */

    rMWCWin = ( 1.0 - rG0 - rBG0 ) * aarMETResult[pci->fMove][NDW]
      + rG0 * aarMETResult[pci->fMove][NDWG]
      + rBG0 * aarMETResult[pci->fMove][NDWB];

    if ( arOutput[ 0 ] != rOppTG )
      rMWCLive = rMWCOppCash + 
        ( rMWCWin - rMWCOppCash ) * ( arOutput[ 0 ] - rOppTG ) 
        / ( 1.0 - rOppTG );
    else
      rMWCLive = rMWCWin;

    /* (1-x) MWC(dead) + x MWC(live) */

    return  rMWCDead * ( 1.0 - rCubeX ) + rMWCLive * rCubeX;

  } 

}


static float
Cl2CfMatchCentered ( float arOutput [ NUM_OUTPUTS ], cubeinfo *pci, float rCubeX ) {

  /* normalized score */

  float rG0, rBG0, rG1, rBG1;
  float arCP[ 2 ];

  float rMWCDead, rMWCLive, rMWCWin, rMWCLose;
  float rMWCOppCash, rMWCCash, rOppTG, rTG;
  float aarMETResult[2][DTLBP1 + 1];

  /* Centered cube */

  /* Calculate normal, gammon, and backgammon ratios */

  if ( arOutput[ 0 ] > 0.0 ) {
    rG0 = ( arOutput[ 1 ] - arOutput[ 2 ] ) / arOutput[ 0 ];
    rBG0 = arOutput[ 2 ] / arOutput[ 0 ];
  }
  else {
    rG0 = 0.0;
    rBG0 = 0.0;
  }

  if ( arOutput[ 0 ] < 1.0 ) {
    rG1 = ( arOutput[ 3 ] - arOutput[ 4 ] ) / ( 1.0 - arOutput[ 0 ] );
    rBG1 = arOutput[ 4 ] / ( 1.0 - arOutput[ 0 ] );
  }
  else {
    rG1 = 0.0;
    rBG1 = 0.0;
  }

  /* MWC(dead cube) = cubeless equity */

  rMWCDead = eq2mwc ( Utility ( arOutput, pci ), pci );

  /* Get live cube cash points */

  GetPoints ( arOutput, pci, arCP );

  getMEMultiple ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo,
				  pci->nCube, -1, -1, pci->fCrawford,
				  aafMET, aafMETPostCrawford,
				  aarMETResult[0], aarMETResult[1]);

  rMWCCash = aarMETResult[pci->fMove][NDW];

  rMWCOppCash = aarMETResult[pci->fMove][NDL];

  rOppTG = 1.0 - arCP[ ! pci->fMove ];
  rTG = arCP[ pci->fMove ];

  if ( arOutput[ 0 ] <= rOppTG ) {

    /* Opp too good to double */

    rMWCLose = ( 1.0 - rG1 - rBG1 ) * aarMETResult[pci->fMove][NDL]
      + rG1 * aarMETResult[pci->fMove][NDLG]
      + rBG1 * aarMETResult[pci->fMove][NDLB];

    if ( rOppTG > 0.0 ) 
      /* avoid division by zero */
      rMWCLive = rMWCLose + 
        ( rMWCOppCash - rMWCLose ) * arOutput[ 0 ] / rOppTG;
    else
      rMWCLive = rMWCLose;
      
    /* (1-x) MWC(dead) + x MWC(live) */

    return  rMWCDead * ( 1.0 - rCubeX ) + rMWCLive * rCubeX;

  }
  else if ( rOppTG < arOutput[ 0 ] && arOutput[ 0 ] < rTG ) {

    /* In double window */

    rMWCLive = 
      rMWCOppCash + 
      (rMWCCash - rMWCOppCash) * ( arOutput[ 0 ] - rOppTG ) / ( rTG - rOppTG); 
    return  rMWCDead * ( 1.0 - rCubeX ) + rMWCLive * rCubeX;

  } else {

    /* I'm too good to double */

    /* MWC(live cube) linear interpolation between the
       points:

       p = TG, MWC = I win 1 point
       p = 1, MWC = I win (normal, gammon, or backgammon)
	 
    */

    rMWCWin = ( 1.0 - rG0 - rBG0 ) * aarMETResult[pci->fMove][NDW]
      + rG0 * aarMETResult[pci->fMove][NDWG]
	  + rBG0 * aarMETResult[pci->fMove][NDWB];

    if ( rTG < 1.0 )
      rMWCLive = rMWCCash + 
        ( rMWCWin - rMWCCash ) * ( arOutput[ 0 ] - rTG ) / ( 1.0 - rTG );
    else
      rMWCLive = rMWCWin;

    /* (1-x) MWC(dead) + x MWC(live) */

    return  rMWCDead * ( 1.0 - rCubeX ) + rMWCLive * rCubeX;

  } 

}

static float
EvalEfficiency( int anBoard[2][25], positionclass pc ){

  /* Since it's somewhat costly to call CalcInputs, the 
     inputs should preferebly be cached to same time. */

  switch ( pc ) {
  case CLASS_OVER:
    return 0.0; /* dead cube */
    break;

  case CLASS_HYPERGAMMON1:
  case CLASS_HYPERGAMMON2:
  case CLASS_HYPERGAMMON3:
    
    /* FIXME */
    
     return 0.60f;
     break;
     
  case CLASS_BEAROFF1:
  case CLASS_BEAROFF_OS:
    /* FIXME: calculate based on #rolls to get off.
       For example, 15 rolls probably have cube eff. of
       0.7, and 1.25 rolls have cube eff. of 1.0.

       It's not so important to have cube eff. correct here as an
       n-ply evaluation will take care of last-roll and 2nd-last-roll
       situations. */

    return rOSCubeX;
    break;

  case CLASS_RACE:
    {
      unsigned int anPips[2];

      float rEff;

      PipCount(anBoard, anPips);

      rEff = anPips[1]*rRaceFactorX + rRaceCoefficientX;
      if (rEff > rRaceMax)
        return rRaceMax;
      else {
        if (rEff < rRaceMin)
          return rRaceMin;
        else
          return rEff;
      }
    }

  case CLASS_CONTACT:

    /* FIXME: should CLASS_CRASHED be handled differently? */
    
    /* FIXME: use �ystein's values published in rec.games.backgammon,
       or work some other semiempirical values */
    
    /* FIXME: very important: use opponents inputs as well */
    
    return rContactX ;
    break;

  case CLASS_CRASHED:

    return rCrashedX;
    break;

  case CLASS_BEAROFF2:
  case CLASS_BEAROFF_TS:

    return 0.0f; /* not used */
    break;

  default:
    g_assert( FALSE );
    break;

  }
  return 0;

}


extern char *FormatEval ( char *sz, evalsetup *pes ) {

  switch ( pes->et ) {
  case EVAL_NONE:
    strcpy ( sz, "" );
    break;
  case EVAL_EVAL:
    sprintf ( sz, _("%s %1i-ply"), 
              pes->ec.fCubeful ? _("Cubeful") : _("Cubeless"),
              pes->ec.nPlies );
    break;
  case EVAL_ROLLOUT:
    sprintf ( sz, "%s", _("Rollout") );
    break;
  default:
    sprintf ( sz, "Unknown (%d)", pes->et );
    break;
  }

  return sz;

}

#if 0 
static void
CalcCubefulEquity ( positionclass pc,
                    float arOutput[ NUM_ROLLOUT_OUTPUTS ],
                    int nPlies, int fDT, cubeinfo *pci ) {

  float rND, rDT, rDP, r;
  int fCube;
  cubeinfo ci;
  float ar[ NUM_ROLLOUT_OUTPUTS ];

  int fMax = ! ( nPlies % 2 );

  memcpy ( &ar[ 0 ], &arOutput[ 0 ], NUM_OUTPUTS * sizeof ( float ) );

  if ( ! nPlies ) {

    /* leaf node */

      if ( pc == CLASS_OVER ||
           ( pci->nMatchTo && ! fDoCubeful( pci ) ) ) {

        /* cubeless */

        rND = Utility ( arOutput, pci );

      }
      else {

        /* cubeful */

        rND = ( pci->nMatchTo ) ?
          mwc2eq ( Cl2CfMatch ( arOutput, pci ), pci ) :
          Cl2CfMoney ( arOutput, pci );
        
      }

    }
  else {

    /* internal node; recurse */

    SetCubeInfo ( &ci,
                  pci->nCube, pci->fCubeOwner,
                  ! pci->fMove, pci->nMatchTo,
                  pci->anScore, pci->fCrawford,
                  pci->fJacoby, pci->fBeavers, pci->bgv );

    CalcCubefulEquity ( pc, ar, nPlies - 1, TRUE, &ci );

    rND = ar[ OUTPUT_CUBEFUL_EQUITY ];

  }

  GetDPEq ( &fCube, &rDP, pci );

  if ( pci->nMatchTo )
    rDP = mwc2eq ( rDP, pci );

  if ( fCube && fDT ) {

    /* double, take */

    if ( ! nPlies ) {

      SetCubeInfo ( &ci, 2 * pci->nCube, ! pci->fMove, pci->fMove,
                    pci->nMatchTo, pci->anScore, pci->fCrawford, pci->fJacoby,
                    pci->fBeavers, pci->bgv );

      /* leaf node */

      if ( pc == CLASS_OVER ||
           ( pci->nMatchTo && ! fDoCubeful( &ci ) ) ) {

        /* cubeless */

        rDT = Utility ( arOutput, &ci );
        if ( pci->nMatchTo ) rDT *= 2.0;

      }
      else {

        /* cubeful */

        rDT = ( pci->nMatchTo ) ?
          mwc2eq ( Cl2CfMatch ( arOutput, &ci ), &ci ) :
          2.0 * Cl2CfMoney ( arOutput, &ci );

      }

    }
    else {

      /* internal node; recurse */

      SetCubeInfo ( &ci, 2 * pci->nCube, ! pci->fMove, ! pci->fMove,
                    pci->nMatchTo, pci->anScore, pci->fCrawford, pci->fJacoby,
                    pci->fBeavers, pci->bgv );

      CalcCubefulEquity ( pc, ar, nPlies - 1, TRUE, &ci );

      rDT = ar[ OUTPUT_CUBEFUL_EQUITY ];
      if ( ! ci.nMatchTo ) rDT *= 2.0;

    }

    if ( fMax ) {

      /* maximize my equity */

      if ( rDP > rND && rDT > rND ) {

        /* it's a double */

        if ( rDT >= rDP )
          r = rDP; /* pass */
        else
          r = rDT; /* take */
        
      }
      else
        r = rND; /* no double */
      
    } 
    else {

      /* minimize my equity */

      rDP = - rDP;

      if ( rDP < rND && rDT < rND ) {
        
        /* it's a double */

        if ( rDT < rDP )
          r = rDP; /* pass */
        else
          r = rDT; /* take */

      }
      else
        r= rND; /* no double */

    }
  }
  else {
    r = rND;
    rDT = 0.0;
  }

  arOutput[ OUTPUT_EQUITY ] = UtilityME ( arOutput, pci );
  arOutput[ OUTPUT_CUBEFUL_EQUITY ] = r;

}
#endif 

extern int
GeneralCubeDecisionE ( float aarOutput[ 2 ][ NUM_ROLLOUT_OUTPUTS ],
                       int anBoard[ 2 ][ 25 ],
                       const cubeinfo* pci,
		       const evalcontext* pec, const evalsetup* pes ) {

  float arOutput[ NUM_OUTPUTS ];
  cubeinfo aciCubePos[ 2 ];
  float arCubeful[ 2 ];
  int i,j;


  /* Setup cube for "no double" and "double, take" */

  memcpy ( &aciCubePos[ 0 ], pci, sizeof ( cubeinfo ) );
  memcpy ( &aciCubePos[ 1 ], pci, sizeof ( cubeinfo ) );
  aciCubePos[ 1 ].fCubeOwner = ! aciCubePos[ 1 ].fMove;
  aciCubePos[ 1 ].nCube *= 2;

  if ( EvaluatePositionCubeful3 ( NULL, anBoard, 
                                  arOutput, 
                                  arCubeful,
                                  aciCubePos, 2,
                                  pci, pec, pec->nPlies, TRUE ) )
    return -1;

  
  /* Scale double-take equity */
  if ( ! pci->nMatchTo )
    arCubeful[ 1 ] *= 2.0;

  for ( i = 0; i < 2; i++ ) {

    /* copy cubeless winning chances */
    for ( j = 0; j < NUM_OUTPUTS; j++ )
      aarOutput[ i ][ j ] = arOutput[ j ];

    /* equity */

    aarOutput[ i ][ OUTPUT_EQUITY ] =
      UtilityME ( arOutput, &aciCubePos[ i ] );

    aarOutput[ i ][ OUTPUT_CUBEFUL_EQUITY ] = arCubeful[ i ];

  }

  return 0;

}

extern int
GeneralEvaluationE( float arOutput [ NUM_ROLLOUT_OUTPUTS ],
                    int anBoard[ 2 ][ 25 ],
                    const cubeinfo* pci, const evalcontext *pec) {

  return GeneralEvaluationEPlied ( NULL, arOutput, anBoard,
                                   pci, pec, pec->nPlies );

}


extern int 
GeneralEvaluationEPliedCubeful ( NNState *nnStates, float arOutput [ NUM_ROLLOUT_OUTPUTS ],
                                 int anBoard[ 2 ][ 25 ],
                                 const cubeinfo* pci, const evalcontext* pec,
                                 int nPlies ) {

  float rCubeful;

  if ( EvaluatePositionCubeful3 ( nnStates, anBoard, 
                                  arOutput, 
                                  &rCubeful,
                                  pci, 1,
                                  pci, pec, nPlies, FALSE ) )
    return -1;

  arOutput[ OUTPUT_EQUITY ] = UtilityME ( arOutput, pci );
  arOutput[ OUTPUT_CUBEFUL_EQUITY ] = rCubeful;

  return 0;

}

extern int
GeneralEvaluationEPlied (NNState *nnStates, float arOutput [ NUM_ROLLOUT_OUTPUTS ],
                          int anBoard[ 2 ][ 25 ],
                          const cubeinfo* pci, const evalcontext* pec,
			  int nPlies ) {

  if ( pec->fCubeful ) {

    if ( GeneralEvaluationEPliedCubeful ( nnStates, arOutput, anBoard, pci,
                                          pec, nPlies ) )
      return -1;

  } 
  else {
    if ( EvaluatePositionCache ( nnStates, anBoard, arOutput, pci, pec,
                                 nPlies, 
                                 ClassifyPosition ( anBoard, pci->bgv ) ) )
      return -1;

    arOutput[ OUTPUT_EQUITY ] = UtilityME ( arOutput, pci );
    arOutput[ OUTPUT_CUBEFUL_EQUITY ] = 0.0f;

  }

  return 0;

}

static void 
GetECF3 ( float arCubeful[], int cci,
          float arCf[], cubeinfo aci[] ) {

  int i,ici;
  float rND, rDT, rDP;

  for ( ici = 0, i = 0; ici < cci; ici++, i += 2 ) {

    if ( aci[ i + 1 ].nCube > 0 ) {

      /* cube available */

      rND = arCf [ i ];

      if ( aci[ 0 ].nMatchTo )
        rDT = arCf [ i + 1 ];
      else
        rDT = 2.0 * arCf[ i + 1 ];

      GetDPEq ( NULL, &rDP, &aci[ i ] );

      if ( rDT >= rND && rDP >= rND ) {

        /* double */

        if ( rDT >= rDP )
          /* pass */
          arCubeful[ ici ] = rDP;
        else
          /* take */
          arCubeful[ ici ] = rDT;

      }
      else {

        /* no double */

        arCubeful [ici ] = rND;

      }


    }
    else {

      /* no cube available: always no double */

      arCubeful[ ici ] = arCf[ i ];

    }

  }

}


static void
MakeCubePos( const cubeinfo aciCubePos[], const int cci,
	     const int fTop, cubeinfo aci[], const int fInvert )
{
  int i, ici;

  for ( ici = 0, i = 0; ici < cci; ici++ ) {

    /* no double */

    if ( aciCubePos[ ici ].nCube > 0 ) {

      SetCubeInfo ( &aci[ i ], 
                    aciCubePos[ ici ].nCube,
                    aciCubePos[ ici ].fCubeOwner,
                    fInvert ?
                    ! aciCubePos[ ici ].fMove : aciCubePos[ ici ].fMove,
                    aciCubePos[ ici ].nMatchTo,
                    aciCubePos[ ici ].anScore,
                    aciCubePos[ ici ].fCrawford,
                    aciCubePos[ ici ].fJacoby,
                    aciCubePos[ ici ].fBeavers,
                    aciCubePos[ ici ].bgv );

    } 
    else {

      aci[ i ].nCube = -1;

    }

    i++;

    if ( ! fTop && aciCubePos[ ici ].nCube > 0 &&
         GetDPEq ( NULL, NULL, &aciCubePos[ ici ] ) ) 
      /* we may double */
      SetCubeInfo ( &aci[ i ], 
                    2 * aciCubePos[ ici ].nCube,
                    ! aciCubePos[ ici ].fMove,
                    fInvert ?
                    ! aciCubePos[ ici ].fMove : aciCubePos[ ici ].fMove,
                    aciCubePos[ ici ].nMatchTo,
                    aciCubePos[ ici ].anScore,
                    aciCubePos[ ici ].fCrawford,
                    aciCubePos[ ici ].fJacoby,
                    aciCubePos[ ici ].fBeavers,
                    aciCubePos[ ici ].bgv );
    else
      /* mark cube position as unavaiable */
      aci[ i ].nCube = -1;

    i++;


  } /* loop cci */

}


/* EvaluatePositionCubeful3 is now just a wrapper for ....Cubeful4, which
   first checks the cache, and then calls ...Cubeful3 */

extern int 
EvaluatePositionCubeful3( NNState *nnStates, int anBoard[ 2 ][ 25 ],
                          float arOutput[ NUM_OUTPUTS ],
                          float arCubeful[],
                          const cubeinfo aciCubePos[], int cci, 
                          const cubeinfo* pciMove, const evalcontext *pec, 
                          int nPlies, int fTop ) {

  int ici;
  int fAll = TRUE;
  evalcache ec;
  unsigned long l;

  if( !cCache || ( pec->rNoise != 0.0f && !pec->fDeterministic ) )
      /* non-deterministic evaluation; never cache */
{
      return EvaluatePositionCubeful4( nnStates, anBoard, arOutput, arCubeful,
				       aciCubePos, cci, pciMove, pec,
				       nPlies, fTop );
}

  PositionKey ( anBoard, ec.auchKey );

  /* check cache for existence for earlier calculation */

  fAll = ! fTop; /* FIXME: fTop should be a part of EvalKey */

  for ( ici = 0; ici < cci && fAll; ++ici ) {

      if ( aciCubePos[ ici ].nCube < 0 )
	  {
        continue;
	  }
      /* argh, bug #9211: the stuff in EvalKey only stores 4 bit for
         the score, so a score of -20,-20 is treated identical to
         -4,-4.... */



      ec.nEvalContext = EvalKey ( pec, nPlies, &aciCubePos[ ici ], TRUE );

	  if ( ( l = CacheLookup( &cEval, &ec, arOutput, arCubeful + ici ) ) != CACHEHIT ) {
        fAll = FALSE;
	  }
  }

  /* get equities */
  
  if ( ! fAll ) {

    /* cache miss */
    if ( EvaluatePositionCubeful4 ( nnStates, anBoard, arOutput, arCubeful, 
                                    aciCubePos, 
                                    cci, pciMove, pec, nPlies, fTop ) )
      return -1;
    
    /* add to cache */
    
    if ( ! fTop ) {

      for ( ici = 0; ici < cci; ++ici ) {
        if ( aciCubePos[ ici ].nCube < 0 )
          continue;
        
        memcpy ( ec.ar, arOutput, sizeof ( float ) * NUM_OUTPUTS );
        ec.ar[ OUTPUT_CUBEFUL_EQUITY ] = arCubeful[ ici ];
        
        ec.nEvalContext = EvalKey ( pec, nPlies, &aciCubePos[ ici ], TRUE );

	CacheAddNoKey( &cEval, &ec);

      }
    }
  }

  return 0;
  
}

#include "drawboard.h"
  
static int 
EvaluatePositionCubeful4( NNState *nnStates, int anBoard[ 2 ][ 25 ],
                          float arOutput[ NUM_OUTPUTS ],
                          float arCubeful[],
                          const cubeinfo aciCubePos[], int cci, 
                          const cubeinfo* pciMove, const evalcontext* pec, 
                          int nPlies, int fTop ) {
  
  
  /* calculate cubeful equity */

  int i, ici;
  positionclass pc;
  float r;
  float ar[ NUM_OUTPUTS ];
  float arEquity[ 4 ];
  float rCubeX;

  cubeinfo ciMoveOpp;

  float *arCf = (float*) g_alloca(2 * cci * sizeof(float));
  float *arCfTemp = (float*) g_alloca(2 * cci * sizeof(float));
  cubeinfo *aci = (cubeinfo*) g_alloca(2 * cci * sizeof(cubeinfo));

#if defined( REDUCTION_CODE )
  int fUseReduction, ir;
  laRollList_t *rolls = NULL;
  laRollList_t *rollList = NULL;
#endif
  int w
#if defined( REDUCTION_CODE )
    , sumW
#endif
    ;
  int n0, n1;

  pc = ClassifyPosition ( anBoard, pciMove->bgv );
  
  if( pc > CLASS_OVER && nPlies > 0 && 
      ! ( pc <= CLASS_PERFECT && !pciMove->nMatchTo ) ) {
    /* internal node; recurse */

    int anBoardNew[ 2 ][ 25 ];

#if !defined( REDUCTION_CODE )
    int const  usePrune =
      pec->fUsePrune && !pec->rNoise && pciMove->bgv == VARIATION_STANDARD;
#endif

    for( i = 0; i < NUM_OUTPUTS; i++ )
      arOutput[ i ] = 0.0;

    for ( i = 0; i < 2 * cci; i++ )
      arCf[ i ] = 0.0;

    /* construct next level cube positions */

    MakeCubePos ( aciCubePos, cci, fTop, aci, TRUE );

#if defined( REDUCTION_CODE )
    /* speed reduction */

    /* make sure to reset nReductionGroup */

    if ( pec->nReduced && ( nPlies == pec->nPlies ) )
      nReductionGroup = 0;

    fUseReduction = pec->nReduced && ( nPlies == 1 ) && ( pec->nPlies > 0 );

    if ( fUseReduction ) {
      nReductionGroup = (nReductionGroup + 1) % pec->nReduced;
      rollList = rollLists[ pec->nReduced ];
      rolls = &rollList[ nReductionGroup ];
    }
    else
      rolls = &allLists[ 0 ];
    
#endif

    /* loop over rolls */

#if defined( REDUCTION_CODE )
    sumW = 0;
    for ( ir=0; ir < rolls->numRolls; ir++ ) {
      n0 = rolls->d1[ir];
      n1 = rolls->d2[ir];
      w  = rolls->wt[ir];
#else
    for( n0 = 1; n0 <= 6; n0++ ) {
      for( n1 = 1; n1 <= n0; n1++ ) {
	w = (n0 == n1) ? 1 : 2;
#endif

      for( i = 0; i < 25; i++ ) {
        anBoardNew[ 0 ][ i ] = anBoard[ 0 ][ i ];
        anBoardNew[ 1 ][ i ] = anBoard[ 1 ][ i ];
      }

      if( fAction )
        fnAction();

      if( fInterrupt ) {
        errno = EINTR;
        return -1;
      }

#if !defined( REDUCTION_CODE )
      if( usePrune ) {
	FindBestMoveInEval(nnStates, n0, n1, anBoardNew, pciMove, pec);
      } else {
#endif
	FindBestMovePlied( NULL, n0, n1, anBoardNew,
                         pciMove, pec, 0, defaultFilters );
#if !defined( REDUCTION_CODE )
      }
#endif

      SwapSides( anBoardNew );

      SetCubeInfo ( &ciMoveOpp,
                    pciMove->nCube, pciMove->fCubeOwner,
                    ! pciMove->fMove, pciMove->nMatchTo,
                    pciMove->anScore, pciMove->fCrawford,
                    pciMove->fJacoby, pciMove->fBeavers, pciMove->bgv );

	  /* Evaluate at 0-ply */
      if( EvaluatePositionCubeful3( nnStates, anBoardNew,
                                    ar,
                                    arCfTemp,
                                    aci,
                                    2 * cci,
                                    &ciMoveOpp,
                                    pec, nPlies - 1, FALSE ) )
        return -1;

      /* Sum up cubeless winning chances and cubeful equities */
	      
      for( i = 0; i < NUM_OUTPUTS; i++ )
        arOutput[ i ] += w * ar[ i ];
      for ( i = 0; i < 2 * cci; i++ )
        arCf[ i ] += w * arCfTemp[ i ];

#if defined( REDUCTION_CODE )
      sumW += w;
#endif

    }

#if defined( REDUCTION_CODE )
    /* reset reduction group */

    if ( pec->nReduced && ( nPlies == pec->nPlies ) )
      nReductionGroup = 0;
#else
    }
#endif

    /* Flip evals */
#if !defined( REDUCTION_CODE )
#define sumW 36
#endif
    
    arOutput[ OUTPUT_WIN ] =
      1.0 - arOutput[ OUTPUT_WIN ] / sumW;
	  
    r = arOutput[ OUTPUT_WINGAMMON ] / sumW;
    arOutput[ OUTPUT_WINGAMMON ] =
      arOutput[ OUTPUT_LOSEGAMMON ] / sumW;
    arOutput[ OUTPUT_LOSEGAMMON ] = r;
	  
    r = arOutput[ OUTPUT_WINBACKGAMMON ] / sumW;
    arOutput[ OUTPUT_WINBACKGAMMON ] =
      arOutput[ OUTPUT_LOSEBACKGAMMON ] / sumW;
    arOutput[ OUTPUT_LOSEBACKGAMMON ] = r;

    for ( i = 0; i < 2 * cci; i++ ) 
      if ( pciMove->nMatchTo )
        arCf[ i ] = 1.0 - arCf[ i ] / sumW;
      else
        arCf[ i ] = - arCf[ i ] / sumW;
#undef sumW
    
    /* invert fMove */
    /* Remember than fMove was inverted in the call to MakeCubePos */

    for ( i = 0; i < 2 * cci; i++ )
      aci[ i ].fMove = ! aci[ i ].fMove;

    /* get cubeful equities */

    GetECF3 ( arCubeful, cci, arCf, aci );

  } else {
    /* at leaf node; use static evaluation */

    if ( pc == CLASS_HYPERGAMMON1 || pc == CLASS_HYPERGAMMON2 ||
         pc == CLASS_HYPERGAMMON3 ) {

      bearoffcontext *pbc = apbcHyper[ pc - CLASS_HYPERGAMMON1 ];
      unsigned short int nUs, nThem, iPos;
      int n;

      if (!pbc)
        return -1;

      nUs = PositionBearoff ( anBoard[ 1 ], pbc->nPoints, pbc->nChequers );
      nThem = PositionBearoff ( anBoard[ 0 ],  pbc->nPoints, pbc->nChequers );
      n = Combination ( pbc->nPoints + pbc->nChequers, pbc->nPoints );
      iPos = nUs * n + nThem;
      
      if ( BearoffHyper ( apbcHyper[ pc - CLASS_HYPERGAMMON1 ], iPos,
                          arOutput, arEquity ) )
        return -1;

    }
    else if ( pc > CLASS_OVER && pc <= CLASS_PERFECT /* && ! pciMove->nMatchTo */ ) {

      if ( EvaluatePerfectCubeful ( anBoard, arEquity, pciMove->bgv ) ) {
        printf( "return -1 EPC Cubeful4\n" );
        return -1;
      }

      arOutput[ 0 ] = ( arEquity[ 0 ] + 1.0 ) / 2.0;
      arOutput[ 1 ] = arOutput[ 2 ] = arOutput[ 3 ] = arOutput[ 4 ] = 0.0;

    }
    else {

      /* evaluate with neural net */
      
      if( EvaluatePosition ( nnStates, anBoard, arOutput, pciMove, NULL ) )
        return -1;
      
      if( pec->rNoise )
        for( i = 0; i < NUM_OUTPUTS; i++ )
          arOutput[ i ] += Noise( pec, anBoard, i );

      if ( pc > CLASS_PERFECT )
        SanityCheck( anBoard, arOutput );
      
    }
    
    /* Calculate cube efficiency */
      
    rCubeX = EvalEfficiency ( anBoard, pc );

    /* Build all possible cube positions */
    
    MakeCubePos ( aciCubePos, cci, fTop, aci, FALSE );
    
    /* Calculate cubeful equity for each possible cube position */
    
    for ( ici = 0; ici < 2 * cci; ici++ ) 
      if ( aci[ ici ].nCube > 0 ) {
        /* cube available */

        if ( ! aci[ ici ].nMatchTo ) {

          /* money play */

          switch ( pc ) {
          case CLASS_HYPERGAMMON1:
          case CLASS_HYPERGAMMON2:
          case CLASS_HYPERGAMMON3:
            /* exact bearoff equities & contact */

            arCf[ ici ] = CFHYPER( arEquity, &aci[ ici ] );
            break;

          case CLASS_BEAROFF2:
          case CLASS_BEAROFF_TS:
            /* exact bearoff equities */

            arCf[ ici ] = CFMONEY( arEquity, &aci[ ici ] );
            break;

          case CLASS_OVER:
          case CLASS_RACE:
          case CLASS_CRASHED:
          case CLASS_CONTACT:
          case CLASS_BEAROFF1:
          case CLASS_BEAROFF_OS:
            /* approximate using Janowski's formulae */
            
            arCf[ ici ] = Cl2CfMoney ( arOutput, &aci[ ici ], rCubeX );
            break;

          }

        }
        else {

          float rCl, rCf, rCfMoney;
          float X = rCubeX;
          cubeinfo ciMoney;

          /* match play */

          switch ( pc ) {
          case CLASS_HYPERGAMMON1:
          case CLASS_HYPERGAMMON2:
          case CLASS_HYPERGAMMON3:
            /* use exact money equities to guess cube efficiency */

            SetCubeInfoMoney( &ciMoney, 1, aci[ ici ].fCubeOwner,
                         aci[ ici ].fMove, FALSE, FALSE, aci[ ici ].bgv );

            rCl = Utility( arOutput, &ciMoney );
            rCubeX = 1.0;
            rCf = Cl2CfMoney( arOutput, &ciMoney, rCubeX );
            rCfMoney = CFHYPER( arEquity, &ciMoney );

            if ( fabs( rCl - rCf ) > 0.0001 )
              rCubeX = ( rCfMoney - rCl ) / ( rCf - rCl );

            arCf[ ici ] = Cl2CfMatch( arOutput, &aci[ ici ], rCubeX );

            rCubeX = X;

            break;

          case CLASS_BEAROFF2:
          case CLASS_BEAROFF_TS:
            /* use exact money equities to guess cube efficiency */

            SetCubeInfoMoney( &ciMoney, 1, aci[ ici ].fCubeOwner,
                         aci[ ici ].fMove, FALSE, FALSE, aci[ ici ].bgv );

            rCl = arEquity[ 0 ];
            rCubeX = 1.0;
            rCf = Cl2CfMoney( arOutput, &ciMoney, rCubeX );
            rCfMoney = CFMONEY( arEquity, &ciMoney );

            if ( fabs( rCl - rCf ) > 0.0001 )
              rCubeX = ( rCfMoney - rCl ) / ( rCf - rCl );
            else
              rCubeX = X;

            arCf[ ici ] = Cl2CfMatch( arOutput, &aci[ ici ], rCubeX );

            rCubeX = X;

            break;

          case CLASS_OVER:
          case CLASS_RACE:
          case CLASS_CRASHED:
          case CLASS_CONTACT:
          case CLASS_BEAROFF1:
          case CLASS_BEAROFF_OS:
            /* approximate using Joern's generalisation of 
               Janowski's formulae */
            
            arCf[ ici ] = Cl2CfMatch ( arOutput, &aci[ ici ], rCubeX );
            break;

          }

        }

      }


    /* find optimal of "no double" and "double" */
    
    GetECF3 ( arCubeful, cci, arCf, aci );

  }
  
  return 0;

}  



/*
 * Compare two evalsetups.
 *
 * Input:
 *    - pes1, pes2: the two evalsetups to compare
 *
 * Output:
 *    None.
 *
 * Returns:
 *    -1 if  *pes1 "<" *pes2
 *     0 if  *pes1 "=" *pes2
 *    +1 if  *pes1 ">" *pes2
 *
 */

extern int
cmp_evalsetup ( const evalsetup *pes1, const evalsetup *pes2 ) {

  /* Check for different evaltypes */

  if ( pes1->et < pes2->et )
    return -1;
  else if ( pes1->et > pes2->et )
    return +1;

  /* The two evaltypes are identical */

  switch ( pes1->et ) {
  case EVAL_NONE:    return 0;

  case EVAL_EVAL:    return cmp_evalcontext ( &pes1->ec, &pes2->ec );

  case EVAL_ROLLOUT: return cmp_rolloutcontext ( &pes1->rc, &pes2->rc );

  default:
    g_assert ( FALSE );
  }

  return 0;
}


/*
 * Compare two evalcontexts.
 *
 * Input:
 *    - pec1, pec2: the two evalcontexts to compare
 *
 * Output:
 *    None.
 *
 * Returns:
 *    -1 if  *pec1 "<" *pec2
 *     0 if  *pec1 "=" *pec2
 *    +1 if  *pec1 ">" *pec2
 *
 */

extern int
cmp_evalcontext ( const evalcontext *pec1, const evalcontext *pec2 ) {

  /* Check if plies are different */

  if ( pec1->nPlies < pec2->nPlies )
    return -1;
  else if ( pec1->nPlies > pec2->nPlies )
    return +1;

  /* Check for cubeful evals */

  if ( pec1->fCubeful < pec2->fCubeful )
    return -1;
  else if ( pec1->fCubeful > pec2->fCubeful )
    return +1;

  /* Noise  */

  if ( pec1->rNoise > pec2->rNoise )
    return -1;
  else if ( pec1->rNoise < pec2->rNoise )
    return +1;

  if ( pec1->rNoise > 0 ) {

    if ( pec1->fDeterministic > pec2->fDeterministic )
      return -1;
    else if ( pec1->fDeterministic > pec2->fDeterministic )
      return +1;

  }

#if defined( REDUCTION_CODE )
  if ( pec1->nPlies > 0 ) {

    int n1 = ( pec1->nReduced != 21 ) ? pec1->nReduced : 0;
    int n2 = ( pec2->nReduced != 21 ) ? pec2->nReduced : 0;
    if ( n1 > n2 )
      return -1;
    else if ( n1 < n2 )
      return +1;
  }
#else
  if ( pec1->nPlies > 0 ) {
    int nPrune1 = (pec1->fUsePrune);
    int nPrune2 = (pec2->fUsePrune);
    if ( nPrune1 > nPrune2 )
	    return -1;
    else if (nPrune1 < nPrune2 )
	    return +1;
  }
#endif
  return 0;

}


/*
 * Compare two rolloutcontexts.
 *
 * Input:
 *    - prc1, prc2: the two evalsetups to compare
 *
 * Output:
 *    None.
 *
 * Returns:
 *    -1 if  *prc1 "<" *prc2
 *     0 if  *prc1 "=" *prc2
 *    +1 if  *prc1 ">" *prc2
 *
 */

extern int
cmp_rolloutcontext ( const rolloutcontext *prc1, const rolloutcontext *prc2 ) {

  /* FIXME: write me */

  return 0;


}


extern void
calculate_gammon_rates( float aarRates[ 2 ][ 2 ],
                        float arOutput[],
                        cubeinfo *pci ) {

  if ( arOutput[ OUTPUT_WIN ] > 0.0 ) {
    aarRates[ pci->fMove ][ 0 ] =
      ( arOutput[ OUTPUT_WINGAMMON ] - arOutput[ OUTPUT_WINBACKGAMMON ] ) /
      arOutput[ OUTPUT_WIN ];
    aarRates[ pci->fMove ][ 1 ] =
      arOutput[ OUTPUT_WINBACKGAMMON ] / arOutput[ OUTPUT_WIN ];
  }
  else {
    aarRates[ pci->fMove ][ 0 ] = aarRates[ pci->fMove ][ 1 ] = 0;
  }

  if ( arOutput[ OUTPUT_WIN ] < 1.0 ) {
    aarRates[ ! pci->fMove ][ 0 ] =
      ( arOutput[ OUTPUT_LOSEGAMMON ] -
        arOutput[ OUTPUT_LOSEBACKGAMMON ] ) /
      ( 1.0 - arOutput[ OUTPUT_WIN ] );
    aarRates[ ! pci->fMove ][ 1 ] =
      arOutput[ OUTPUT_LOSEBACKGAMMON ] /
      ( 1.0 - arOutput[ OUTPUT_WIN ] );
  }
  else {
    aarRates[ ! pci->fMove ][ 0 ] = aarRates[ ! pci->fMove ][ 1 ] = 0;
  }

}

/*
 * Get current gammon rates
 *
 * Input:
 *   anBoard: current board
 *   pci: current cubeinfo
 *   pec: eval context
 *
 * Output:
 *   aarRates: gammon and backgammon rates (first index is player)
 *
 */

extern int
getCurrentGammonRates ( float aarRates[ 2 ][ 2 ],
                        float arOutput[],
                        int anBoard[ 2 ][ 25 ],
                        cubeinfo *pci,
                        evalcontext *pec ) {

  if( EvaluatePosition( NULL, anBoard, arOutput, pci, pec ) < 0 )
      return -1;

  calculate_gammon_rates( aarRates, arOutput, pci );

  return 0;

}

/*
 * Get take, double, beaver, etc points for money game using
 * Rick Janowski's formulae:
 *   http://www.msoworld.com/mindzine/news/classic/bg/cubeformulae.html
 *
 * Input:
 *   fJacoby, fBeavers: flags for different flavours of money game
 *   aarRates: gammon and backgammon rates (first index is player)
 *
 * Output:
 *   aaarPoints: the points
 *
 */

extern void
getMoneyPoints ( float aaarPoints[ 2 ][ 7 ][ 2 ],
                 const int fJacoby, const int fBeavers,
                 float aarRates[ 2 ][ 2 ] ) {

  float arCLV[ 2 ];/* average cubeless value of games won */
  float rW, rL;
  int i;

  /* calculate average cubeless value of games won */

  for ( i = 0; i < 2; i++ )
    arCLV[ i ] = 1.0 + aarRates[ i ][ 0 ] + 2.0f * aarRates[ i ][ 1 ];

    /* calculate points */
    
  for ( i = 0; i < 2; i++ ) {

    /* Determine rW and rL from Rick's formulae */

    rW = arCLV[ i ];
    rL = arCLV[ ! i ];

    /* Determine points */

    /* take point */
      
    aaarPoints[ i ][ 0 ][ 0 ] = ( rL - 0.5 ) / ( rW + rL );
    aaarPoints[ i ][ 0 ][ 1 ] = ( rL - 0.5 ) / ( rW + rL + 0.5 );

    /* beaver point */

    aaarPoints[ i ][ 1 ][ 0 ] = rL / ( rW + rL );
    aaarPoints[ i ][ 1 ][ 1 ] = rL / ( rW + rL + 0.5 );

    /* raccoon point */

    aaarPoints[ i ][ 2 ][ 0 ] = rL / ( rW + rL );
    aaarPoints[ i ][ 2 ][ 1 ] = ( rL + 0.5 ) / ( rW + rL + 0.5 );

    /* initial double point */
      
    if ( ! fJacoby ) {
      /* without Jacoby */
      aaarPoints[ i ][ 3 ][ 0 ] = rL / ( rW + rL );
    }
    else {
      /* with Jacoby */
          
      if ( fBeavers )
        /* with beavers */
        aaarPoints[ i ][ 3 ][ 0 ] = ( rL - 0.25 ) / ( rL + rW - 0.5 );
      else
        /* without beavers */
        aaarPoints[ i ][ 3 ][ 0 ] = ( rL - 0.5 ) / ( rL + rW - 1.0 );
        
    }
    aaarPoints[ i ][ 3 ][ 1 ] = ( rL + 1.0 ) / ( rL + rW + 0.5 );

    /* redouble point */
    aaarPoints[ i ][ 4 ][ 0 ] = rL / ( rW + rL );
    aaarPoints[ i ][ 4 ][ 1 ] = ( rL + 1.0 ) / ( rL + rW + 0.5 );

    /* cash point */

    aaarPoints[ i ][ 5 ][ 0 ] = ( rL + 0.5 ) / ( rW + rL );
    aaarPoints[ i ][ 5 ][ 1 ] = ( rL + 1.0 ) / ( rW + rL + 0.5 );

    /* too good point */
      
    aaarPoints[ i ][ 6 ][ 0 ] = ( rL + 1.0 ) / ( rW + rL );
    aaarPoints[ i ][ 6 ][ 1 ] = ( rL + 1.0 ) / ( rW + rL + 0.5 );

  }

}


/*
 * Get take, double, take, and too good points for match play.
 *
 * Input:
 *   pci: cubeinfo 
 *   aarRates: gammon and backgammon rates (first index is player)
 *
 * Output:
 *   aaarPoints: the points
 *
 */

extern void
getMatchPoints ( float aaarPoints[ 2 ][ 4 ][ 2 ],
                 int afAutoRedouble[ 2 ],
                 int afDead[ 2 ],
                 cubeinfo *pci,
                 float aarRates[ 2 ][ 2 ] ) {

  float arOutput[ NUM_OUTPUTS ];
  float arDP1[ 2 ], arDP2[ 2 ],arCP1[ 2 ], arCP2[ 2 ], arTG[ 2 ];
  float rDTW, rDTL, rNDW, rNDL, rDP, rRisk, rGain;

  int i, anNormScore[ 2 ];

  for ( i = 0; i < 2; i++ )
    anNormScore[ i ] = pci->nMatchTo - pci->anScore[ i ];

  /* get cash points */

  arOutput[ 0 ] = 0.5;
  arOutput[ 1 ] = 0.5 * ( aarRates[ 0 ][ 0 ] + aarRates[ 0 ][ 1 ] );
  arOutput[ 2 ] = 0.5 * aarRates[ 0 ][ 1 ];
  arOutput[ 3 ] = 0.5 * ( aarRates[ 1 ][ 0 ] + aarRates[ 1 ][ 1 ] );
  arOutput[ 4 ] = 0.5 * aarRates[ 1 ][ 1 ];

  GetPoints ( arOutput, pci, arCP2 );

  for ( i = 0; i < 2; i++ ) {

    afAutoRedouble [ i ] =
      ( anNormScore[ i ] - 2 * pci->nCube <= 0 ) &&
      ( anNormScore[ ! i ] - 2 * pci->nCube > 0 );
    
    afDead[ i ] =
      ( anNormScore[ ! i ] - 2 * pci->nCube <=0 );

      /* MWC for "double, take; win" */

    rDTW =
      (1.0 - aarRates[ i ][ 0 ] - aarRates[ i ][ 1 ]) *
      getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo, i,
              2 * pci->nCube, i, pci->fCrawford,
              aafMET, aafMETPostCrawford )
      + aarRates[ i ][ 0 ] * 
      getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo, i,
              4 * pci->nCube, i, pci->fCrawford, 
              aafMET, aafMETPostCrawford )
      + aarRates[ i ][ 1 ] * 
      getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo, i,
              6 * pci->nCube, i, pci->fCrawford, 
              aafMET, aafMETPostCrawford );

    /* MWC for "no double, take; win" */

    rNDW =
      (1.0 - aarRates[ i ][ 0 ] - aarRates[ i ][ 1 ]) *
      getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo, i,
              pci->nCube, i, pci->fCrawford,
              aafMET, aafMETPostCrawford )
      + aarRates[ i ][ 0 ] * 
      getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo, i,
              2 * pci->nCube, i, pci->fCrawford, 
              aafMET, aafMETPostCrawford )
      + aarRates[ i ][ 1 ] * 
      getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo, i,
              3 * pci->nCube, i, pci->fCrawford, 
              aafMET, aafMETPostCrawford );

    /* MWC for "Double, take; lose" */

    rDTL =
      (1.0 - aarRates[ ! i ][ 0 ] - aarRates[ ! i ][ 1 ]) *
      getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo, i,
              2 * pci->nCube, ! i, pci->fCrawford,
              aafMET, aafMETPostCrawford )
      + aarRates[ ! i ][ 0 ] * 
      getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo, i,
              4 * pci->nCube, ! i, pci->fCrawford, 
              aafMET, aafMETPostCrawford )
      + aarRates[ ! i ][ 1 ] * 
      getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo, i,
              6 * pci->nCube, ! i, pci->fCrawford, 
              aafMET, aafMETPostCrawford );

    /* MWC for "No double; lose" */

    rNDL =
      (1.0 - aarRates[ ! i ][ 0 ] - aarRates[ ! i ][ 1 ]) *
      getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo, i,
              1 * pci->nCube, ! i, pci->fCrawford,
              aafMET, aafMETPostCrawford )
      + aarRates[ ! i ][ 0 ] * 
      getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo, i,
              2 * pci->nCube, ! i, pci->fCrawford, 
              aafMET, aafMETPostCrawford )
      + aarRates[ ! i ][ 1 ] * 
      getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo, i,
              3 * pci->nCube, ! i, pci->fCrawford, 
              aafMET, aafMETPostCrawford );

    /* MWC for "Double, pass" */

    rDP = 
      getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo, i,
              pci->nCube, i, pci->fCrawford,
              aafMET, aafMETPostCrawford );

    /* Double point */

    rRisk = rNDL - rDTL;
    rGain = rDTW - rNDW;

    arDP1 [ i ] = rRisk / ( rRisk + rGain );
    arDP2 [ i ] = arDP1 [ i ];

    /* Dead cube take point without redouble */

    rRisk = rDTW - rDP;
    rGain = rDP - rDTL;

    arCP1 [ i ] = 1.0 - rRisk / ( rRisk + rGain );

    /* find too good point */

    rRisk = rNDW - rNDL;
    rGain = rNDW - rDP;

    arTG[ i ] = rRisk / ( rRisk + rGain );

    if ( afAutoRedouble[ i ] ) {

      /* With redouble */

      rDTW =
        (1.0 - aarRates[ i ][ 0 ] - aarRates[ i ][ 1 ]) *
        getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo, i,
                4 * pci->nCube, i, pci->fCrawford,
                aafMET, aafMETPostCrawford )
        + aarRates[ i ][ 0 ] * 
        getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo, i,
                8 * pci->nCube, i, pci->fCrawford,
                aafMET, aafMETPostCrawford )
        + aarRates[ i ][ 1 ] * 
        getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo, i,
                12 * pci->nCube, i, pci->fCrawford,
                aafMET, aafMETPostCrawford );

      rDTL =
        (1.0 - aarRates[ ! i ][ 0 ] - aarRates[ ! i ][ 1 ]) *
        getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo, i,
                4 * pci->nCube, ! i, pci->fCrawford,
                aafMET, aafMETPostCrawford )
        + aarRates[ ! i ][ 0 ] * 
        getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo, i,
                8 * pci->nCube, ! i, pci->fCrawford,
                aafMET, aafMETPostCrawford )
        + aarRates[ ! i ][ 1 ] * 
        getME ( pci->anScore[ 0 ], pci->anScore[ 1 ], pci->nMatchTo, i,
                12 * pci->nCube, ! i, pci->fCrawford,
                aafMET, aafMETPostCrawford );

      rRisk = rDTW - rDP;
      rGain = rDP - rDTL;
        
      arCP2 [ i ] = 1.0 - rRisk / ( rRisk + rGain );

      /* Double point */

      rRisk = rNDL - rDTL;
      rGain = rDTW - rNDW;
      
      arDP2 [ i ] = rRisk / ( rRisk + rGain );

    }

  }

  /* save points */

  for ( i = 0; i < 2; i++ ) {

    /* take point */

    aaarPoints[ i ][ 0 ][ 0 ] = 1.0f - arCP1[ ! i ];
    aaarPoints[ i ][ 0 ][ 1 ] = 1.0f - arCP2[ ! i ];

    /* double point */

    aaarPoints[ i ][ 1 ][ 0 ] = arDP1[ i ];
    aaarPoints[ i ][ 1 ][ 1 ] = arDP2[ i ];

    /* cash point */

    aaarPoints[ i ][ 2 ][ 0 ] = arCP1[ i ];
    aaarPoints[ i ][ 2 ][ 1 ] = arCP2[ i ];

    /* too good point */

    aaarPoints[ i ][ 3 ][ 0 ] = arTG[ i ];

    if ( ! afDead[ i ] )
      aaarPoints[ i ][ 3 ][ 1 ] = arCP2[ i ];

  }

}

extern void
getCubeDecisionOrdering ( int aiOrder[ 3 ],
                          float arDouble[ 4 ], 
                          float aarOutput[ 2 ][ NUM_ROLLOUT_OUTPUTS ],
                          const cubeinfo* pci ) {

  cubedecision cd;

  /* Get cube decision */

  cd = FindBestCubeDecision ( arDouble, aarOutput, pci );

  switch ( cd ) {

  case DOUBLE_TAKE:
  case DOUBLE_BEAVER:
  case REDOUBLE_TAKE:

    /*
     * Optimal     : Double, take
     * Best for me : Double, pass
     * Worst for me: No Double 
     */

    aiOrder[ 0 ] = OUTPUT_TAKE;
    aiOrder[ 1 ] = OUTPUT_DROP;
    aiOrder[ 2 ] = OUTPUT_NODOUBLE;

    break;

  case DOUBLE_PASS:
  case REDOUBLE_PASS:

    /*
     * Optimal     : Double, pass
     * Best for me : Double, take
     * Worst for me: no double 
     */
    aiOrder[ 0 ] = OUTPUT_DROP;
    aiOrder[ 1 ] = OUTPUT_TAKE;
    aiOrder[ 2 ] = OUTPUT_NODOUBLE;

    break;

  case NODOUBLE_TAKE:
  case NODOUBLE_BEAVER:
  case TOOGOOD_TAKE:
  case NO_REDOUBLE_TAKE:
  case NO_REDOUBLE_BEAVER:
  case TOOGOODRE_TAKE:
  case NODOUBLE_DEADCUBE:
  case NO_REDOUBLE_DEADCUBE:
  case OPTIONAL_DOUBLE_BEAVER:
  case OPTIONAL_DOUBLE_TAKE:
  case OPTIONAL_REDOUBLE_TAKE:

    /*
     * Optimal     : no double
     * Best for me : double, pass
     * Worst for me: double, take
     */

    aiOrder[ 0 ] = OUTPUT_NODOUBLE;
    aiOrder[ 1 ] = OUTPUT_DROP;
    aiOrder[ 2 ] = OUTPUT_TAKE;

    break;

  case TOOGOOD_PASS:
  case TOOGOODRE_PASS:
  case OPTIONAL_DOUBLE_PASS:
  case OPTIONAL_REDOUBLE_PASS:

    /*
     * Optimal     : no double
     * Best for me : double, take
     * Worst for me: double, pass
     */

    aiOrder[ 0 ] = OUTPUT_NODOUBLE;
    aiOrder[ 1 ] = OUTPUT_TAKE;
    aiOrder[ 2 ] = OUTPUT_DROP;

    break;

  default:

    g_assert ( FALSE );

    break;

  }

}



extern float
getPercent ( const cubedecision cd,
             const float arDouble[] ) {

  switch ( cd ) {

  case DOUBLE_TAKE:
  case DOUBLE_BEAVER:
  case DOUBLE_PASS:
  case REDOUBLE_TAKE:
  case REDOUBLE_PASS:
  case NODOUBLE_DEADCUBE:
  case NO_REDOUBLE_DEADCUBE:
  case OPTIONAL_DOUBLE_BEAVER:
  case OPTIONAL_DOUBLE_TAKE:
  case OPTIONAL_REDOUBLE_TAKE:
  case OPTIONAL_DOUBLE_PASS:
  case OPTIONAL_REDOUBLE_PASS:
    /* correct cube action */
    return -1.0;
    break;

  case TOOGOODRE_TAKE:
  case TOOGOOD_TAKE:
    /* never correct to double */
    return -1.0;
    break;

  case NODOUBLE_TAKE:
  case NODOUBLE_BEAVER:
  case NO_REDOUBLE_TAKE:
  case NO_REDOUBLE_BEAVER:

    /* how many doubles should be dropped before it is correct to double */

    return 
      ( arDouble[ OUTPUT_NODOUBLE ] - arDouble[ OUTPUT_TAKE ] ) /
      (arDouble[ OUTPUT_DROP ] - arDouble[ OUTPUT_TAKE ] );
    break;

  case TOOGOOD_PASS:
  case TOOGOODRE_PASS:

    /* how many doubles should be taken before it is correct to double */
    if ( arDouble[ OUTPUT_NODOUBLE ] > arDouble[ OUTPUT_TAKE ] ) 
      /* strange match play scenario 
         (see 3-ply eval on cAmgACAAGAAA/4HPkAUgzW8EBMA):
         never correct to double! */
      return -1.0;
    else
      return 
        ( arDouble[ OUTPUT_NODOUBLE ] - arDouble[ OUTPUT_DROP ] ) /
        (arDouble[ OUTPUT_TAKE ] - arDouble[ OUTPUT_DROP ] );

    break;

  default:

    g_assert ( FALSE );

  }

  return -1.0;
}


/*
 * Resort movelist and recalculate best score.
 *
 * Input:
 *   pml: movelist
 *
 * Output:
 *   pml: update movelist
 *   ai : the new ordering. Caller must allocate ai.
 *
 * FIXME: the construction of the ai-array is *very* ugly.
 *        We should probably write a substitute for qsort that
 *        updates ai on the fly.
 *
 */

extern void
RefreshMoveList ( movelist *pml, int *ai ) {

  int i, j;
  movelist ml;

  if ( ! pml->cMoves )
    return;

  if ( ai )
    CopyMoveList ( &ml, pml );

  qsort( pml->amMoves, pml->cMoves, 
         sizeof( move ), (cfunc) CompareMovesGeneral );

  pml->rBestScore = pml->amMoves[ 0 ].rScore;

  if ( ai ) {
    for ( i = 0; i < pml->cMoves; i++ ) {

      for ( j = 0; j < pml->cMoves; j++ ) {

        if ( ! memcmp ( ml.amMoves[ j ].anMove, pml->amMoves[ i ].anMove,
                        8 * sizeof ( int ) ) )
          ai[ j ] = i;
        
      }
    }

    free ( ml.amMoves );

  }


}


extern void
CopyMoveList ( movelist *pmlDest, const movelist *pmlSrc ) {

  if ( pmlDest == pmlSrc )
    return;

  pmlDest->cMoves = pmlSrc->cMoves;
  pmlDest->cMaxMoves = pmlSrc->cMaxMoves;
  pmlDest->cMaxPips = pmlSrc->cMaxPips;
  pmlDest->iMoveBest = pmlSrc->iMoveBest;
  pmlDest->rBestScore = pmlSrc->rBestScore;

  if ( pmlSrc->cMoves ) {
    pmlDest->amMoves = (move *) malloc ( pmlSrc->cMoves * sizeof ( move ) );
    memcpy ( pmlDest->amMoves, pmlSrc->amMoves,
             pmlSrc->cMoves * sizeof ( move ) );
  }
  else
    pmlDest->amMoves = NULL;

}



/*
 * is this a close cubedecision?
 *
 * Input:
 *   arDouble: equities for cube decisions
 *
 */

extern int
isCloseCubedecision ( const float arDouble[] ) {
  const float rThr = 0.16f;
  float rDouble;
  rDouble = MIN(arDouble[ OUTPUT_TAKE ] , 1.0f);

  /* Report if doubling is less than very bad (0.16) */
  if ( arDouble[ OUTPUT_OPTIMAL ] - rDouble < rThr ) return 1;

  return 0;

}


/*
 * is this a missed double?
 *
 * Input:
 *   arDouble: equities for cube decisions
 *   fDouble: did the player double
 *   pci: cubeinfo
 *
 */

extern int
isMissedDouble ( float arDouble[], 
                 float aarOutput[ 2 ][ NUM_ROLLOUT_OUTPUTS ], 
                 const int fDouble, 
                 const cubeinfo *pci ) {

  cubedecision cd = FindBestCubeDecision ( arDouble, aarOutput, pci );

  switch ( cd ) {
    
  case DOUBLE_TAKE:
  case DOUBLE_PASS:
  case DOUBLE_BEAVER:
  case REDOUBLE_TAKE:
  case REDOUBLE_PASS:

    return ! fDouble;
    break;

  default:

    return 0;
    break;


  }

}
                 


extern unsigned int
locateMove ( int anBoard[ 2 ][ 25 ], 
             const int anMove[ 8 ], const movelist *pml ) {

  unsigned int i;
  unsigned char auch[ 10 ];
  unsigned char key[ 10 ];

  MoveKey ( anBoard, anMove, key );

  for ( i = 0; i < pml->cMoves; ++i ) {

    MoveKey ( anBoard, pml->amMoves[ i ].anMove, auch );

    if ( EqualKeys ( auch, key ) )
      return i;


  }

  return 0;

}


extern int
MoveKey ( int anBoard[ 2 ][ 25 ], const int anMove[ 8 ], 
          unsigned char auch[ 10 ] ) {

  int anBoardMove[ 2 ][ 25 ];

  memcpy ( anBoardMove, anBoard, sizeof ( anBoardMove ) );
  ApplyMove ( anBoardMove, anMove, FALSE );
  PositionKey ( anBoardMove, auch );

  return 0;

}


extern int
equal_movefilter ( const int i, 
                   movefilter amf1[ MAX_FILTER_PLIES ],
                   movefilter amf2[ MAX_FILTER_PLIES ] ) {

  int j;

  for ( j = 0; j <= i; ++j ) {
    if ( amf1[ j ].Accept != amf2[ j ].Accept )
      return 0;
    if ( amf1[ j ].Accept < 0 )
      continue;
    if ( amf1[ j ].Extra != amf2[ j ].Extra )
      return 0;
    if ( ! amf1[ j ].Extra )
      continue;
    if ( amf1[ j ].Threshold != amf2[ j ].Threshold )
      return 0;
    
  }

  return 1;

}


extern int
equal_movefilters ( movefilter aamf1[ MAX_FILTER_PLIES ][ MAX_FILTER_PLIES ],
                    movefilter aamf2[ MAX_FILTER_PLIES ][ MAX_FILTER_PLIES ] ) {

  int i;

  for ( i = 0; i < MAX_FILTER_PLIES; ++i )
    if ( ! equal_movefilter ( i, aamf1[ i ], aamf2[ i ] ) )
      return 0;
      
  return 1;

}


/*
 * Categorise double into normal, beaver, or raccoon.
 * 
 * The function is called before ApplyMoveRecord:
 *
 * fDoubled = FALSE:
 *
 *    the previous moverecord was not a MOVE_DOUBLE,
 *    hence this is a normal double.
 *
 * fDoubled = TRUE:
 *
 *    The previous moverecord was a MOVE_DOUBLE
 *    so it's either a beaver or a raccoon
 *
 *    Beaver: fTurn != fMove (the previous doubler was the player on roll
 *                            so the redouble must be a beaver)
 *    Raccoon: fTurn == fMove and/or fCubeOwner != fMove
 *
 *
 */

extern doubletype
DoubleType ( const int fDoubled, const int fMove, const int fTurn ) {

  if ( fDoubled ) {

    /* beaver or raccoon */

    if(  fTurn != fMove )
      /* beaver */
      return DT_BEAVER;
    else
      /* raccoon */
      return DT_RACCOON;

  }
  else 
    /* normal double */
    return DT_NORMAL;

  /* code unreachable */
  return DT_NORMAL;

}

