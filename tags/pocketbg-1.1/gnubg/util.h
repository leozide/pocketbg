/*
 * util.h
 *
 * by Christian Anthon 2007
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
 * $Id: util.h,v 1.1 2007/05/14 10:23:43 c_anthon Exp $
 */

#ifndef _UTIL_H_
#define _UTIL_H_

#include "stdio.h"

#define BuildFilename(file) g_build_filename(PKGDATADIR, file, NULL)
#define BuildFilename2(file1, file2) g_build_filename(PKGDATADIR, file1, file2, NULL)

extern int MT_GetThreadID();
extern void MT_Unlock(long *lock);
extern void MT_Lock(long *lock);
extern char * getInstallDir( void );

#endif