//
//  ParseHelper.m
//  LiveSessions
//
//  Created by Nirav Bhatt on 3/9/13.
//  Copyright (c) 2013 IPhoneGameZone. All rights reserved.
//
#define kUIAlertViewTagUserName 100
#define kUIAlertViewTagIncomingCall  200

#import "ParseHelper.h"

@implementation ParseHelper

//will initiate the call by saving session
//if there is a session already existing, do not save,
//just pop an alert
+(void)saveSessionToParse:(NSDictionary *)inputDict
{    
    NSString * receiverID = [inputDict objectForKey:@"receiverID"];
	
	PFQuery *recID = [PFQuery queryWithClassName:@"ActiveSessions"];
	[recID whereKey:@"receiverID" equalTo:receiverID];
 
	PFQuery *callID = [PFQuery queryWithClassName:@"ActiveSessions"];
	[callID whereKey:@"callerID" equalTo:receiverID];
	
	PFQuery *query = [PFQuery orQueryWithSubqueries:@[recID,callID]];
	
    [query getFirstObjectInBackgroundWithBlock:^
    (PFObject *object, NSError *error)
    {
        if (!object)
        {
            NSLog(@"No session with receiverID exists.");
            [self storeToParse:inputDict];
        }
        else
        {
           [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kReceiverBusyNotification object:nil]];
           return;
        }
    }];
}

+(void) storeToParse:(NSDictionary *)inputDict
{
    __block PFObject *activeSession = [PFObject objectWithClassName:@"ActiveSessions"];
    NSString * callerID = [inputDict objectForKey:@"callerID"];
    if (callerID)
    {
        [activeSession setObject:callerID forKey:@"callerID"];
    }
	
    NSString * receiverID = [inputDict objectForKey:@"receiverID"];
    if (receiverID)
    {
        [activeSession setObject:receiverID forKey:@"receiverID"];
    }
    
    //callerTitle
    NSString * callerTitle = [inputDict objectForKey:@"callerTitle"];
    if (receiverID)
    {
        [activeSession setObject:callerTitle forKey:@"callerTitle"];
    }
    
    [activeSession saveInBackgroundWithBlock:^(BOOL succeeded, NSError* error)
     {
         if (!error)
         {
//             NSLog(@"sessionID: %@, publisherToken: %@ , subscriberToken: %@", activeSession[@"sessionID"],activeSession[@"publisherToken"],
//                   activeSession[@"subscriberToken"]);
			 
             eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
             appDelegate.sessionID = activeSession[@"sessionID"];
             appDelegate.subscriberToken = activeSession[@"subscriberToken"];
             appDelegate.publisherToken = activeSession[@"publisherToken"];
             appDelegate.callerTitle = activeSession[@"callerTitle"];
             [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kSessionSavedNotification object:nil]];
         }
         else
         {
             NSLog(@"savesession error!!! %@", [error localizedDescription]);
             NSString * msg = [NSString stringWithFormat:@"Failed to save outgoing call session. Please try again.  %@", [error localizedDescription]];
             [self showAlert:msg];
         }         
     }];
}

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
		
		// Store the deviceToken in the current Installation and save it to Parse.
//		[appDelegate saveInstallation];
		
		//fire appdelegate timer
		[self saveCurrentUserToParse];
	}
}

