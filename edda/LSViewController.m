//
//  LSViewController.m
//  LiveSessions
//
//  Created by Nirav Bhatt on 4/13/13.
//  Copyright (c) 2013 IPhoneGameZone. All rights reserved.
//

#define RANGE_IN_MILES 200.0
#import "LSViewController.h"

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
   // if (appDelegate.bFullyLoggedIn)
   //     [self fireNearUsersQuery:50.0 :appDelegate.currentLocation.coordinate :YES];
    // [m_userTableView reloadData];
}

//- (void) viewWillAppear:(BOOL)animated
//{
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didCallArrive) name:kIncomingCallNotification object:nil];
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showReceiverBusyMsg) name:kReceiverBusyNotification object:nil];//
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didLogin) name:kLoggedInNotification object:nil];
//}


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
    
    NSString * userTitle = [dict objectForKey:@"userTitle"];   
   
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil)
    {
        // Init new cell
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    //background view
    [cell setBackgroundColor:[UIColor clearColor]];    
   // [cell setBackgroundView:[[UIView alloc] init]];
   // UIImage * backImg = [UIImage imageNamed:@"cellrow.png"];
//    cell.backgroundView = [[UIImageView alloc] initWithImage:[ [UIImage imageNamed:@"cellrow.png"] stretchableImageWithLeftCapWidth:0.0 topCapHeight:5.0]];
    // cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.textLabel.text = userTitle;   
//    cell.textLabel.font = [UIFont fontWithName:@"Verdana" size:13];
    cell.contentView.backgroundColor = [UIColor clearColor];
 
 //   [cell.textLabel sizeToFit];    
     
    UIButton *videoCallButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    videoCallButton.frame = CGRectMake(cell.frame.size.width - 50, 10.0f, 40.0, 40.0f);
  //  videoCallButton.layer.borderColor = [UIColor redColor].CGColor;
  //  videoCallButton.layer.borderWidth = 3.5;
    videoCallButton.tag = indexPath.row;
   // [videoCallButton setTitle:@"Chat" forState:UIControlStateNormal];
    [videoCallButton addTarget:self action:@selector(startVideoChat:) forControlEvents:UIControlEventTouchUpInside];
//    [videoCallButton setBackgroundImage:[UIImage imageNamed:@"phonecall.png"] forState:UIControlStateNormal];
    [cell addSubview:videoCallButton];
    return cell;
}


//- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    NSMutableDictionary * dict = [m_userArray objectAtIndex:indexPath.row];
//    NSString * receiverID = [dict objectForKey:@"userID"];
//    m_receiverID = [receiverID copy];
//    [self goToStreamingVC];
//}

- (void) startVideoChat:(id) sender
{
    UIButton * button = (UIButton *)sender;
    
    if (button.tag < 0) //out of bounds
    {
        [ParseHelper showAlert:@"User is no longer online."];
        return;
    }
    
    NSMutableDictionary * dict = [m_userArray objectAtIndex:button.tag];
    NSString * receiverID = [dict objectForKey:@"userID"];
    m_receiverID = [receiverID copy];
    [self goToStreamingVC];
}

- (void) goToStreamingVC
{
    //[self presentModalViewController:streamingVC animated:YES];
    //
    [self performSegueWithIdentifier:@"StreamingSegue" sender:self];
}

-(void) prepareForSegue:(UIStoryboardPopoverSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"StreamingSegue"])
    {
        //  UIStoryboard * storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle:[NSBundle mainBundle]];
        
//        UINavigationController * navcontroller =  (UINavigationController *) segue.destinationViewController;
//        
//        LSStreamingViewController * streamingVC =  (LSStreamingViewController *)navcontroller.topViewController;
//        
//        streamingVC.callReceiverID = [m_receiverID copy];
//    
//        if (bAudioOnly)
//        {
//            streamingVC.bAudio = YES;
//            streamingVC.bVideo = NO;
//        }
//        else
//        {
//            streamingVC.bAudio = YES;
//            streamingVC.bVideo = YES;
//        }
    }
}

//if and when a call arrives
- (void) didCallArrive
{
    //pass blank because call has arrived, no need for receiverID.
    m_receiverID = @"";
    [self goToStreamingVC];
}

//called when user or location update is called
//so that paused location services can resume.
- (void) didUserLocSaved
{
}

//this method polls for new users that gets added / removed from surrounding region.
//distanceinMiles - range in Miles
//bRefreshUI - whether to refresh table UI
//argCoord - location around which to execute the search.
-(void) fireNearUsersQuery : (CLLocationDistance) distanceinMiles :(CLLocationCoordinate2D)argCoord :(bool)bRefreshUI
{
    CGFloat miles = distanceinMiles;
    NSLog(@"fireNearUsersQuery %f",miles);
    
    PFQuery *query = [PFQuery queryWithClassName:@"ActiveUsers"];
    [query setLimit:1000];
//    [query whereKey:@"userLocation"
//       nearGeoPoint:
//     [PFGeoPoint geoPointWithLatitude:argCoord.latitude longitude:argCoord.longitude] withinMiles:miles];    
	
    //deletee all existing rows,first from front end, then from data source. 
    [m_userArray removeAllObjects];
    [m_userTableView reloadData];    
    
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error)
    {
        if (!error)
        {
			int c = 0;
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
				
                NSMutableDictionary * dict = [NSMutableDictionary dictionary];
                [dict setObject:userID forKey:@"userID"];
                [dict setObject:userTitle forKey:@"userTitle"];
               
                // TODO: if reverse-geocoder is added, userLocation can be converted to
                // meaningful placemark info and user's address can be shown in table view.
                // [dict setObject:userTitle forKey:@"userLocation"];
                [m_userArray addObject:dict];
				
				PFGeoPoint * coordinate = [object valueForKey:@"userLocation"];
				CLLocation * location = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
				[self geocodeLocation:location forIndex:c];
				c++;
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
    CLLocationDistance d = RANGE_IN_MILES;
    //fetch users from 50 miles around.
    NSLog(@"%f %f", appDelegate.currentLocation.coordinate.latitude, appDelegate.currentLocation.coordinate.longitude);
    [self fireNearUsersQuery:d :appDelegate.currentLocation.coordinate :YES];
}


#pragma mark - Geocoding
- (void)geocodeLocation:(CLLocation*)location forIndex:(int)index
{
	if (!geocoder)
		geocoder = [[CLGeocoder alloc] init];
	
	[geocoder reverseGeocodeLocation:location completionHandler:
	 ^(NSArray* placemarks, NSError* error){
		 if ([placemarks count] > 0)
		 {
			 NSLog(@"found: %@", [[placemarks objectAtIndex:0] locality]);
			 NSString *title = [NSString stringWithFormat:@"%@",[[placemarks objectAtIndex:0] locality]];
			 [[m_userArray objectAtIndex:index] setObject:title forKey:@"userTitle"];
			 [m_userTableView reloadData];
		 }
	 }];
}

@end
