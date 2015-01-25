//
//  LSViewController.m
//  LiveSessions
//
//  Created by Nirav Bhatt on 4/13/13.
//  Copyright (c) 2013 IPhoneGameZone. All rights reserved.
//

#import "LSViewController.h"
#import "eddaMainViewController.h"
#import "eddaMapAnnotation.h"

//#import "KPAnnotation.h"
//#import "KPGridClusteringAlgorithm.h"
//#import "KPClusteringController.h"
//#import "KPGridClusteringAlgorithm_Private.h"

@interface LSViewController () // <KPClusteringControllerDelegate, KPClusteringControllerDelegate>

//@property (strong, nonatomic) KPClusteringController *clusteringController;

@end

@implementation LSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.mapView.delegate = self;
	self.mapView.showsPointsOfInterest = NO;
	
//	KPGridClusteringAlgorithm *algorithm = [KPGridClusteringAlgorithm new];
//	algorithm.annotationSize = CGSizeMake(25, 50);
//	algorithm.clusteringStrategy = KPGridClusteringAlgorithmStrategyTwoPhase;
//	self.clusteringController = [[KPClusteringController alloc] initWithMapView:self.mapView clusteringAlgorithm:algorithm];
//	self.clusteringController.delegate = self;

	m_userArray = [NSMutableArray array];
	m_annotationArray = [NSMutableArray array];
	
	self.appDelegate = (eddaAppDelegate*)[[UIApplication sharedApplication] delegate];
	
	m_userTableView.backgroundColor = [UIColor clearColor];
	[m_userTableView setSeparatorInset:UIEdgeInsetsZero];
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

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	// Remove seperator inset
	if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
		[cell setSeparatorInset:UIEdgeInsetsZero];
	}
	
	// Prevent the cell from inheriting the Table View's margin settings
	if ([cell respondsToSelector:@selector(setPreservesSuperviewLayoutMargins:)]) {
		[cell setPreservesSuperviewLayoutMargins:NO];
	}
	
	// Explictly set your cell's layout margins
	if ([cell respondsToSelector:@selector(setLayoutMargins:)]) {
		[cell setLayoutMargins:UIEdgeInsetsZero];
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSMutableDictionary * dict = [m_userArray objectAtIndex:indexPath.row];
    
    if (!dict)
        return nil;
    
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil)
    {
        // Init new cell
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
	
    //background view
    [cell setBackgroundColor:[UIColor blackColor]];

	cell.textLabel.backgroundColor = [UIColor clearColor];
	cell.textLabel.text = [dict objectForKey:@"userTitle"];
    cell.textLabel.font = [UIFont fontWithName:@"AvenirNextCondensed-Medium" size:24];
	cell.textLabel.textColor = [UIColor whiteColor];
	
	NSString *relativeDate = [self dateDiff:(NSDate *)[dict objectForKey:@"lastRequestAt"]];

	NSString * detailString = [NSString stringWithFormat:@"%@ — last active %@", [dict objectForKey:@"locality"], relativeDate];
	
	cell.detailTextLabel.text = detailString;
	cell.detailTextLabel.font = [UIFont fontWithName:@"AvenirNextCondensed-Medium" size:16];
	cell.detailTextLabel.textColor = [UIColor grayColor];
    cell.contentView.backgroundColor = [UIColor clearColor];
 
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self callUser:indexPath.row];
}

- (void)viewDidUnload {
    m_userTableView = nil;
    [super viewDidUnload];
}

- (IBAction)touchRefresh:(id)sender
{
    //fetch users from > 100 meters around.
    NSLog(@"%f %f", self.appDelegate.currentLocation.coordinate.latitude, self.appDelegate.currentLocation.coordinate.longitude);
	[self.mapView removeAnnotations:m_annotationArray];
    [self fireUsersQuery:YES];
}

#pragma mark - Call stuff

