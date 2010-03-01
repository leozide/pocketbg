//
//  RootViewController.m
//  bg
//
//  Created by Leo on 6/18/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "RootViewController.h"
#import "SettingsViewController.h"
#import "HelpViewController.h"
#import "bgViewController.h"
#import "bgView.h"

#include "config.h"
//#include "gnubg-types.h"
#include "eval.h"
#include "backgammon.h"
#include "sound.h"
#include "drawboard.h"
#include "bgBoardData.h"
#include "bgBoard.h"

extern void UserCommand(char* szCommand);
extern int fGUIDragTargetHelp;

evalcontext ecSettings[] =
{
	{ TRUE, 0, FALSE, TRUE, 0.060f }, // beginner
	{ TRUE, 0, FALSE, TRUE, 0.040f }, // intermediate
	{ TRUE, 0, FALSE, TRUE, 0.0f }, // expert
	{ TRUE, 2, TRUE, TRUE, 0.0f }, // world class
	{ TRUE, 3, TRUE, TRUE, 0.0f }, // grand master
};

int iSettingsMoveFilter[] =
{
	-1, // beginner: n/a
	-1, // intermediate: n/a
	-1, // expoert: n/a
	2,  // wc: normal
	2,  // grandmaster: normal
};

@implementation RootViewController

@synthesize mainViewController;
@synthesize settingsViewController;
@synthesize helpViewController;
@synthesize settingsNavigationBar;
@synthesize helpNavigationBar;

- (void)viewDidLoad
{
	[super viewDidLoad];

	bgViewController* viewController = [[bgViewController alloc] initWithNibName:@"bgViewController" bundle:nil];
	self.mainViewController = viewController;
	[viewController release];

	[self.view addSubview:mainViewController.view];
}

- (void) SaveMatch
{
	NSArray* Paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString* DocDir = [Paths objectAtIndex:0];

	outputoff();

	char buf[1024];
	sprintf(buf, "save match \"%s/autosave.sgf\"", [DocDir cStringUsingEncoding:NSUTF8StringEncoding]);
	UserCommand(buf);

	outputon();
}

- (IBAction)cancel
{
	[self ShowMainView];
}

static void SetEvalCommands( char *szPrefix, evalcontext *pec, evalcontext *pecOrig )
{
	char sz[ 256 ];

	if ( pec->nPlies != pecOrig->nPlies )
	{
		sprintf( sz, "%s plies %d", szPrefix, pec->nPlies );
		UserCommand( sz );
	}

	if ( pec->fUsePrune != pecOrig->fUsePrune )
	{
		sprintf( sz, "%s prune %s", szPrefix, pec->fUsePrune ? "on" : "off" );
		UserCommand( sz );
	}

	if ( pec->fCubeful != pecOrig->fCubeful )
	{
		sprintf( sz, "%s cubeful %s", szPrefix, pec->fCubeful ? "on" : "off" );
		UserCommand( sz );
	}

	if ( pec->rNoise != pecOrig->rNoise )
	{
		sprintf( sz, "%s noise %.3f", szPrefix, pec->rNoise );
		UserCommand( sz );
	}

	if ( pec->fDeterministic != pecOrig->fDeterministic )
	{
		sprintf( sz, "%s deterministic %s", szPrefix, pec->fDeterministic ? "on" : "off" );
		UserCommand( sz );
	}
}

static void SetMovefilterCommands ( const char *sz, movefilter aamfNew[ MAX_FILTER_PLIES ][ MAX_FILTER_PLIES ], movefilter aamfOld[ MAX_FILTER_PLIES ][ MAX_FILTER_PLIES ] )
{
	int i, j;
	char szCmd[256];
	
	for ( i = 0; i < MAX_FILTER_PLIES; ++i )
		for ( j = 0; j <= i; ++j )
		{
			if ( aamfNew[ i ][ j ].Accept != aamfOld[ i ][ j ].Accept ||
				aamfNew[ i ][ j ].Extra != aamfOld[ i ][ j ].Extra ||
				aamfNew[ i ][ j ].Threshold != aamfOld[ i ][ j ].Threshold )
			{
				sprintf(szCmd, "%s %d %d %d %d %0.3f",
										 sz, i + 1, j,
										 aamfNew[ i ][ j ].Accept,
										 aamfNew[ i ][ j ].Extra,
										 aamfNew[ i ][ j ].Threshold );
				UserCommand ( szCmd );
			}
		}
}