+(void) anonymousLogin
{
    loggedInUser = [PFUser currentUser];
    if (loggedInUser)
    {
		[self showUserTitlePrompt];
        return;
    }
    
    [PFAnonymousUtils logInWithBlock:^(PFUser *user, NSError *error)
     {
         if (error)
         {
             NSLog(@"Anonymous login failed.%@", [error localizedDescription]);
             NSString * msg = [NSString stringWithFormat:@"Failed to login anonymously. Please try again.  %@", [error localizedDescription]];
             [self showAlert:msg];
         }
         else
         {            
             loggedInUser = [PFUser user];
//             loggedInUser = user;
             [self showUserTitlePrompt];
         }
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
        //saveuserwithlocationtoparse will handle it.
        eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
		NSLog(@"nick: %@", [alertView textFieldAtIndex:0].text);
        appDelegate.userTitle = [[alertView textFieldAtIndex:0].text copy];
        appDelegate.bFullyLoggedIn = YES;
		
		// Store the data
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setObject:appDelegate.userTitle forKey:@"nickname"];
		[defaults synchronize];
		
		// Store the deviceToken in the current Installation and save it to Parse.
//		[appDelegate saveInstallation];

		//fire appdelegate timer
		[self saveCurrentUserToParse];
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
    NSString * activeUserobjID = [self activeUserObjectID];
    if (!activeUserobjID || [activeUserobjID isEqualToString:@""])
        return;
    
    PFQuery *query = [PFQuery queryWithClassName:@"ActiveUsers"];
    [query whereKey:@"userID" equalTo:activeUserobjID];
    
    [query getFirstObjectInBackgroundWithBlock:^(PFObject *object, NSError *error)
    {
        if (!object)
        {
            NSLog(@"No such users exists.");
        }
        else
        {
            // The find succeeded.
            NSLog(@"Successfully retrieved the ActiveUser.");
            [object deleteInBackgroundWithBlock:^(BOOL succeeded, NSError *error)
             {
                 if (succeeded && !error)
                 {
                     NSLog(@"User deleted from parse");
                     activeUserObjectID = nil;
                 }
                 else
                 {
                     //[self showAlert:[error description]];
                      NSLog(@"%@", [error description]);
                 }
             }];
        }
    }];
}

+ (bool) isUnderDeletion : (id) argObjectID
{
    return [objectsUnderDeletionQueue containsObject:argObjectID];
}

+ (void) deleteActiveSession
{
    NSLog(@"deleteActiveSession");
    eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
    NSString * activeSessionID = appDelegate.sessionID;
    
    if (!activeSessionID || [activeSessionID isEqualToString:@""])
        return;
  

    PFQuery *query = [PFQuery queryWithClassName:@"ActiveSessions"];
    [query whereKey:@"sessionID" equalTo:appDelegate.sessionID];

    [query getFirstObjectInBackgroundWithBlock:^(PFObject *object, NSError *error)
    {
        if (!object)
        {
            NSLog(@"No session exists.");     
        }
        else
        {
            // The find succeeded.
            NSLog(@"Successfully retrieved the object.");
            [object deleteInBackgroundWithBlock:^(BOOL succeeded, NSError *error)
            {
                if (succeeded && !error)
                {
                    NSLog(@"Session deleted from parse");                   
                }
                else
                {
                    //[self showAlert:[error description]];
                    NSLog(@"%@", [error description]);
                }
            }];
        }
    }];
}

+ (void) saveCurrentUserToParse
{
	__block PFObject *activeUser;

	PFQuery *query = [PFQuery queryWithClassName:@"ActiveUsers"];
	[query whereKey:@"userID" equalTo:[NSString stringWithFormat:@"%@",loggedInUser.objectId]];
	[query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error)
	 {
		 NSLog(@"current: %@",loggedInUser.objectId);
		 if (!error)
		 {
			 // if user is active user already, just update the entry
			 // otherwise create it.
			 if (objects.count == 0)
			 {
				 activeUser = [PFObject objectWithClassName:@"ActiveUsers"];
			 }
			 else
			 {
				 activeUser = (PFObject *)[objects objectAtIndex:0];
			 }
			 NSLog(@"%i objects for id: %@", objects.count, loggedInUser.objectId);
			 eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
			 [activeUser setObject:[NSString stringWithFormat:@"%@",loggedInUser.objectId] forKey:@"userID"];
			 [activeUser setObject:[PFGeoPoint geoPointWithLocation:appDelegate.currentLocation] forKey:@"userLocation"];
			 [activeUser setObject:[NSNumber numberWithDouble:appDelegate.currentLocation.altitude] forKey:@"userAltitude"];
			 [activeUser setObject:@NO forKey:@"isAligned"];
			 [activeUser setObject:appDelegate.userTitle forKey:@"userTitle"];
			 [activeUser saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error)
			  {
				  if (error)
				  {
					  NSString * errordesc = [NSString stringWithFormat:@"Save to ActiveUsers failed.%@", [error localizedDescription]];
					  [self showAlert:errordesc];
					  NSLog(@"%@", errordesc);
				  }
				  else
				  {
					  NSLog(@"Save to ActiveUsers succeeded.");
					  activeUserObjectID = activeUser.objectId;
					  
					  NSLog(@"objectID: %@ userID: %@", activeUserObjectID, loggedInUser.objectId);
				  }
				  [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kLoggedInNotification object:nil]];
//				  [appDelegate fireListeningTimer];
			  }];
		 }
		 else
		 {
			 NSString * msg = [NSString stringWithFormat:@"Failed to save updated location. Please try again.  %@", [error localizedDescription]];
			 [self showAlert:msg];
		 }
	 }];
}

