/*
 * sound.c from GAIM.
 *
 * Copyright (C) 1998-1999, Mark Spencer <markster@marko.net>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
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
 * File modified by Joern Thyssen <jthyssen@dk.ibm.com> for use with
 * GNU Backgammon.
 *
 * $Id: sound.c,v 1.60 2007/06/11 19:01:12 c_anthon Exp $
 */

#import <AudioToolbox/AudioServices.h>
#include "config.h"

#include "backgammon.h"
#include <glib.h>
#include <string.h>
#include <stdlib.h>

#include "sound.h"

SystemSoundID bgSoundID[NUM_SOUNDS];

char *sound_description[ NUM_SOUNDS ] = {
  N_("Starting GNU Backgammon"),
  N_("Agree"),
  N_("Doubling"),
  N_("Drop"),
  N_("Chequer movement"),
  N_("Move"),
  N_("Redouble"),
  N_("Resign"),
  N_("Roll"),
  N_("Take"),
  N_("Human fans"),
  N_("Human wins game"),
  N_("Human wins match"),
  N_("Bot fans"),
  N_("Bot wins game"),
  N_("Bot wins match"),
  N_("Analysis is finished")
};

char *sound_command[ NUM_SOUNDS ] = {
  "start",
  "agree",
  "double",
  "drop",
  "chequer",
  "move",
  "redouble",
  "resign",
  "roll",
  "take",
  "humanfans",
  "humanwinsgame",
  "humanwinsmatch",
  "botfans",
  "botwinsgame",
  "botwinsmatch",
  "analysisfinished"
};

int fSound = TRUE;
static char *sound_cmd = NULL;

extern void playSound ( const gnubgsound gs )
{
	/* no sounds for this user */
	if ( ! fSound )
		return;

	if (!bgSoundID[gs])
	{
		char* FilePath = GetDefaultSoundFile(gs);
		CFURLRef FileURL = CFURLCreateFromFileSystemRepresentation(NULL, (UInt8*)FilePath, strlen(FilePath), false);
		g_free(FilePath);

		SystemSoundID SoundID;
		OSStatus error = AudioServicesCreateSystemSoundID((CFURLRef)FileURL, &SoundID);
		CFRelease(FileURL);

		if (error == kAudioServicesNoError)
			bgSoundID[gs] = SoundID;
	}

	if (bgSoundID[gs])
		AudioServicesPlaySystemSound(bgSoundID[gs]);
}


extern void SoundWait( void ) {

    if (!fSound)
        return;
#ifdef WIN32
    	/* Wait 1/10 of a second to make sure sound has started */
    	Sleep(100);
      while (!PlaySound(NULL, NULL, SND_FILENAME | SND_ASYNC | SND_NOSTOP | SND_NODEFAULT))
        Sleep(1);	/* Wait (1ms) for previous sound to finish */
      return;
#endif
}

char *sound_file[ NUM_SOUNDS ] = {0};

extern char *GetDefaultSoundFile(int sound)
{
  static char aszDefaultSound[ NUM_SOUNDS ][ 80 ] = {
  /* start and exit */
  "fanfare.wav",
  /* commands */
  "drop.wav",
  "double.wav",
  "drop.wav",
  "chequer.wav",
  "move.wav",
  "double.wav",
  "resign.wav",
  "roll.wav",
  "take.wav",
  /* events */
  "dance.wav",
  "gameover.wav",
  "matchover.wav",
  "dance.wav",
  "gameover.wav",
  "matchover.wav",
  "fanfare.wav"
  };

	return g_build_filename(PKGDATADIR, aszDefaultSound[sound], NULL);
}

extern char *GetSoundFile(gnubgsound sound)
{
	if (!sound_file[sound])
		return GetDefaultSoundFile(sound);
	if (!(*sound_file[sound]))
		return g_strdup("");
	if (g_path_is_absolute(sound_file[sound]))
		return g_strdup(sound_file[sound]);

	return g_build_filename(PKGDATADIR, sound_file[sound], NULL);
}

extern void SetSoundFile(gnubgsound sound, const char *file)
{
	char *old_file = GetSoundFile(sound);
	const char *new_file = file ? file : "";
	if (!strcmp(new_file, old_file))
	{
		g_free(old_file);
		return;		/* No change */
	}
	g_free(old_file);

	if (!*new_file) {
		outputf(_("No sound played for: %s\n"),
			gettext(sound_description[sound]));
	} else {
		outputf(_("Sound for: %s: %s\n"),
			gettext(sound_description[sound]),
			new_file);
	}
	g_free(sound_file[sound]);
	sound_file[sound] = g_strdup(new_file);
}

extern char *sound_get_command(void)
{
	return (sound_cmd ? sound_cmd : "");
}

extern char *sound_set_command(const char *sz)
{
	g_free(sound_cmd);
	sound_cmd = g_strdup(sz ? sz : "");
	return sound_cmd;
};