- (IBAction)save
{
	bgSettings* settings = &self.settingsViewController->settings;
	char buf[1024];
	
	// Check if all settings are valid.
	if (settings->Player1Color == settings->Player2Color)
	{
		UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Duplicate Colors" message:@"Both players are using the same checker colors. Please select different colors for the players." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		[alertView show];
		[alertView release];
		return;
	}
	
	if (settings->Player1Type != 0 && settings->Player2Type != 0)
	{
		UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"No Human Players" message:@"Both players are AI players. Please select at least one human player." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		[alertView show];
		[alertView release];
		return;
	}

	for (int i = 0; i < 4; i++)
		Player1Color[i] = gCheckerColors[settings->Player1Color].Value[i];
	
	for (int i = 0; i < 4; i++)
		Player2Color[i] = gCheckerColors[settings->Player2Color].Value[i];
	
	// Reload view if it was deleted.
	UIView *mainView = mainViewController.view;
	mainView;
	
	outputoff();

	// Trying to swap names - change current name to avoid error.
	if (!CompareNames(settings->Player1, ap[1].szName) && CompareNames(settings->Player1, settings->Player2))
		sprintf(ap[1].szName, "_%s", settings->Player1);

	if (strcmp(ap[0].szName, settings->Player1))
	{
		sprintf(buf, "set player 0 name %s", settings->Player1);
		UserCommand(buf);
	}

	if (strcmp(ap[1].szName, settings->Player2))
	{
		sprintf(buf, "set player 1 name %s", settings->Player2);
		UserCommand(buf);
	}

	for (int i = 0; i < 2; i++)
	{
		int Difficulty = (i == 0) ? settings->Player1Type : settings->Player2Type;

		if (Difficulty == 0)
		{
			sprintf(buf, "set player %d human", i);
			UserCommand(buf);
			continue;
		}

		sprintf(buf, "set player %d gnubg", i);
		UserCommand(buf);

		evalcontext* ec = &ecSettings[Difficulty-1];

		sprintf(buf, "set player %d chequer evaluation", i);
		SetEvalCommands(buf, ec, &ap[i].esChequer.ec);
		sprintf(buf, "set player %d cube evaluation", i);
		SetEvalCommands(buf, ec, &ap[i].esChequer.ec);

		if (iSettingsMoveFilter[Difficulty-1] < 0)
			continue;

		movefilter mf[MAX_FILTER_PLIES][MAX_FILTER_PLIES];
		memcpy(&mf, aaamfMoveFilterSettings[iSettingsMoveFilter[Difficulty-1]], sizeof(mf));
		sprintf(buf, "set player %d movefilter", i);
		SetMovefilterCommands(buf, mf, ap[i].aamf);
	}

	if (settings->MatchLength != nDefaultLength)
	{
		sprintf(buf, "set matchlength %d", settings->MatchLength);
		UserCommand(buf);
	}

	if (settings->Cube != fCubeUse)
	{
		sprintf(buf, "set cube use %s", settings->Cube ? "on" : "off");
		UserCommand(buf);
	}

	if (settings->Jacoby != fJacoby)
	{
		sprintf(buf, "set jacoby %s", settings->Jacoby ? "on" : "off");
		UserCommand(buf);
	}

	if (settings->Crawford != fAutoCrawford)
	{
		sprintf(buf, "set auto crawford %s", settings->Crawford ? "on" : "off");
		UserCommand(buf);
	}

	if (settings->Sounds != fSound)
	{
		sprintf(buf, "set sound enable %s", settings->Sounds ? "on" : "off");
		UserCommand(buf);
	}

	if (settings->TargetHelp != fGUIDragTargetHelp)
	{
		sprintf(buf, "set gui dragtargethelp %s", settings->TargetHelp ? "on" : "off");
		UserCommand(buf);
	}

	if (settings->Clockwise != fClockwise)
	{
		sprintf(buf, "set clockwise %s", settings->Clockwise ? "on" : "off");
		UserCommand(buf);
	}

	extern int fAdvancedHint;
	if (settings->AdvancedHint != fAdvancedHint)
	{
		sprintf(buf, "set advancedhint %s", settings->AdvancedHint ? "on" : "off");
		UserCommand(buf);
	}
	
	NSArray* Paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString* DocDir = [Paths objectAtIndex:0];
	
	sprintf(buf, "save settings \"%s/bgautorc\"", [DocDir cStringUsingEncoding:NSUTF8StringEncoding]);
	UserCommand(buf);

	outputon();
	ShowBoard();

	[self ShowMainView];
}

-(void) ShowMainView
{
	UIView *mainView = mainViewController.view;
	UIView *settingsView = settingsViewController.view;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:1];
	[UIView setAnimationTransition:([mainView superview] ? UIViewAnimationTransitionFlipFromRight : UIViewAnimationTransitionFlipFromLeft) forView:self.view cache:YES];
	
	[mainViewController viewWillAppear:YES];
	[settingsViewController viewWillDisappear:YES];
	[settingsView removeFromSuperview];
	[settingsNavigationBar removeFromSuperview];
	[self.view addSubview:mainView];
	[settingsViewController viewDidDisappear:YES];
	[mainViewController viewDidAppear:YES];

    [UIView commitAnimations];
}

