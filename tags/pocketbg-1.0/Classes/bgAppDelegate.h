//
//  bgAppDelegate.h
//  bg
//
//  Created by Leo on 5/8/09.
//  Copyright __MyCompanyName__ 2009. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RootViewController;

@interface bgAppDelegate : NSObject <UIApplicationDelegate>
{
	UIWindow *window;
	RootViewController *rootViewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet RootViewController *rootViewController;

@end

