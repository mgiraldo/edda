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
	
	if (nickname == nil) {
		UIAlertView *userNameAlert = [[UIAlertView alloc] initWithTitle:@"Edda" message:@"Enter a nickname:" delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
		userNameAlert.alertViewStyle = UIAlertViewStylePlainTextInput;
		userNameAlert.tag = kUIAlertViewTagUserName;
		[userNameAlert show];
	} else {
		eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
		appDelegate.userTitle = nickname;
		appDelegate.bFullyLoggedIn = YES;
		
		// Store the deviceToken in the current Installation and save it to QB.
//		[appDelegate saveInstallation];
		
		//fire appdelegate timer
		[self saveCurrentUserToQB];
	}
}

+(void) anonymousLogin
{
	loggedInUser = [QBUUser user];
	if (loggedInUser)
	{
		[self showUserTitlePrompt];
		return;
	}
	
	eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
	NSLog(@"nick: %@", appDelegate.userTitle);
	
	[QBRequest createSessionWithSuccessBlock:^(QBResponse *response, QBASession *session) {
		// session created
		
		QBUUser *user = [QBUUser user];
		user.login = appDelegate.userTitle;
		user.password = [[QBHelper uniqueDeviceIdentifier] substringToIndex:16];
		
		// Registration/sign up of User
		[QBRequest signUp:user successBlock:^(QBResponse *response, QBUUser *ruser) {
			// Sign up was successful
			// Sign In to QuickBlox Chat
			loggedInUser = ruser;
			NSLog(@"signed up: %@", loggedInUser);
			[self showUserTitlePrompt];
		} errorBlock:^(QBResponse *response) {
			// Handle error here
			NSLog(@"error while signing up with QB");
		}];
	} errorBlock:^(QBResponse *response) {
		// handle errors
		NSLog(@"%@", response.error);
	}];
}

+(void) initData
{
    if (!objectsUnderDeletionQueue)
        objectsUnderDeletionQueue = [NSMutableArray array];
}

+ (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (kUIAlertViewTagUserName == alertView.tag)
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
            //user did not accept call, restart timer
            //start polling for new call.
            [self setPollingTimer:YES];
        }
    }
}

+ (void) deleteActiveUser
{
//    NSString * activeUserobjID = [self activeUserObjectID];
//    if (!activeUserobjID || [activeUserobjID isEqualToString:@""])
//        return;
//    
//    PFQuery *query = [PFQuery queryWithClassName:@"ActiveUsers"];
//    [query whereKey:@"userID" equalTo:activeUserobjID];
//    
//    [query getFirstObjectInBackgroundWithBlock:^(PFObject *object, NSError *error)
//    {
//        if (!object)
//        {
//            NSLog(@"No such users exists.");
//        }
//        else
//        {
//            // The find succeeded.
//            NSLog(@"Successfully retrieved the ActiveUser.");
//            [object deleteInBackgroundWithBlock:^(BOOL succeeded, NSError *error)
//             {
//                 if (succeeded && !error)
//                 {
//                     NSLog(@"User deleted from QB");
//                     activeUserObjectID = nil;
//                 }
//                 else
//                 {
//                     //[self showAlert:[error description]];
//                      NSLog(@"%@", [error description]);
//                 }
//             }];
//        }
//    }];
}

+ (bool) isUnderDeletion : (id) argObjectID
{
    return [objectsUnderDeletionQueue containsObject:argObjectID];
}

+ (void) deleteActiveSession
{
//    NSLog(@"deleteActiveSession");
//    eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
//    NSString * activeSessionID = appDelegate.sessionID;
//    
//    if (!activeSessionID || [activeSessionID isEqualToString:@""])
//        return;
//  
//
//    PFQuery *query = [PFQuery queryWithClassName:@"ActiveSessions"];
//    [query whereKey:@"sessionID" equalTo:appDelegate.sessionID];
//
//    [query getFirstObjectInBackgroundWithBlock:^(PFObject *object, NSError *error)
//    {
//        if (!object)
//        {
//            NSLog(@"No session exists.");     
//        }
//        else
//        {
//            // The find succeeded.
//            NSLog(@"Successfully retrieved the object.");
//            [object deleteInBackgroundWithBlock:^(BOOL succeeded, NSError *error)
//            {
//                if (succeeded && !error)
//                {
//                    NSLog(@"Session deleted from QB");                   
//                }
//                else
//                {
//                    //[self showAlert:[error description]];
//                    NSLog(@"%@", [error description]);
//                }
//            }];
//        }
//    }];
}