-(void)callUser:(NSInteger)index {
	NSMutableDictionary * dict = [m_userArray objectAtIndex:index];
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

#pragma mark - data and map stuff
//this method polls for new users that gets added / removed from surrounding region.
//distanceinMiles - range in Miles
//bRefreshUI - whether to refresh table UI
//argCoord - location around which to execute the search.
-(void) fireUsersQuery : (bool)bRefreshUI
{
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	
	//delete all existing rows,first from front end, then from data source.
	[m_userArray removeAllObjects];
	[m_annotationArray removeAllObjects];
	[m_userTableView reloadData];
	
	@weakify(self);
	[QBRequest usersForPage:[QBGeneralResponsePage responsePageWithCurrentPage:0 perPage:100] successBlock:^(QBResponse *response, QBGeneralResponsePage *page, NSArray *arrayOfUsers) {
		@strongify(self);
		
		// sort users
		NSMutableArray *sortedArray = [[NSMutableArray alloc] initWithCapacity:arrayOfUsers.count];
		
		for (QBUUser *object in arrayOfUsers) {
			NSString *userID = [NSString stringWithFormat:@"%lu",(unsigned long)object.ID];
			
			if (object.ID == self.appDelegate.loggedInUser.ID) {
				//				NSLog(@"skipping - current user");
				continue;
			}
			
			if (object.customData == nil) {
				// not found
				continue;
			}
			
			NSDictionary *custom = [QBHelper QBCustomDataToObject:object.customData];
			
			// create
			QBLGeoData *coordinate = [QBLGeoData geoData];
			
			// place coordinates
			coordinate.latitude = [[custom valueForKey:@"latitude"] doubleValue];
			coordinate.longitude = [[custom valueForKey:@"longitude"] doubleValue];
			
			NSNumber *userAltitude = [custom valueForKey:@"altitude"];
			
			NSString *qbname = [custom valueForKey:@"username"];
			
			NSString *userTitle;
			
			if (qbname != nil) {
				userTitle = [QBHelper decodeUsername:qbname];
			} else {
				userTitle = @"old Edda version";
			}
			
			NSNumber *privacy = [custom valueForKey:@"privacy"];
			
			if (privacy == nil) {
				privacy = [NSNumber numberWithBool:NO];
			}
			
			NSMutableDictionary * dict = [NSMutableDictionary dictionary];
			[dict setObject:userID forKey:@"userID"];
			[dict setObject:userTitle forKey:@"userTitle"];
			[dict setObject:coordinate forKey:@"userLocation"];
			[dict setObject:@"Locating…" forKey:@"locality"];
			[dict setObject:userAltitude forKey:@"userAltitude"];
			[dict setObject:privacy forKey:@"privacy"];
			[dict setObject:object.lastRequestAt forKey:@"lastRequestAt"];
			
			[sortedArray addObject:dict];
		}
		
		NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"lastRequestAt" ascending:NO];
		NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
		[sortedArray sortUsingDescriptors:sortDescriptors];
		
		int index = 0;

		for (NSMutableDictionary *object in sortedArray) {
			//skip if private
			NSNumber *private = [object valueForKey:@"privacy"];
			if (private.boolValue) {
				continue;
			}
			
			QBLGeoData *coordinate = (QBLGeoData *)[object valueForKey:@"userLocation"];
			
			[m_userArray addObject:object];
			
			CLLocation * location = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
			[self geocodeLocation:location forIndex:index];
			
			NSString *relativeDate = [self dateDiff:(NSDate *)[object objectForKey:@"lastRequestAt"]];
			NSString * detailString = [NSString stringWithFormat:@"Active %@", relativeDate];

			eddaMapAnnotation *annotation = [[eddaMapAnnotation alloc] init];
			annotation.coordinate = CLLocationCoordinate2DMake(coordinate.latitude, coordinate.longitude);
			annotation.title = [object valueForKey:@"userTitle"];
			annotation.subtitle = detailString;
			annotation.index = index;

			[m_annotationArray addObject:annotation];
			
			index++;
		}
		
		//when done, refresh the table view
		if (bRefreshUI)
		{
			[m_userTableView reloadData];
			[self.mapView showAnnotations:m_annotationArray animated:YES];
		}
		
		[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	} errorBlock:^(QBResponse *response) {
		NSLog(@"Errors = %@", response.error);
		[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	}];
	
}

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

- (NSString *)dateDiff:(NSDate *)convertedDate {
	NSDateFormatter *df = [[NSDateFormatter alloc] init];
	[df setFormatterBehavior:NSDateFormatterBehavior10_4];
	[df setDateFormat:@"EEE, dd MMM yy HH:mm:ss VVVV"];
	NSDate *todayDate = [NSDate date];
	double ti = [convertedDate timeIntervalSinceDate:todayDate];
	ti = ti * -1;
	if(ti < 1) {
		return @"never";
	} else 	if (ti < 60) {
		return @"less than a minute ago";
	} else if (ti < 3600) {
		int diff = round(ti / 60);
		return [NSString stringWithFormat:@"%d minutes ago", diff];
	} else if (ti < 86400) {
		int diff = round(ti / 60 / 60);
		return[NSString stringWithFormat:@"%d hours ago", diff];
	} else if (ti < 2629743) {
		int diff = round(ti / 60 / 60 / 24);
		return[NSString stringWithFormat:@"%d days ago", diff];
	} else {
		return @"never";
	}
}

#pragma mark - MapView and Clustering

-(void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control {
	id <MKAnnotation> annotation = [view annotation];
	if ([annotation isKindOfClass:[eddaMapAnnotation class]])
	{
		eddaMapAnnotation *eddaPin = (eddaMapAnnotation *)annotation;
		[self callUser:eddaPin.index];
	}
}

//- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view {
//	if ([view.annotation isKindOfClass:[KPAnnotation class]]) {
//		
//		KPAnnotation *cluster = (KPAnnotation *)view.annotation;
//		
//		if (cluster.annotations.count > 1){
//			[self.mapView setRegion:MKCoordinateRegionMakeWithDistance(cluster.coordinate,
//																	   cluster.radius * 2.5f,
//																	   cluster.radius * 2.5f)
//						   animated:YES];
//		}
//	}
//}

//- (void)clusteringController:(KPClusteringController *)clusteringController configureAnnotationForDisplay:(KPAnnotation *)annotation {
////	annotation.title = [NSString stringWithFormat:@"%lu custom annotations", (unsigned long)annotation.annotations.count];
//	annotation.subtitle = [NSString stringWithFormat:@"%.0f meters", annotation.radius];
//}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
	// If it's the user location, just return nil.
	if ([annotation isKindOfClass:[MKUserLocation class]])
		return nil;
	// Handle any custom annotations.
	if ([annotation isKindOfClass:[eddaMapAnnotation class]])
	{
		// Try to dequeue an existing pin view first.
		MKPinAnnotationView *annotationView = (MKPinAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:@"pin"];
		if (!annotationView)
		{
			// If an existing pin view was not available, create one.
			annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"pin"];
			
			UIButton* rightButton = [UIButton buttonWithType:UIButtonTypeCustom];
			rightButton.frame = CGRectMake(0, 0, 30, 26);
			[rightButton setImage:[UIImage imageNamed:@"CallIcon"] forState:UIControlStateNormal];
			
			annotationView.rightCalloutAccessoryView = rightButton;
			annotationView.pinColor = MKPinAnnotationColorRed;
			annotationView.annotation = annotation;
			annotationView.canShowCallout = YES;
			annotationView.animatesDrop = YES;
		} else {
			annotationView.annotation = annotation;
		}
		return annotationView;
	}

//	// Handle any custom annotations.
//	if ([annotation isKindOfClass:[KPAnnotation class]])
//	{
//		KPAnnotation *kingpinAnnotation = (KPAnnotation *)annotation;
//		if ([kingpinAnnotation isCluster]) {
//			annotationView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"cluster"];
//			
//			if (annotationView == nil) {
//				annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:kingpinAnnotation reuseIdentifier:@"cluster"];
//			}
//			
//			annotationView.pinColor = MKPinAnnotationColorGreen;
//		} else {
//			annotationView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"pin"];
//			
//			if (annotationView == nil) {
//				annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:[kingpinAnnotation.annotations anyObject] reuseIdentifier:@"pin"];
//			}
//			
//			NSLog(@"pin: %@", annotation);
//			
//			// Add a detail disclosure button to the callout.
//			UIButton* rightButton = [UIButton buttonWithType:UIButtonTypeCustom];
//			rightButton.frame = CGRectMake(0, 0, 30, 26);
//			[rightButton setImage:[UIImage imageNamed:@"CallIcon"] forState:UIControlStateNormal];
//
//			annotationView.rightCalloutAccessoryView = rightButton;
//			annotationView.pinColor = MKPinAnnotationColorRed;
//			annotationView.annotation = annotation;
//			annotationView.canShowCallout = YES;
//			annotationView.animatesDrop = YES;
//		}
//		
//		return annotationView;
//	}
	return nil;
}

//- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
//	[self.clusteringController refresh:YES];
//}
//
//- (BOOL)clusteringControllerShouldClusterAnnotations:(KPClusteringController *)clusteringController {
//	return YES;
//}
//
//- (void)clusteringControllerWillUpdateVisibleAnnotations:(KPClusteringController *)clusteringController {
////	NSLog(@"Clustering controller %@ will update visible annotations", clusteringController);
//}
//
//- (void)clusteringControllerDidUpdateVisibleMapAnnotations:(KPClusteringController *)clusteringController {
////	NSLog(@"Clustering controller %@ did update visible annotations", clusteringController);
//}

@end
