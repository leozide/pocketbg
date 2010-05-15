//
//  bgViewController.m
//  bg
//
//  Created by Leo on 5/8/09.
//  Copyright __MyCompanyName__ 2009. All rights reserved.
//

#import "bgViewController.h"

@implementation bgViewController

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];

#ifndef PBG_HD
	[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRotate:) name:UIDeviceOrientationDidChangeNotification object:nil];
#endif
}

- (void)didRotate:(NSNotification*)notification
{
	UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
	CGAffineTransform transform;
	if (orientation == UIDeviceOrientationLandscapeLeft)
		transform = CGAffineTransformMakeRotation(M_PI/2);
	else if (orientation == UIDeviceOrientationLandscapeRight)
		transform = CGAffineTransformMakeRotation(-M_PI/2);
	else
		return;
	self.view.transform = transform;
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
#ifdef PBG_HD
	return YES;
#else
    return (interfaceOrientation == UIInterfaceOrientationLandscapeRight);
#endif
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
}


- (void)dealloc
{
    [super dealloc];
}

@end
