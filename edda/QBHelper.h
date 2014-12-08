//
//  QBHelper.h
//

#define kLoggedInNotification @"LoggedInNotification"
#define kIncomingCallNotification @"IncomingCallNotification"
#define kCallCancelledNotification @"CallCancelledNotification"
#define kSessionSavedNotification @"SessionSavedNotification"
#define kReceiverBusyNotification @"ReceiverBusyNotification"
#define kMessageSentNotification @"MessageSentNotification"
#define kMessageArrivedNotification @"MessageArrivedNotification"
#define kUserLocSavedNotification @"UserLocSavedNotification"

#import <Foundation/Foundation.h>
#import "eddaAppDelegate.h"

static QBUUser* loggedInUser;
static NSString* activeUserObjectID;
static bool bPollingTimerOn = NO;
static NSMutableArray * objectsUnderDeletionQueue;

@interface QBHelper : NSObject
{
   
}
+(void) setPollingTimer : (bool) bArg;
+(void) initData;
+ (void) saveUserAlignmentToQB:(BOOL)alignment;
+(QBUUser*) loggedInUser;
+(NSString*) activeUserObjectID;
//+ (void)saveUserToQB:(NSDictionary *)inputDict;
+(void)saveCurrentUserToQB;
+(void)saveSessionToQB:(NSDictionary *)inputDict;
//+(void)saveMessageToQB:(NSDictionary *)inputDict;
+(void) saveUserWithLocationToQB:(QBLPlace *)place altitude:(NSNumber *)altitude;
+(void) pollQBForActiveSessions;
//+(void) pollQBForActiveMessages;
+(void) showAlert : (NSString *) message;
+(void) deleteActiveUser;
+(void) deleteActiveSession;
+(void) showUserTitlePrompt;
+(NSString *) uniqueDeviceIdentifier;
+(void) anonymousLogin;
@end
