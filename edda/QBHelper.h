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
+ (void) setPassword:(NSString *)password;
+ (void) saveUserAlignmentToQB:(BOOL)alignment;
+ (void) saveUserPrivacyToQB:(BOOL)privacy;
+ (NSDictionary *)QBCustomDataToObject:(NSString *)customData;
+ (NSString *)decodeText:(NSString *)encodedText;
+ (void) saveUserWithLocationToQB:(QBLPlace *)place altitude:(NSNumber *)altitude;
+ (void) processPushedCall:(NSDictionary *)userInfo;
+ (void)signUpUser:(NSString *)username;
+ (void) showAlert : (NSString *) message;
+ (void) showUserTitlePrompt;
+ (NSString *) uniqueDeviceIdentifier;
+ (void) anonymousLogin;
+ (void) initQBSession;

@end
