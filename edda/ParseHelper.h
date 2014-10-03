//
//  ParseHelper.h
//  LiveSessions
//
//  Created by Nirav Bhatt on 3/9/13.
//  Copyright (c) 2013 IPhoneGameZone. All rights reserved.
//

#define kLoggedInNotification @"LoggedInNotification"
#define kIncomingCallNotification @"IncomingCallNotification"
#define kSessionSavedNotification @"SessionSavedNotification"
#define kReceiverBusyNotification @"ReceiverBusyNotification"
#define kMessageSentNotification @"MessageSentNotification"
#define kMessageArrivedNotification @"MessageArrivedNotification"
#define kUserLocSavedNotification @"UserLocSavedNotification"

#import <Foundation/Foundation.h>
#import "Parse/Parse.h"
#import "eddaAppDelegate.h"

static PFUser* loggedInUser;
static NSString* activeUserObjectID;
static bool bPollingTimerOn = NO;
static NSMutableArray * objectsUnderDeletionQueue;

@interface ParseHelper : NSObject
{
   
}
+(void) setPollingTimer : (bool) bArg;
+(void) initData;
+ (void) saveUserAlignmentToParse:(PFUser*)user :(BOOL)alignment;
+(PFUser*) loggedInUser;
+(NSString*) activeUserObjectID;
+(void) anonymousLogin;
//+ (void)saveUserToParse:(NSDictionary *)inputDict;
+ (void)saveCurrentUserToParse;
+(void)saveSessionToParse:(NSDictionary *)inputDict;
//+(void)saveMessageToParse:(NSDictionary *)inputDict;
+ (void) saveUserWithLocationToParse:(PFUser*) user :(PFGeoPoint *)geopoint :(NSNumber *)altitude;
+(void) pollParseForActiveSessions;
//+(void) pollParseForActiveMessages;
+(void) showAlert : (NSString *) message;
+ (void) deleteActiveUser;
+ (void) deleteActiveSession;
@end
