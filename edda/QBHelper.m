//
//  QBHelper.m
//
#define kUIAlertViewTagUserName 100
#define kUIAlertViewTagIncomingCall  200

#import "QBHelper.h"

@implementation QBHelper 

+(void) showUserTitlePrompt
{
	// Get the stored data before the view loads
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *nickname = [defaults objectForKey:@"nickname"];
	
	NSLog(@"saved nick: %@", nickname);
	
	if (nickname == nil || [nickname isEqualToString:@""]) {
		// no saved nick... prompt:
		UIAlertView *userNameAlert = [[UIAlertView alloc] initWithTitle:@"Edda" message:@"Enter a nickname:" delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
		userNameAlert.alertViewStyle = UIAlertViewStylePlainTextInput;
		userNameAlert.tag = kUIAlertViewTagUserName;
		[userNameAlert show];
	} else {
		// there is a saved nick
		eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
		appDelegate.userTitle = nickname;
		appDelegate.bFullyLoggedIn = YES;
		
		[self saveCurrentUserToQB];
	}
}

+(void) anonymousLogin
{
	[self showUserTitlePrompt];
}

+(void)signUpUser:(NSString *)username {
	eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];

	// Registration/sign up of User
	QBUUser *user = [QBUUser user];
	user.login = [QBHelper uniqueDeviceIdentifier];
	user.password = [QBHelper uniqueDeviceIdentifier];

	NSNumber *zero = [NSNumber numberWithFloat:0.0];
	NSNumber *negative = [NSNumber numberWithBool:NO];
	
	NSDictionary *custom = [[NSDictionary alloc] initWithObjectsAndKeys:
							zero, @"latitude",
							zero, @"longitude",
							zero, @"altitude",
							negative, @"privacy",
							negative, @"alignment",
							[[appDelegate.userTitle dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0], @"username",
							nil];
	
	NSString *customString = [QBHelper DictionaryToQBCustomData:custom];
	user.customData = customString;

	[QBRequest signUp:user successBlock:^(QBResponse *response, QBUUser *ruser) {
		// Sign up was successful
		// Sign In to QuickBlox Chat
		appDelegate.loggedInUser = ruser;
		NSLog(@"signed up: %@", appDelegate.loggedInUser);
		[QBHelper showUserTitlePrompt];
	} errorBlock:^(QBResponse *response) {
		// Handle error here
		NSLog(@"error while signing up with QB");
	}];
}

+ (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (kUIAlertViewTagUserName == alertView.tag && ![[alertView textFieldAtIndex:0].text isEqualToString:@""])
    {
		NSString *login = [[alertView textFieldAtIndex:0].text stringByTrimmingCharactersInSet:
						   [NSCharacterSet whitespaceCharacterSet]];
		
		eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
		NSLog(@"nick: %@", login);
        appDelegate.userTitle = login;
        appDelegate.bFullyLoggedIn = YES;
		
		// Store the data
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setObject:appDelegate.userTitle forKey:@"nickname"];
		[defaults synchronize];
		
		[QBHelper changeLoginToLogin:login];
		
		//fire appdelegate timer
		[self saveCurrentUserToQB];
    }
    else if (kUIAlertViewTagIncomingCall == alertView.tag)
    {
        if (buttonIndex != [alertView cancelButtonIndex])   //accept the call
        {
            //accept the call
            [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kIncomingCallNotification object:nil]];
        }
        else
        {
			[[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kCallCancelledNotification object:nil]];
        }
    }
}

+ (void) saveCurrentUserToQB
{
	[[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kLoggedInNotification object:nil]];
}