+ (void) saveUserAlignmentToParse:(BOOL)alignment
{
	PFQuery *query = [PFQuery queryWithClassName:@"ActiveUsers"];
	[query whereKey:@"userID" equalTo:loggedInUser.objectId];
//	NSLog(@"alignment for: [%@]", user.objectId);
	[query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
		if (!error) {
			// Do something with the found objects
			if (objects.count == 1) {
				[objects.firstObject setValue:[NSNumber numberWithBool:alignment] forKey:@"isAligned"];
				[objects.firstObject saveInBackground];
			} else {
				NSLog(@"error! found %d users", objects.count);
			}
		} else {
			// Log details of the failure
			NSLog(@"Error: %@ %@", error, [error userInfo]);
		}
	}];
}

+ (void) saveUserWithLocationToParse:(PFGeoPoint *)geopoint :(NSNumber *)altitude
{
    __block PFObject *activeUser;
	
	PFQuery *query = [PFQuery queryWithClassName:@"ActiveUsers"];
	[query whereKey:@"userID" equalTo:[NSString stringWithFormat:@"%@",loggedInUser.objectId]];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error)
    {
        if (!error)
        {
            // if user is active user already, just update the entry
            // otherwise create it.
            if (objects.count == 0)
            {
				activeUser = [PFObject objectWithClassName:@"ActiveUsers"];
            }
            else
            {
                
                activeUser = (PFObject *)[objects objectAtIndex:0];
            }
            eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
            [activeUser setObject:loggedInUser.objectId forKey:@"userID"];
            [activeUser setObject:geopoint forKey:@"userLocation"];
			[activeUser setObject:altitude forKey:@"userAltitude"];
            [activeUser setObject:appDelegate.userTitle forKey:@"userTitle"];
            [activeUser saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error)
            {
                if (error)
                {
                    NSString * errordesc = [NSString stringWithFormat:@"Save to ActiveUsers failed.%@", [error localizedDescription]];
                    [self showAlert:errordesc];
                    NSLog(@"%@", errordesc);
                }
                else
                {
                    NSLog(@"Save to ActiveUsers succeeded.");
                    activeUserObjectID = activeUser.objectId;
                   
                    NSLog(@"%@", activeUserObjectID);
                }
                [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kUserLocSavedNotification object:nil]];
            }];
        }
        else
        {
            NSString * msg = [NSString stringWithFormat:@"Failed to save updated location. Please try again.  %@", [error localizedDescription]];
            [self showAlert:msg];
        }
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

+(PFUser*) loggedInUser
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

//poll parse ActiveSessions object for incoming calls.
+(void) pollParseForActiveSessions
{
    __block PFObject *activeSession;
    
    if (!bPollingTimerOn)
        return;
    
    PFQuery *query = [PFQuery queryWithClassName:@"ActiveSessions"];
    
    NSString* currentUserID = [self loggedInUser].objectId;
	if (currentUserID==nil)
		return;
    [query whereKey:@"receiverID" equalTo:currentUserID];  
    
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error)
     {
         if (!error)
         {
             // if user is active user already, just update the entry
             // otherwise create it.
             eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
         
             if (objects.count == 0)
             {
            
             }
             else
             {
                 activeSession = (PFObject *)[objects objectAtIndex:0];                 
                 appDelegate.sessionID = activeSession[@"sessionID"];
                 appDelegate.subscriberToken = activeSession[@"subscriberToken"];
                 appDelegate.publisherToken = activeSession[@"publisherToken"];
                 appDelegate.callerTitle = activeSession[@"callerTitle"];
				 appDelegate.callerID = activeSession[@"callerID"];

				 //done with backend object, remove it.
                 [self setPollingTimer:NO];
                 [self deleteActiveSession];
                 
                 NSString *msg = [NSString stringWithFormat:@"incoming call from %@, accept?", appDelegate.callerTitle];
                 
                 UIAlertView *incomingCallAlert = [[UIAlertView alloc] initWithTitle:@"Edda" message:msg delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
                
                 incomingCallAlert.tag = kUIAlertViewTagIncomingCall;
                 [incomingCallAlert show];                 
             }
         }
         else
         {
             NSString * msg = [NSString stringWithFormat:@"Failed to retrieve active session for incoming call. Please try again. %@", [error localizedDescription]];
             [self showAlert:msg];
         }
     }];
}
@end
