//
//  eddaAppDelegate.m
//  edda
//
//  Created by Mauricio Giraldo on 28/8/14.
//  Copyright (c) 2014 Ping Pong Estudio. All rights reserved.
//

#import "eddaAppDelegate.h"
#import "eddaMainViewController.h"
#import <Parse/Parse.h>

@implementation eddaAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	[UIApplication sharedApplication].idleTimerDisabled = YES;

	NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"configuration" ofType:@"plist"];
	NSDictionary *configuration = [[NSDictionary alloc] initWithContentsOfFile:plistPath];
	
	NSString *testflightId = configuration[@"TestFlight"][@"ApplicationId"];

	[TestFlight takeOff:testflightId];

	// OpenTok initialization
	self.otAPIKey = configuration[@"Opentok"][@"APIKey"];
	self.otProjectSecret = configuration[@"Opentok"][@"ProjectSecret"];

	// Parse initialization
	self.pApplicationID = configuration[@"Parse"][@"ApplicationID"];
	self.pClientKey = configuration[@"Parse"][@"ClientKey"];
	
	self.bFullyLoggedIn = NO;
	
	self.callReceiverTitle = @"";
	self.callReceiverID = @"";
	
	[Parse setApplicationId:self.pApplicationID clientKey:self.pClientKey];
	[PFUser enableAutomaticUser];
	[ParseHelper initData];
	[ParseHelper anonymousLogin];
	[ParseHelper saveCurrentUserToParse];
	
	return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
	// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
	// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
	backgroundTask = [application beginBackgroundTaskWithExpirationHandler:^{
		
		// Clean up any unfinished task business by marking where you
		// stopped or ending the task outright.
		[application endBackgroundTask:backgroundTask];
		backgroundTask = UIBackgroundTaskInvalid;
	}];
 
	// Start the long-running task and return immediately.
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
				   ^{
        // Do the work associated with the task, preferably in chunks.
        [ParseHelper deleteActiveSession];
        [ParseHelper deleteActiveUser];
        [application endBackgroundTask:backgroundTask];
        backgroundTask = UIBackgroundTaskInvalid;
				   });
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
	// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
	self.bFullyLoggedIn = NO;
	[ParseHelper initData];
	[ParseHelper anonymousLogin];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

//this method will be called once logged in. It will poll parse ActiveSessions object
//for incoming calls.
-(void) fireListeningTimer
{
	if (self.appTimer && [self.appTimer isValid])
		return;
	
	self.appTimer = [NSTimer scheduledTimerWithTimeInterval:8.0
													 target:self
												   selector:@selector(onTick:)
												   userInfo:nil
													repeats:YES];
	[ParseHelper setPollingTimer:YES];
	NSLog(@"fired timer");
}


-(void)onTick:(NSTimer *)timer
{
	NSLog(@"OnTick");
	[ParseHelper pollParseForActiveSessions];
}

@end