+ (void) changeLoginToLogin:(NSString *)newlogin
{
	eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
	
	if (appDelegate.loggedInUser == nil) return;
	
	NSDictionary * oldCustom = [QBHelper QBCustomDataToObject:appDelegate.loggedInUser.customData];
	
	NSMutableDictionary * newCustom = [NSMutableDictionary dictionaryWithDictionary:oldCustom];
	
	[newCustom setValue:[[newlogin dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] forKey:@"username"];
	
	appDelegate.userTitle = newlogin;

	[self saveCustomToQB:newCustom];
}

+ (void) saveUserAlignmentToQB:(BOOL)alignment
{
	eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
	
	NSDictionary * oldCustom = [QBHelper QBCustomDataToObject:appDelegate.loggedInUser.customData];
	
	NSMutableDictionary * newCustom = [NSMutableDictionary dictionaryWithDictionary:oldCustom];
	
	[newCustom setValue:[NSNumber numberWithBool:alignment] forKey:@"alignment"];
	
	[self saveCustomToQB:newCustom];
}

+ (void) saveUserPrivacyToQB:(BOOL)privacy
{
	eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
	
	NSDictionary * oldCustom = [QBHelper QBCustomDataToObject:appDelegate.loggedInUser.customData];
	
	NSMutableDictionary * newCustom = [NSMutableDictionary dictionaryWithDictionary:oldCustom];
	
	[newCustom setValue:[NSNumber numberWithBool:privacy] forKey:@"privacy"];
	
	[self saveCustomToQB:newCustom];
}

+ (NSDictionary *)QBCustomDataToObject:(NSString *)customData {
	NSError *e = nil;
    NSDictionary *custom = [NSJSONSerialization JSONObjectWithData:[customData dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&e];
	return custom;
}

+ (NSString *)DictionaryToQBCustomData:(NSDictionary *)dictionary {
	NSError *error;
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary
													   options:NSJSONWritingPrettyPrinted
														 error:&error];
	NSString *string = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
	return string;
}

+ (NSString *)decodeUsername:(NSString *)encodedUsername {
	NSData *encodedData = [[NSData alloc] initWithBase64EncodedString:encodedUsername options:0];
	
	NSString *userTitle = [[NSString alloc] initWithData:encodedData encoding:NSUTF8StringEncoding];
	
	return userTitle;
}

+ (void) saveCustomToQB:(NSDictionary *)custom {
	eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
	NSString *customString = [QBHelper DictionaryToQBCustomData:custom];
	appDelegate.loggedInUser.customData = customString;
	[QBRequest updateUser:appDelegate.loggedInUser successBlock:^(QBResponse *response, QBUUser *user) {
		// success
	} errorBlock:^(QBResponse *response) {
		// error
	}];
}

+ (void) saveUserWithLocationToQB:(QBLPlace *)place altitude:(NSNumber *)altitude
{
	NSNumber *lat = [NSNumber numberWithDouble:place.latitude];
	NSNumber *lon = [NSNumber numberWithDouble:place.longitude];
	NSNumber *alignment = [NSNumber numberWithBool:NO];

	eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
	NSDictionary * oldCustom = [QBHelper QBCustomDataToObject:appDelegate.loggedInUser.customData];
	
	NSMutableDictionary * newCustom = [NSMutableDictionary dictionaryWithDictionary:oldCustom];
	
	[newCustom setValue:lat forKey:@"latitude"];
	[newCustom setValue:lon forKey:@"longitude"];
	[newCustom setValue:altitude forKey:@"altitude"];
	[newCustom setValue:alignment forKey:@"alignment"];
	
	[self saveCustomToQB:newCustom];
}

+(void) showAlert : (NSString *) message
{
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Edda" message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
    [alert show];
}

+(void) processPushedCall:(NSDictionary *)userInfo {
	eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
	appDelegate.callerID = [userInfo valueForKey:@"callerID"];
	appDelegate.callerTitle = [userInfo valueForKey:@"callerTitle"];
}

+ (NSString *) uniqueDeviceIdentifier
{

//	return @"uuid";
	NSUUID *UUID = [UIDevice currentDevice].identifierForVendor;//[[SGKeyChain defaultKeyChain] stringForKey:@"uniqueId"];
	
	NSString *deviceUUID = [NSString stringWithString:UUID.UUIDString];

	return deviceUUID;
}
@end
