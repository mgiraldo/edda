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
    self.appDelegate = (eddaAppDelegate*)[[UIApplication sharedApplication] delegate];
    m_userTableView.backgroundColor = [UIColor clearColor];
}

- (void) viewDidAppear:(BOOL)animated
{
    if (self.appDelegate.bFullyLoggedIn)
        [self fireUsersQuery:YES];
     [m_userTableView reloadData];
}

- (void) viewWillAppear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didCallArrive) name:kIncomingCallNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showReceiverBusyMsg) name:kReceiverBusyNotification object:nil];//
}

- (BOOL)prefersStatusBarHidden {
	return YES;
}

-(void) showReceiverBusyMsg
{
	NSLog(@"Receiver is busy on another call. Please try later.");
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
	NSNumber * receiverID = [dict objectForKey:@"userID"];
	NSString * receiverTitle = [dict objectForKey:@"userTitle"];
	NSNumber * receiverAltitude = [dict objectForKey:@"userAltitude"];

	QBLGeoData *coordinate = [dict valueForKey:@"userLocation"];
	CLLocation *location = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];

	m_receiverID = [receiverID copy];
	m_receiverTitle = [receiverTitle copy];
	m_receiverLocation = [location copy];
	m_receiverAltitude = [receiverAltitude copy];

	self.appDelegate.callReceiverID = m_receiverID;
	self.appDelegate.callReceiverTitle = m_receiverTitle;
	self.appDelegate.callReceiverLocation = m_receiverLocation;
	self.appDelegate.callReceiverAltitude = m_receiverAltitude;
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
	m_receiverID = nil;
	m_receiverTitle = @"";
	m_receiverLocation = nil;
	m_receiverAltitude = 0;
	self.appDelegate.callReceiverID = m_receiverID;
	self.appDelegate.callReceiverTitle = m_receiverTitle;
	self.appDelegate.callReceiverLocation = m_receiverLocation;
	self.appDelegate.callReceiverAltitude = m_receiverAltitude;
}

//this method polls for new users that gets added / removed from surrounding region.
//distanceinMiles - range in Miles
//bRefreshUI - whether to refresh table UI
//argCoord - location around which to execute the search.
-(void) fireUsersQuery : (bool)bRefreshUI
{
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];

	// TODO: add user distance limit to > 100m
	
    //delete all existing rows,first from front end, then from data source.
    [m_userArray removeAllObjects];
    [m_userTableView reloadData];    
    
	[QBRequest usersForPage:[QBGeneralResponsePage responsePageWithCurrentPage:0 perPage:100] successBlock:^(QBResponse *response, QBGeneralResponsePage *page, NSArray *arrayOfUsers) {
		int index = 0;
		for (QBUUser *object in arrayOfUsers) {
			//if for this user, skip it.
			NSString *userID = [NSString stringWithFormat:@"%lu",(unsigned long)object.ID];
			NSString *currentuser = [NSString stringWithFormat:@"%lu",(unsigned long)self.appDelegate.loggedInUser.ID];
//			NSLog(@"userid: %@",userID);
//			NSLog(@"current: %@",currentuser);
			
			if ([userID isEqualToString:currentuser]) {
//				NSLog(@"skipping - current user");
				continue;
			}
			
			NSRange underscore = [object.login rangeOfString:@"_" options:NSBackwardsSearch];
			
			if (underscore.length==0 || object.customData == nil) {
				// not found
//				NSLog(@"skipping - no underscore");
				continue;
			}
			
			NSString *userTitle = [object.login substringToIndex:underscore.location];
			NSDictionary *custom = [QBHelper QBCustomDataToObject:object.customData];
			
			// create
			QBLGeoData *coordinate = [QBLGeoData geoData];
			
			// place coordinates
			coordinate.latitude = [[custom valueForKey:@"latitude"] doubleValue];
			coordinate.longitude = [[custom valueForKey:@"longitude"] doubleValue];

			NSNumber *userAltitude = [custom valueForKey:@"altitude"];
			
			NSMutableDictionary * dict = [NSMutableDictionary dictionary];
			[dict setObject:userID forKey:@"userID"];
			[dict setObject:userTitle forKey:@"userTitle"];
			[dict setObject:coordinate forKey:@"userLocation"];
			[dict setObject:@"Locating…" forKey:@"locality"];
			[dict setObject:userAltitude forKey:@"userAltitude"];
			
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

		[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	} errorBlock:^(QBResponse *response) {
		NSLog(@"Errors = %@", response.error);
		[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	}];

}

- (void)viewDidUnload {
    m_userTableView = nil;
    [super viewDidUnload];
}

- (IBAction)touchRefresh:(id)sender
{
    //fetch users from > 100 meters around.
    NSLog(@"%f %f", self.appDelegate.currentLocation.coordinate.latitude, self.appDelegate.currentLocation.coordinate.longitude);
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
//			 NSLog(@"found: %@", [[placemarks objectAtIndex:0] locality]);
			 NSString *locality = [NSString stringWithFormat:@"%@",[[placemarks objectAtIndex:0] locality]];
			 [[m_userArray objectAtIndex:index] setObject:locality forKey:@"locality"];
			 [m_userTableView reloadData];
		 }
	 }];
}

@end
