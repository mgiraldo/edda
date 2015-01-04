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

static NSString* activeUserObjectID;
static bool bPollingTimerOn = NO;

@interface QBHelper : NSObject
{
   
}

+ (void) changeLoginToLogin:(NSString *)login;
+ (void) saveUserAlignmentToQB:(BOOL)alignment;
+ (NSDictionary *)QBCustomDataToObject:(NSString *)customData;
+ (NSString *)decodeUsername:(NSString *)encodedUsername;
+(void)saveCurrentUserToQB;
+(void) saveUserWithLocationToQB:(QBLPlace *)place altitude:(NSNumber *)altitude;
+(void) processPushedCall:(NSDictionary *)userInfo;
+(void)signUpUser:(NSString *)username;
+(void) showAlert : (NSString *) message;
+(void) showUserTitlePrompt;
+(NSString *) uniqueDeviceIdentifier;
+(void) anonymousLogin;
@end
