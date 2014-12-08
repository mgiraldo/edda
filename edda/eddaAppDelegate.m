//
//  eddaAppDelegate.m
//  edda
//
//  Created by Mauricio Giraldo on 28/8/14.
//  Copyright (c) 2014 Ping Pong Estudio. All rights reserved.
//

#import "eddaAppDelegate.h"
#import "eddaMainViewController.h"

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
	
	// Quickblox
	[QBApplication sharedApplication].applicationId = [configuration[@"Quickblox"][@"ApplicationID"] integerValue];
	[QBConnection registerServiceKey:configuration[@"Quickblox"][@"AuthKey"]];
	[QBConnection registerServiceSecret:configuration[@"Quickblox"][@"AuthSecret"]];
	[QBSettings setAccountKey:configuration[@"Quickblox"][@"AccountKey"]];
	
	NSMutableDictionary *videoChatConfiguration = [[QBSettings videoChatConfiguration] mutableCopy];
	[videoChatConfiguration setObject:@20 forKey:kQBVideoChatCallTimeout];
	[videoChatConfiguration setObject:AVCaptureSessionPresetLow forKey:kQBVideoChatFrameQualityPreset];
	[videoChatConfiguration setObject:@2 forKey:kQBVideoChatVideoFramesPerSecond];
	[videoChatConfiguration setObject:@3 forKey:kQBVideoChatP2PTimeout];
	[videoChatConfiguration setObject:@10 forKey:kQBVideoChatBadConnectionTimeout];
	[QBSettings setVideoChatConfiguration:videoChatConfiguration];

	self.bFullyLoggedIn = NO;
	[QBHelper initData];
	[QBHelper anonymousLogin];
	
	// Register for Push Notitications, if running iOS 8
	if ([application respondsToSelector:@selector(registerUserNotificationSettings:)]) {
		UIUserNotificationType userNotificationTypes = (UIUserNotificationTypeAlert |
														UIUserNotificationTypeBadge |
														UIUserNotificationTypeSound);
		UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:userNotificationTypes
																				 categories:nil];
		[application registerUserNotificationSettings:settings];
		[application registerForRemoteNotifications];
	} else {
		// Register for Push Notifications before iOS 8
		[application registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge |
														 UIRemoteNotificationTypeAlert |
														 UIRemoteNotificationTypeSound)];
	}

	if (application.applicationState != UIApplicationStateBackground) {
		// Track an app open here if we launch with a push, unless
		// "content_available" was used to trigger a background push (introduced
		// in iOS 7). In that case, we skip tracking here to avoid double
		// counting the app-open.
		BOOL preBackgroundPush = ![application respondsToSelector:@selector(backgroundRefreshStatus)];
		BOOL oldPushHandlerOnly = ![self respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)];
		BOOL noPushPayload = ![launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
		if (preBackgroundPush || oldPushHandlerOnly || noPushPayload) {
//		  [PFAnalytics trackAppOpenedWithLaunchOptions:launchOptions];
		}
	}

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
        [QBHelper deleteActiveSession];
        [QBHelper deleteActiveUser];
        [application endBackgroundTask:backgroundTask];
        backgroundTask = UIBackgroundTaskInvalid;
				   });
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
	// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
	self.bFullyLoggedIn = NO;
	[QBHelper initData];
	[QBHelper anonymousLogin];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark - Push notifications

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
	NSLog(@"registered for notifs: %@", deviceToken);
	self.token = deviceToken;
	[self saveInstallation];
}

-(void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
	NSLog(@"FAILED to register for notifs: %@", error);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
	NSLog(@"didReceiveRemoteNotification: %@", userInfo);
	if (application.applicationState == UIApplicationStateInactive) {
		// The application was just brought from the background to the foreground,
		// so we consider the app as having been "opened by a push notification."
//		[PFAnalytics trackAppOpenedWithRemoteNotificationPayload:userInfo];
//		[PFPush handlePush:userInfo];
	}
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
	NSLog(@"received push: %@", userInfo);
	if (application.applicationState == UIApplicationStateInactive) {
		// The application was just brought from the background to the foreground,
		// so we consider the app as having been "opened by a push notification."
//		[PFAnalytics trackAppOpenedWithRemoteNotificationPayload:userInfo];
//		[PFPush handlePush:userInfo];
	}
	if (completionHandler) {
		completionHandler(UIBackgroundFetchResultNewData);
	}
}

-(void)saveInstallation{
//	if ([PFUser currentUser]) {
//		PFInstallation *currentInstallation = [PFInstallation currentInstallation];
//		[currentInstallation setDeviceTokenFromData:self.token];
//		[currentInstallation setObject:[PFUser currentUser] forKey:@"user"];
//		[currentInstallation saveInBackground];
//		
//		NSLog(@"INSTALLATION REGISTERED");
//	}
}

#pragma mark - Call timer

//this method will be called once logged in. It will poll QB ActiveSessions object
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
	[QBHelper setPollingTimer:YES];
	NSLog(@"fired timer");
}


-(void)onTick:(NSTimer *)timer
{
//	NSLog(@"OnTick");
	[QBHelper pollQBForActiveSessions];
}

@end