-(void) ShowSettingsView
{
	if (settingsViewController == nil)
	{
		SettingsViewController *viewController = [[SettingsViewController alloc] initWithNibName:@"SettingsView" bundle:nil];
		viewController.difficultyLevels = [[NSArray alloc] initWithObjects: @"Human", @"AI - Beginner", @"AI - Intermediate", @"AI - Expert", @"AI - World Class", /*@"AI - Grandmaster",*/ nil];
		self.settingsViewController = viewController;
		[viewController release];

		// Set up the navigation bar
		UINavigationBar *navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0.0, 0.0, 320.0, 44.0)];
		self.settingsNavigationBar = navigationBar;
		[navigationBar release];

		UIBarButtonItem *leftItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
		UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(save)];
		UINavigationItem *navigationItem = [[UINavigationItem alloc] initWithTitle:@"Settings"];
		navigationItem.leftBarButtonItem = leftItem;
		navigationItem.rightBarButtonItem = rightItem;
		[settingsNavigationBar pushNavigationItem:navigationItem animated:NO];
		[navigationItem release];
		[leftItem release];
		[rightItem release];
	}

	bgSettings* settings = &self.settingsViewController->settings;
	strcpy(settings->Player1, ap[0].szName);
	strcpy(settings->Player2, ap[1].szName);
	settings->MatchLength = nDefaultLength;

	for (int i = 0; i < gNumCheckerColors; i++)
		if (Player1Color[0] == gCheckerColors[i].Value[0] && Player1Color[1] == gCheckerColors[i].Value[1] && Player1Color[2] == gCheckerColors[i].Value[2])
		{
			settings->Player1Color = i;
			break;
		}
	
	for (int i = 0; i < gNumCheckerColors; i++)
		if (Player2Color[0] == gCheckerColors[i].Value[0] && Player2Color[1] == gCheckerColors[i].Value[1] && Player2Color[2] == gCheckerColors[i].Value[2])
		{
			settings->Player2Color = i;
			break;
		}
	
	for (int i = 0; i < 2; i++)
	{
		int Type = 0;

		if (ap[i].pt == PLAYER_HUMAN)
		{
			Type = 0;
		}
		else // if (ap[i].pt == PLAYER_GNU)
		{
			float noise = ap[i].esChequer.ec.rNoise;
			if (noise == 0.06f)
				Type = 1;
			else if (noise == 0.04f)
				Type = 2;
			else // if (noise == 0.00)
			{
				int plies = ap[i].esChequer.ec.nPlies;
				if (plies == 0)
					Type = 3;
				else //if (plies == 2)
					Type = 4;
//				else // if (plies == 3)
//					Type = 5;
			}
		}

		if (i == 0)
			settings->Player1Type = Type;
		else
			settings->Player2Type = Type;
	}

	settings->Cube = fCubeUse;
	settings->Jacoby = fJacoby;
	settings->Crawford = fAutoCrawford;
	settings->Sounds = fSound;
	settings->TargetHelp = fGUIDragTargetHelp;
	settings->Clockwise = fClockwise;
	settings->AdvancedHint = fAdvancedHint;

	UIView *mainView = mainViewController.view;
	UIView *settingsView = settingsViewController.view;

	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:1];
	[UIView setAnimationTransition:([mainView superview] ? UIViewAnimationTransitionFlipFromRight : UIViewAnimationTransitionFlipFromLeft) forView:self.view cache:YES];

	[settingsViewController viewWillAppear:YES];
	[mainViewController viewWillDisappear:YES];
	[mainView removeFromSuperview];
	[self.view addSubview:settingsView];
	[self.view insertSubview:settingsNavigationBar aboveSubview:settingsView];
	[mainViewController viewDidDisappear:YES];
	[settingsViewController viewDidAppear:YES];

    [UIView commitAnimations];
}

-(void) ShowHelpView
{
	if (helpViewController == nil)
	{
		HelpViewController *viewController = [[HelpViewController alloc] initWithNibName:@"HelpView" bundle:nil];
		self.helpViewController = viewController;
		[viewController release];
		
		// Set up the navigation bar
		UINavigationBar *navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0.0, 0.0, 320.0, 44.0)];
		self.helpNavigationBar = navigationBar;
		[navigationBar release];
		
		UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(cancel)];
		UINavigationItem *navigationItem = [[UINavigationItem alloc] initWithTitle:@"How to Play"];
		navigationItem.rightBarButtonItem = rightItem;
		[helpNavigationBar pushNavigationItem:navigationItem animated:NO];
		[navigationItem release];
		[rightItem release];
	}

	UIView *mainView = mainViewController.view;
	UIView *helpView = helpViewController.view;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:1];
	[UIView setAnimationTransition:([mainView superview] ? UIViewAnimationTransitionFlipFromRight : UIViewAnimationTransitionFlipFromLeft) forView:self.view cache:YES];
	
	[helpViewController viewWillAppear:YES];
	[mainViewController viewWillDisappear:YES];
	[mainView removeFromSuperview];
	[self.view addSubview:helpView];
	[self.view insertSubview:helpNavigationBar aboveSubview:helpView];
	[mainViewController viewDidDisappear:YES];
	[helpViewController viewDidAppear:YES];
	
    [UIView commitAnimations];
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	// Return YES for supported orientations
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
	// Release anything that's not essential, such as cached data
}

- (void)dealloc
{
	[settingsNavigationBar release];
	[mainViewController release];
	[settingsViewController release];
	[helpNavigationBar release];
	[helpViewController release];
	[super dealloc];
}

@end
