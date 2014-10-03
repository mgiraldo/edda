//
//  LSViewController.m
//  LiveSessions
//
//  Created by Nirav Bhatt on 4/13/13.
//  Copyright (c) 2013 IPhoneGameZone. All rights reserved.
//

#import "LSViewController.h"
#import "eddaMainViewController.h"

@interface LSViewController ()

@end

@implementation LSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
  
    
    m_userArray = [NSMutableArray array];
    appDelegate = [[UIApplication sharedApplication] delegate];
    m_userTableView.backgroundColor = [UIColor clearColor];
}

- (void) viewDidAppear:(BOOL)animated
{
    if (appDelegate.bFullyLoggedIn)
        [self fireUsersQuery:YES];
     [m_userTableView reloadData];
}

- (void) viewWillAppear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didCallArrive) name:kIncomingCallNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showReceiverBusyMsg) name:kReceiverBusyNotification object:nil];//
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didLogin) name:kLoggedInNotification object:nil];
}

- (BOOL)prefersStatusBarHidden {
	return YES;
}

-(void) showReceiverBusyMsg
{
	NSLog(@"Receiver is busy on another call. Please try later.");
}

- (void) didLogin
{
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [m_userArray count];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSMutableDictionary * dict = [m_userArray objectAtIndex:indexPath.row];
    
    if (!dict)
        return nil;
    
    NSString * userTitle = [NSString stringWithFormat:@"%@, %@",[dict objectForKey:@"userTitle"],[dict objectForKey:@"locality"]];
   
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil)
    {
        // Init new cell
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    //background view
    [cell setBackgroundColor:[UIColor clearColor]];    
    
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.textLabel.text = userTitle;   
//    cell.textLabel.font = [UIFont fontWithName:@"Verdana" size:13];
    cell.contentView.backgroundColor = [UIColor clearColor];
 
 //   [cell.textLabel sizeToFit];    
     
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSMutableDictionary * dict = [m_userArray objectAtIndex:indexPath.row];
	NSString * receiverID = [dict objectForKey:@"userID"];
	NSString * receiverTitle = [dict objectForKey:@"userTitle"];
	NSNumber * receiverAltitude = [dict objectForKey:@"userAltitude"];

	PFGeoPoint *coordinate = [dict valueForKey:@"userLocation"];
	CLLocation *location = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];

	m_receiverID = [receiverID copy];
	m_receiverTitle = [receiverTitle copy];
	m_receiverLocation = [location copy];
	m_receiverAltitude = [receiverAltitude copy];

	appDelegate.callReceiverID = m_receiverID;
	appDelegate.callReceiverTitle = m_receiverTitle;
	appDelegate.callReceiverLocation = m_receiverLocation;
	appDelegate.callReceiverAltitude = m_receiverAltitude;
	[self goToStreamingVC];
}

//if and when a call arrives
- (void) didCallArrive
{
    //pass blank because call has arrived, no need for receiverID.
	[self clearReceiver];
    [self goToStreamingVC];
}

- (void) goToStreamingVC {
	[self performSegueWithIdentifier:@"unwindToVideoChatID" sender:self];
}

- (void)clearReceiver {
	m_receiverID = @"";
	m_receiverTitle = @"";
	m_receiverLocation = nil;
	m_receiverAltitude = 0;
	appDelegate.callReceiverID = m_receiverID;
	appDelegate.callReceiverTitle = m_receiverTitle;
	appDelegate.callReceiverLocation = m_receiverLocation;
	appDelegate.callReceiverAltitude = m_receiverAltitude;
}

//this method polls for new users that gets added / removed from surrounding region.
//distanceinMiles - range in Miles
//bRefreshUI - whether to refresh table UI
//argCoord - location around which to execute the search.
-(void) fireUsersQuery : (bool)bRefreshUI
{
    NSLog(@"fireNearUsersQuery");
    
    PFQuery *query = [PFQuery queryWithClassName:@"ActiveUsers"];
    [query setLimit:1000];
	
    //deletee all existing rows,first from front end, then from data source. 
    [m_userArray removeAllObjects];
    [m_userTableView reloadData];    
    
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error)
    {
        if (!error)
        {
			int index = 0;
            for (PFObject *object in objects)
            {
                //if for this user, skip it.
                NSString *userID = [object valueForKey:@"userID"];
                NSString *currentuser = [ParseHelper loggedInUser].objectId;
                NSLog(@"userid: %@",userID);
                NSLog(@"current: %@",currentuser);
                
                if ([userID isEqualToString:currentuser])
                {
                    NSLog(@"skipping - current user");
                    continue;
                }
                
                NSString *userTitle = [object valueForKey:@"userTitle"];
				PFGeoPoint *coordinate = [object valueForKey:@"userLocation"];
				NSNumber *userAltitude = [object valueForKey:@"userAltitude"];
				
                NSMutableDictionary * dict = [NSMutableDictionary dictionary];
                [dict setObject:userID forKey:@"userID"];
                [dict setObject:userTitle forKey:@"userTitle"];
				[dict setObject:coordinate forKey:@"userLocation"];
				[dict setObject:@"Locating…" forKey:@"locality"];
				[dict setObject:userAltitude forKey:@"userAltitude"];
				
                // TODO: if reverse-geocoder is added, userLocation can be converted to
                // meaningful placemark info and user's address can be shown in table view.
                // [dict setObject:userTitle forKey:@"userLocation"];
                [m_userArray addObject:dict];
				
				CLLocation * location = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
				[self geocodeLocation:location forIndex:index];
				index++;
			}
            
            //when done, refresh the table view
            if (bRefreshUI)
            {
                [m_userTableView reloadData];
            }
        }
        else
        {
            NSLog(@"error: %@",[error description]);
        }
    }];
}

- (void)viewDidUnload {
    m_userTableView = nil;
    [super viewDidUnload];
}

- (IBAction)touchRefresh:(id)sender
{
    //fetch users from 50 miles around.
    NSLog(@"%f %f", appDelegate.currentLocation.coordinate.latitude, appDelegate.currentLocation.coordinate.longitude);
    [self fireUsersQuery:YES];
}

#pragma mark - Geocoding
- (void)geocodeLocation:(CLLocation*)location forIndex:(int)index
{
	CLGeocoder *geocoder = [[CLGeocoder alloc] init];
	
	[geocoder reverseGeocodeLocation:location completionHandler:
	 ^(NSArray* placemarks, NSError* error){
		 if ([placemarks count] > 0)
		 {
			 NSLog(@"found: %@", [[placemarks objectAtIndex:0] locality]);
			 NSString *locality = [NSString stringWithFormat:@"%@",[[placemarks objectAtIndex:0] locality]];
			 [[m_userArray objectAtIndex:index] setObject:locality forKey:@"locality"];
			 [m_userTableView reloadData];
		 }
	 }];
}

@end