+ (void) saveCurrentUserToQB
{
	eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];

	NSString *password = [[QBHelper uniqueDeviceIdentifier] substringToIndex:16];
	
	[QBRequest createSessionWithSuccessBlock:^(QBResponse *response, QBASession *session) {
		[QBRequest logInWithUserLogin:appDelegate.userTitle password:password successBlock:^(QBResponse *response, QBUUser *user) {
			// success
			NSLog(@"log in success!");
			loggedInUser = user;
			[[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kLoggedInNotification object:nil]];
		} errorBlock:^(QBResponse *response) {
			// error / try sign up
			QBUUser *user = [QBUUser user];
			user.login = appDelegate.userTitle;
			user.password = password;
			
			// Registration/sign up of User
			[QBRequest signUp:user successBlock:^(QBResponse *response, QBUUser *ruser) {
				// Sign up was successful
				// Sign In to QuickBlox Chat
				loggedInUser = ruser;
				NSLog(@"signed up: %@", loggedInUser);
				[self showUserTitlePrompt];
			} errorBlock:^(QBResponse *response) {
				// Handle error here
				NSLog(@"error while signing up with QB");
			}];
		}];
	} errorBlock:^(QBResponse *response) {
		// handle errors
		NSLog(@"%@", response.error);
	}];

//	__block PFObject *activeUser;
//
//	PFQuery *query = [PFQuery queryWithClassName:@"ActiveUsers"];
//	[query whereKey:@"userID" equalTo:[NSString stringWithFormat:@"%@",loggedInUser.objectId]];
//	[query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error)
//	 {
//		 NSLog(@"current: %@",loggedInUser.objectId);
//		 if (!error)
//		 {
//			 // if user is active user already, just update the entry
//			 // otherwise create it.
//			 if (objects.count == 0)
//			 {
//				 activeUser = [PFObject objectWithClassName:@"ActiveUsers"];
//			 }
//			 else
//			 {
//				 activeUser = (PFObject *)[objects objectAtIndex:0];
//			 }
//			 NSLog(@"%i objects for id: %@", objects.count, loggedInUser.objectId);
//			 eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
//			 [activeUser setObject:[NSString stringWithFormat:@"%@",loggedInUser.objectId] forKey:@"userID"];
//			 [activeUser setObject:[PFGeoPoint geoPointWithLocation:appDelegate.currentLocation] forKey:@"userLocation"];
//			 [activeUser setObject:[NSNumber numberWithDouble:appDelegate.currentLocation.altitude] forKey:@"userAltitude"];
//			 [activeUser setObject:@NO forKey:@"isAligned"];
//			 [activeUser setObject:appDelegate.userTitle forKey:@"userTitle"];
//			 [activeUser saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error)
//			  {
//				  if (error)
//				  {
//					  NSString * errordesc = [NSString stringWithFormat:@"Save to ActiveUsers failed.%@", [error localizedDescription]];
//					  [self showAlert:errordesc];
//					  NSLog(@"%@", errordesc);
//				  }
//				  else
//				  {
//					  NSLog(@"Save to ActiveUsers succeeded.");
//					  activeUserObjectID = activeUser.objectId;
//					  
//					  NSLog(@"objectID: %@ userID: %@", activeUserObjectID, loggedInUser.objectId);
//				  }
//				  [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kLoggedInNotification object:nil]];
////				  [appDelegate fireListeningTimer];
//			  }];
//		 }
//		 else
//		 {
//			 NSString * msg = [NSString stringWithFormat:@"Failed to save updated location. Please try again.  %@", [error localizedDescription]];
//			 [self showAlert:msg];
//		 }
//	 }];
}

