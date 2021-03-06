//
//  eddaAppDelegate.h
//  edda
//
//  Created by Mauricio Giraldo on 28/8/14.
//  Copyright (c) 2014 Ping Pong Estudio. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "QBHelper.h"

@interface eddaAppDelegate : UIResponder <UIApplicationDelegate, QBActionStatusDelegate>
{
	UIBackgroundTaskIdentifier backgroundTask;
}

@property (nonatomic) UIWindow *window;
@property (nonatomic) NSString *otAPIKey;
@property (nonatomic) NSString *otProjectSecret;
@property (nonatomic) NSString *pApplicationID;
@property (nonatomic) NSString *pClientKey;

@property (nonatomic) QBUUser* loggedInUser;
@property (copy, nonatomic) NSString* userTitle;
@property (copy, nonatomic) NSString* callerTitle;
@property (copy, nonatomic) NSString* callerID;
@property (copy, nonatomic) NSString* sessionID;
@property (copy, nonatomic) NSString* publisherToken;
@property (copy, nonatomic) NSString* subscriberToken;

@property (copy, nonatomic) NSNumber* callReceiverID;
@property (copy, nonatomic) NSString* callReceiverTitle;
@property (nonatomic) CLLocation *callReceiverLocation;
@property (nonatomic) NSNumber *callReceiverAltitude;

@property (nonatomic) CLLocation *currentLocation;
@property (assign, nonatomic) bool bFullyLoggedIn;  //to say user also entered his title
@property (nonatomic) NSTimer * appTimer;

@property (strong) NSData* token;

@end
