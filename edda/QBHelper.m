//
//  QBHelper.m
//
#define kUIAlertViewTagUserName 100
#define kUIAlertViewTagIncomingCall  200

#import "QBHelper.h"

@implementation QBHelper 

//will initiate the call by saving session
//if there is a session already existing, do not save,
//just pop an alert
+(void)saveSessionToQB:(NSDictionary *)inputDict
{
//    NSString * receiverID = [inputDict objectForKey:@"receiverID"];
//	
//	PFQuery *recID = [PFQuery queryWithClassName:@"ActiveSessions"];
//	[recID whereKey:@"receiverID" equalTo:receiverID];
// 
//	PFQuery *callID = [PFQuery queryWithClassName:@"ActiveSessions"];
//	[callID whereKey:@"callerID" equalTo:receiverID];
//	
//	PFQuery *query = [PFQuery orQueryWithSubqueries:@[recID,callID]];
//	
//    [query getFirstObjectInBackgroundWithBlock:^
//    (PFObject *object, NSError *error)
//    {
//        if (!object)
//        {
//            NSLog(@"No session with receiverID exists.");
//            [self storeToQB:inputDict];
//        }
//        else
//        {
//           [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kReceiverBusyNotification object:nil]];
//           return;
//        }
//    }];
}

//+(void) storeToQB:(NSDictionary *)inputDict
//{
//    __block PFObject *activeSession = [PFObject objectWithClassName:@"ActiveSessions"];
//    NSString * callerID = [inputDict objectForKey:@"callerID"];
//    if (callerID)
//    {
//        [activeSession setObject:callerID forKey:@"callerID"];
//    }
//	
//    NSString * receiverID = [inputDict objectForKey:@"receiverID"];
//    if (receiverID)
//    {
//        [activeSession setObject:receiverID forKey:@"receiverID"];
//    }
//    
//    //callerTitle
//    NSString * callerTitle = [inputDict objectForKey:@"callerTitle"];
//    if (receiverID)
//    {
//        [activeSession setObject:callerTitle forKey:@"callerTitle"];
//    }
//    
//    [activeSession saveInBackgroundWithBlock:^(BOOL succeeded, NSError* error)
//     {
//         if (!error)
//         {
////             NSLog(@"sessionID: %@, publisherToken: %@ , subscriberToken: %@", activeSession[@"sessionID"],activeSession[@"publisherToken"],
////                   activeSession[@"subscriberToken"]);
//			 
//             eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
//             appDelegate.sessionID = activeSession[@"sessionID"];
//             appDelegate.subscriberToken = activeSession[@"subscriberToken"];
//             appDelegate.publisherToken = activeSession[@"publisherToken"];
//             appDelegate.callerTitle = activeSession[@"callerTitle"];
//             [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kSessionSavedNotification object:nil]];
//         }
//         else
//         {
//             NSLog(@"savesession error!!! %@", [error localizedDescription]);
//             NSString * msg = [NSString stringWithFormat:@"Failed to save outgoing call session. Please try again.  %@", [error localizedDescription]];
//             [self showAlert:msg];
//         }         
//     }];
//}

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
	// Registration/sign up of User
	QBUUser *user = [QBUUser user];
	user.login = [NSString stringWithFormat:@"%@_%@", username, [QBHelper uniqueDeviceIdentifier]];
	user.password = [QBHelper uniqueDeviceIdentifier];
	
	[QBRequest signUp:user successBlock:^(QBResponse *response, QBUUser *ruser) {
		eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
		// Sign up was successful
		// Sign In to QuickBlox Chat
		appDelegate.loggedInUser = ruser;
		NSLog(@"signed up: %@", appDelegate.loggedInUser);
		[self showUserTitlePrompt];
	} errorBlock:^(QBResponse *response) {
		// Handle error here
		NSLog(@"error while signing up with QB");
	}];
}

+ (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (kUIAlertViewTagUserName == alertView.tag && ![[alertView textFieldAtIndex:0].text isEqualToString:@""])
    {
        //lets differe saving title till we have the location.
        //saveuserwithlocationtoQB will handle it.
        eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
		NSLog(@"nick: %@", [alertView textFieldAtIndex:0].text);
        appDelegate.userTitle = [[alertView textFieldAtIndex:0].text copy];
        appDelegate.bFullyLoggedIn = YES;
		
		// Store the data
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setObject:appDelegate.userTitle forKey:@"nickname"];
		[defaults synchronize];
		
		// Store the deviceToken in the current Installation and save it to QB.
//		[appDelegate saveInstallation];

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

+ (void) saveUserAlignmentToQB:(BOOL)alignment
{
	eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
	
	NSDictionary * oldCustom = [QBHelper QBCustomDataToObject:appDelegate.loggedInUser.customData];
	
	NSMutableDictionary * newCustom = [NSMutableDictionary dictionaryWithDictionary:oldCustom];
	
	[newCustom setValue:[NSNumber numberWithBool:alignment] forKey:@"alignment"];
	
	[self saveCustomToQB:newCustom];
}

+ (NSDictionary *)QBCustomDataToObject:(NSString *)customData {
	NSError *e = nil;
    NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:[customData dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&e];
	return JSON;
}

+ (NSString *)DictionaryToQBCustomData:(NSDictionary *)dictionary {
	NSError *error;
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary
													   options:NSJSONWritingPrettyPrinted
														 error:&error];
	NSString *string = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
	return string;
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
	NSDictionary *custom = [[NSDictionary alloc] initWithObjectsAndKeys:lat, @"latitude", lon, @"longitude", altitude, @"altitude", alignment, @"alignment", nil];
	
	[self saveCustomToQB:custom];
	
//	// first get this user's geodata, if any
//	QBLGeoDataFilter *geoFilter = [QBLGeoDataFilter new];
//	geoFilter.userID = [QBHelper self.loggedInUser].ID;
//	
//	[QBRequest geoDataWithFilter:geoFilter page:[QBGeneralResponsePage responsePageWithCurrentPage:1 perPage:70]
//					successBlock:^(QBResponse *response, NSArray *objects, QBGeneralResponsePage *page) {
//		// success
//		if (objects.count > 0) {
//			// delete dem locations
//			for (int i = 0; i < objects.count; i++) {
//				QBLGeoData *geoData = (QBLGeoData *)[objects objectAtIndex:i];
//				[QBRequest deleteGeoDataWithID:geoData.ID successBlock:^(QBResponse *response) {
//					// Successful response
//				} errorBlock:^(QBResponse *response) {
//					// Handle error
//				}];
//			}
//		}
//		// create
//		QBLGeoData *geodata = [QBLGeoData geoData];
//		
//		// place coordinates
//		geodata.latitude = place.latitude;
//		geodata.longitude = place.longitude;
//		geodata.status = altitude.stringValue;
//		
//		[QBRequest createGeoData:geodata
//					successBlock:^(QBResponse *response, QBLGeoData *geoData) {
//						// Geodata created successfully
//						NSLog(@"success saving location!");
//						[[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kUserLocSavedNotification object:nil]];
//					} errorBlock:^(QBResponse *response) {
//						// Handle error
//						NSLog(@"ERROR saving location!");
//					}];
//	} errorBlock:^(QBResponse *response) {
//		// error
//		NSLog(@"some error with the geo data filter query");
//	}];
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