+ (void) saveUserAlignmentToQB:(BOOL)alignment
{
	NSDictionary * oldCustom = [QBHelper QBCustomDataToObject:loggedInUser.customData];
	
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
	NSString *customString = [QBHelper DictionaryToQBCustomData:custom];
	loggedInUser.customData = customString;
	[QBRequest updateUser:loggedInUser successBlock:^(QBResponse *response, QBUUser *user) {
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
	
	// first get this user's geodata, if any
	QBLGeoDataFilter *geoFilter = [QBLGeoDataFilter new];
	geoFilter.userID = loggedInUser.ID;
	
	[QBRequest geoDataWithFilter:geoFilter page:[QBGeneralResponsePage responsePageWithCurrentPage:1 perPage:70]
					successBlock:^(QBResponse *response, NSArray *objects, QBGeneralResponsePage *page) {
		// success
		if (objects.count > 0) {
			// delete dem locations
			for (int i = 0; i < objects.count; i++) {
				QBLGeoData *geoData = (QBLGeoData *)[objects objectAtIndex:i];
				[QBRequest deleteGeoDataWithID:geoData.ID successBlock:^(QBResponse *response) {
					// Successful response
				} errorBlock:^(QBResponse *response) {
					// Handle error
				}];
			}
		}
		// create
		QBLGeoData *geodata = [QBLGeoData geoData];
		
		// place coordinates
		geodata.latitude = place.latitude;
		geodata.longitude = place.longitude;
		geodata.status = altitude.stringValue;
		
		[QBRequest createGeoData:geodata
					successBlock:^(QBResponse *response, QBLGeoData *geoData) {
						// Geodata created successfully
						NSLog(@"success saving location!");
						[[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kUserLocSavedNotification object:nil]];
					} errorBlock:^(QBResponse *response) {
						// Handle error
						NSLog(@"ERROR saving location!");
					}];
	} errorBlock:^(QBResponse *response) {
		// error
		NSLog(@"some error with the geo data filter query");
	}];
}

+(void) showAlert : (NSString *) message
{
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"LiveSessions" message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
    [alert show];
}

+(NSString*) activeUserObjectID
{
    return activeUserObjectID;
}

+(QBUUser*) loggedInUser
{    
    return loggedInUser;
}

+(void) setPollingTimer : (bool) bArg
{
    bPollingTimerOn = bArg;
}

+ (void) invalidateTimer
{
    NSLog(@"invalidating");
    bPollingTimerOn = NO;
    eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate.appTimer invalidate];
    appDelegate.appTimer = nil;
}

//poll QB ActiveSessions object for incoming calls.
+(void) pollQBForActiveSessions
{
//    __block PFObject *activeSession;
//    
//    if (!bPollingTimerOn)
//        return;
//    
//    PFQuery *query = [PFQuery queryWithClassName:@"ActiveSessions"];
//    
//    NSString* currentUserID = [self loggedInUser].objectId;
//	if (currentUserID==nil)
//		return;
//    [query whereKey:@"receiverID" equalTo:currentUserID];  
//    
//    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error)
//     {
//         if (!error)
//         {
//             // if user is active user already, just update the entry
//             // otherwise create it.
//             eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
//         
//             if (objects.count == 0)
//             {
//            
//             }
//             else
//             {
//                 activeSession = (PFObject *)[objects objectAtIndex:0];                 
//                 appDelegate.sessionID = activeSession[@"sessionID"];
//                 appDelegate.subscriberToken = activeSession[@"subscriberToken"];
//                 appDelegate.publisherToken = activeSession[@"publisherToken"];
//                 appDelegate.callerTitle = activeSession[@"callerTitle"];
//				 appDelegate.callerID = activeSession[@"callerID"];
//
//				 //done with backend object, remove it.
//                 [self setPollingTimer:NO];
//                 [self deleteActiveSession];
//                 
//                 NSString *msg = [NSString stringWithFormat:@"incoming call from %@, accept?", appDelegate.callerTitle];
//                 
//                 UIAlertView *incomingCallAlert = [[UIAlertView alloc] initWithTitle:@"Edda" message:msg delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
//                
//                 incomingCallAlert.tag = kUIAlertViewTagIncomingCall;
//                 [incomingCallAlert show];                 
//             }
//         }
//         else
//         {
//             NSString * msg = [NSString stringWithFormat:@"Failed to retrieve active session for incoming call. Please try again. %@", [error localizedDescription]];
//             [self showAlert:msg];
//         }
//     }];
}

+ (NSString *) uniqueDeviceIdentifier
{

//	return @"uuid";
	NSUUID *UUID = [UIDevice currentDevice].identifierForVendor;//[[SGKeyChain defaultKeyChain] stringForKey:@"uniqueId"];
	
	NSString *deviceUUID = [NSString stringWithString:UUID.UUIDString];

	return deviceUUID;
}
@end
