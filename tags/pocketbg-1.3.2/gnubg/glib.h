#ifndef _GLIB_H_
#define _GLIB_H_

#include <assert.h>
#include <time.h>
#include <string.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <alloca.h>
#include <unistd.h>
#include <ctype.h>
#include <stdarg.h>

#define gint int
#define gulong unsigned long
#define gsize size_t
#define gchar char
#define G_ASCII_DTOSTR_BUF_SIZE (29+10)

#define G_PI M_PI

#define g_path_is_absolute(a) ((a)[0] == '/')
#define g_get_home_dir() "./"

//#define __need_struct_timeval
//#include <sys/_structs.h>

//struct timeval;
//#define GTimeVal timeval
//gettimeofday
typedef struct
{
	long		tv_sec;		/* seconds */
	long	tv_usec;	/* and microseconds */
} GTimeVal;
#define g_get_current_time(a) gettimeofday((struct timeval*)a, 0)

#define GLogLevelFlags int
#define gpointer void*

#define FALSE 0
#define TRUE 1

#ifndef MIN
#define MIN(a, b)  (((a) < (b)) ? (a) : (b))
#endif

#ifndef MAX
#define MAX(a, b)  (((a) > (b)) ? (a) : (b))
#endif

#define _(a) a
#define N_(a) a

#define g_get_user_name() "Player"

#define g_new(a,b) malloc(b*sizeof(a))
#define g_new0(a,b) calloc(b, sizeof(a))
#define g_malloc malloc
#define g_free free
#define g_alloca alloca
#define g_realloc realloc

#define g_fopen fopen
#define g_rename rename
#define g_unlink unlink

static char* g_ascii_formatd(char* buf, int sz, const char* fmt, float val)
{
	sprintf(buf, fmt, val);
	return buf;
}
#define g_strdup strdup
#define g_ascii_strcasecmp strcasecmp
#define g_ascii_strtod strtod
#define g_print printf
#define g_ascii_strncasecmp strncasecmp
#define g_printerr printf
#define g_ascii_tolower tolower
#define g_ascii_isalnum isalnum
#define g_strtod strtod
#define g_ascii_isdigit isdigit

#define g_getenv getenv
#define g_setenv(a,b,c)
#define g_assert(a)


static gchar *
g_build_path_va (const gchar  *separator,
				 const gchar  *first_element,
				 va_list      *args)
{
	char result[2048];
	size_t separator_len = strlen (separator);
	int is_first = TRUE;
	int have_leading = FALSE;
	const gchar *single_element = NULL;
	const gchar *next_element;
	const gchar *last_trailing = NULL;
	
	result[0] = 0;
	
	next_element = first_element;
	
	while (TRUE)
    {
		const gchar *element;
		const gchar *start;
		const gchar *end;
		
		if (next_element)
		{
			element = next_element;
			next_element = va_arg (*args, gchar *);
		}
		else
			break;
		
		/* Ignore empty elements */
		if (!*element)
			continue;
		
		start = element;
		
		if (separator_len)
		{
			while (start &&
				   strncmp (start, separator, separator_len) == 0)
				start += separator_len;
      	}
		
		end = start + strlen (start);
		
		if (separator_len)
		{
			while (end >= start + separator_len &&
				   strncmp (end - separator_len, separator, separator_len) == 0)
				end -= separator_len;
			
			last_trailing = end;
			while (last_trailing >= element + separator_len &&
				   strncmp (last_trailing - separator_len, separator, separator_len) == 0)
				last_trailing -= separator_len;
			
			if (!have_leading)
			{
				/* If the leading and trailing separator strings are in the
				 * same element and overlap, the result is exactly that element
				 */
				if (last_trailing <= start)
					single_element = element;
				size_t rl = strlen(result);
				memcpy (result+rl, element, start - element);
				result[rl+start-element] = 0;
				have_leading = TRUE;
			}
			else
				single_element = NULL;
		}
		
		if (end == start)
			continue;
		
		if (!is_first)
			strcat (result, separator);
		
		size_t rl = strlen(result);
		memcpy (result+rl, start, end - start);
		result[rl+end-start] = 0;
		is_first = FALSE;
    }
	
	if (single_element)
    {
		return strdup (single_element);
    }
	else
    {
		if (last_trailing)
			strcat(result, last_trailing);
		
		return strdup (result);
    }
}

static gchar *g_build_filename (const gchar *first_element, ...)
{
	gchar *str;
	va_list args;
	
	va_start (args, first_element);
	str = g_build_path_va ("/", first_element, &args);
	va_end (args);
	
	return str;
}

#define ngettext(a,b,c) ((c==1) ? (a) : (b))
#define gettext(a) ((char*)a)

#define BAD_CAST
#define xmlChar char

typedef void (*IdleFunc)();
void* g_idle_add(IdleFunc Func, void* Data);
void g_source_remove(void* i);

extern int fX;
extern void* nNextTurn;
extern void NextTurnNotify();

#endif // _GLIB_H_
