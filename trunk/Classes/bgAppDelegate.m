#import "bgAppDelegate.h"
#include "config.h"
#include "backgammon.h"

@implementation bgAppDelegate

@synthesize window = _window;

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

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	[self SaveMatch];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	[self SaveMatch];
}

@end
