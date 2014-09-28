//
//  bgAppDelegate.m
//  bg
//
//  Created by Leo on 5/8/09.
//  Copyright __MyCompanyName__ 2009. All rights reserved.
//

#import "bgAppDelegate.h"
#import "RootViewController.h"

@implementation bgAppDelegate

@synthesize window = _window;

@end
/*
@implementation bgAppDelegate

@synthesize window;
@synthesize rootViewController;

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
	// Override point for customization after app launch    
	[window addSubview:rootViewController.view];
	[window makeKeyAndVisible];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	[rootViewController SaveMatch];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	[rootViewController SaveMatch];
}

- (void)dealloc
{
	[rootViewController release];
	[window release];
	[super dealloc];
}

@end
*/