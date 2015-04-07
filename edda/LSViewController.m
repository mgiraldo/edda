//
//  LSViewController.m
//  LiveSessions
//
//  Created by Mauricio Giraldo on 29/1/15.
//  Copyright (c) 2015 Ping Pong Estudio. All rights reserved.
//

#define kUIAlertViewTagPassword 100

#import "LSViewController.h"
#import "eddaMainViewController.h"
#import "eddaMapAnnotation.h"
#import "eddaClusterAnnotationView.h"
#import "MKMapView+ZoomLevel.h"

#import "KPAnnotation.h"
#import "KPGridClusteringAlgorithm.h"
#import "KPClusteringController.h"
#import "KPGridClusteringAlgorithm_Private.h"

@interface LSViewController () <KPClusteringControllerDelegate, KPClusteringControllerDelegate>

@property (strong, nonatomic) KPClusteringController *clusteringController;

@end

@implementation LSViewController

static int _maxZoom = 10;

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	m_refreshControl = [[UIRefreshControl alloc] init];
	[m_userTableView addSubview:m_refreshControl];
	[m_refreshControl addTarget:self action:@selector(refreshView) forControlEvents:UIControlEventValueChanged];
	
	self.mapView.delegate = self;
	self.mapView.showsPointsOfInterest = NO;
	
	KPGridClusteringAlgorithm *algorithm = [KPGridClusteringAlgorithm new];
	algorithm.gridSize = CGSizeMake(5, 5);
	algorithm.annotationSize = CGSizeMake(50, 50);
	algorithm.clusteringStrategy = KPGridClusteringAlgorithmStrategyTwoPhase;
	self.clusteringController = [[KPClusteringController alloc] initWithMapView:self.mapView clusteringAlgorithm:algorithm];
	self.clusteringController.delegate = self;
	self.clusteringController.animationOptions = UIViewAnimationOptionCurveEaseOut;

	m_userArray = [NSMutableArray array];
	m_annotationArray = [NSMutableArray array];
	
	self.appDelegate = (eddaAppDelegate*)[[UIApplication sharedApplication] delegate];
	
	m_userTableView.backgroundColor = [UIColor clearColor];
	m_userTableView.separatorColor = [UIColor darkGrayColor];
	m_userTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	[m_userTableView setSeparatorInset:UIEdgeInsetsZero];
	
	// blur
	
	CAGradientLayer* maskLayer = [CAGradientLayer layer];
	
	maskLayer.bounds = CGRectMake(0, 0,
								  self.view.frame.size.width,
								  self.mapView.frame.size.height);
	
	CGColorRef outerColor = [UIColor colorWithWhite:0.0 alpha:1.0].CGColor;
	CGColorRef innerColor = [UIColor colorWithWhite:0.5 alpha:0.0].CGColor;
	
	maskLayer.colors = [NSArray arrayWithObjects:(__bridge id)outerColor,
						(__bridge id)innerColor, (__bridge id)innerColor, nil];
	
	maskLayer.locations = [NSArray arrayWithObjects:[NSNumber numberWithFloat:0.0],
						   [NSNumber numberWithFloat:0.1],
						   [NSNumber numberWithFloat:1.0], nil];
	
	maskLayer.anchorPoint = CGPointZero;
	
	[self.mapView.layer addSublayer:maskLayer];
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
	cell.backgroundColor = [UIColor blackColor];

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
	m_selectedIndex = indexPath.row;
	if ([[[m_userArray objectAtIndex:m_selectedIndex] valueForKey:@"password"] isEqualToString:@""]) {
		// all cool... just call
		[self callUser:m_selectedIndex];
	} else {
		[self promptPassword];
	}
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)viewDidUnload {
    m_userTableView = nil;
    [super viewDidUnload];
}

- (IBAction)touchRefresh:(id)sender
{
	[self refreshView];
}

- (IBAction)touchPrivateCall:(id)sender {
}

- (void)refreshView {
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
-(void) fireUsersQuery : (BOOL)bRefreshUI
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

			NSString *qbpassword = [custom valueForKey:@"password"];

			NSString *userTitle, *userPassword;
			
			if (qbname != nil) {
				userTitle = [QBHelper decodeText:qbname];
			} else {
				userTitle = @"old Edda version";
			}
			
			if (qbpassword != nil) {
				userPassword = [QBHelper decodeText:qbpassword];
			} else {
				userPassword = @"";
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
			[dict setObject:userPassword forKey:@"password"];
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
			[m_refreshControl endRefreshing];
			[m_userTableView reloadData];
			[self.clusteringController setAnnotations:m_annotationArray];
			
			MKCoordinateRegion region = [self regionFromLocations];
			[self.mapView setRegion:region animated:YES];
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
		int diff = round(ti / 604800);
		return[NSString stringWithFormat:@"%d weeks ago", diff];
	}
}

#pragma mark - Password Stuff

- (void)promptPassword {
	self.passwordRequiredMsg = [[UIAlertView alloc]
								initWithTitle:@"🔒 What's the secret phrase?"
								message:nil
								delegate:self
								cancelButtonTitle:@"Cancel"
								otherButtonTitles:@"Call", nil];
	
	self.passwordRequiredMsg.tag = kUIAlertViewTagPassword;
	self.passwordRequiredMsg.alertViewStyle = UIAlertViewStylePlainTextInput;
	[self.passwordRequiredMsg textFieldAtIndex:0].delegate = self;
	[self.passwordRequiredMsg show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if(kUIAlertViewTagPassword == alertView.tag && buttonIndex != [alertView cancelButtonIndex]) {
		UITextField *password = [alertView textFieldAtIndex:0];
		if ([[[m_userArray objectAtIndex:m_selectedIndex] valueForKey:@"password"] isEqualToString:password.text]) {
			// all cool... just call
			[self callUser:m_selectedIndex];
		}
	}
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	// Dismiss keyboard when return key is pressed
	[self.passwordRequiredMsg dismissWithClickedButtonIndex:self.passwordRequiredMsg.firstOtherButtonIndex animated:YES];
	return YES;
}

#pragma mark - MapView and Clustering

- (MKCoordinateRegion)regionFromLocations {
	CLLocationCoordinate2D upper = [[m_annotationArray objectAtIndex:0] coordinate];
	CLLocationCoordinate2D lower = [[m_annotationArray objectAtIndex:0] coordinate];
	
	// FIND LIMITS
	for(eddaMapAnnotation *eachLocation in m_annotationArray) {
		if([eachLocation coordinate].latitude > upper.latitude) upper.latitude = [eachLocation coordinate].latitude;
		if([eachLocation coordinate].latitude < lower.latitude) lower.latitude = [eachLocation coordinate].latitude;
		if([eachLocation coordinate].longitude > upper.longitude) upper.longitude = [eachLocation coordinate].longitude;
		if([eachLocation coordinate].longitude < lower.longitude) lower.longitude = [eachLocation coordinate].longitude;
	}
	
	// FIND REGION
	MKCoordinateSpan locationSpan;
	locationSpan.latitudeDelta = upper.latitude - lower.latitude;
	locationSpan.longitudeDelta = upper.longitude - lower.longitude;
	CLLocationCoordinate2D locationCenter;
	locationCenter.latitude = (upper.latitude + lower.latitude) / 2;
	locationCenter.longitude = (upper.longitude + lower.longitude) / 2;
	
	MKCoordinateRegion region = MKCoordinateRegionMake(locationCenter, locationSpan);
	return region;
}

-(void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control {
	if ([view.annotation isKindOfClass:[KPAnnotation class]]) {
		KPAnnotation *cluster = (KPAnnotation *)view.annotation;
		if (cluster.annotations.count == 1){
			eddaMapAnnotation * myAnnotation = (eddaMapAnnotation *)[cluster.annotations anyObject];
			m_selectedIndex = myAnnotation.index;
			if ([[[m_userArray objectAtIndex:m_selectedIndex] valueForKey:@"password"] isEqualToString:@""]) {
				// all cool... just call
				[self callUser:m_selectedIndex];
			} else {
				[self promptPassword];
			}
		}
	}
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view {
	if ([view.annotation isKindOfClass:[KPAnnotation class]]) {
		KPAnnotation *cluster = (KPAnnotation *)view.annotation;
		if (cluster.annotations.count > 1){
			[self.mapView setRegion:MKCoordinateRegionMakeWithDistance(cluster.coordinate,
																	   cluster.radius * 2.5f,
																	   cluster.radius * 2.5f)
						   animated:YES];
		}
	}
}

- (void)clusteringController:(KPClusteringController *)clusteringController configureAnnotationForDisplay:(KPAnnotation *)annotation {
	if (!annotation.isCluster) {
		eddaMapAnnotation * myAnnotation = (eddaMapAnnotation *)[annotation.annotations anyObject];
		annotation.title = myAnnotation.title;
		annotation.subtitle = myAnnotation.subtitle;
	}
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
	// If it's the user location, just return nil.
	if ([annotation isKindOfClass:[MKUserLocation class]])
		return nil;

	// Handle any custom annotations.
	if ([annotation isKindOfClass:[KPAnnotation class]])
	{
		KPAnnotation *kingpinAnnotation = (KPAnnotation *)annotation;
		if ([kingpinAnnotation isCluster]) {
			eddaClusterAnnotationView *annotationView = nil;
			
			annotationView = (eddaClusterAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"cluster"];
			
			if (annotationView == nil) {
				annotationView = [[eddaClusterAnnotationView alloc] initWithAnnotation:kingpinAnnotation reuseIdentifier:@"cluster"];
			}
			
			NSString *text;

			if (kingpinAnnotation.annotations.count < 10) {
				text = [NSString stringWithFormat:@"%lu", (unsigned long)kingpinAnnotation.annotations.count];
			} else {
				text = @"10+";
			}
			
			[annotationView setClusterText:text];
			
			return annotationView;
		} else {
			MKPinAnnotationView *annotationView = nil;
			
			annotationView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"pin"];
			
			eddaMapAnnotation * myAnnotation = (eddaMapAnnotation *)[kingpinAnnotation.annotations anyObject];
			
			if (annotationView == nil) {
				annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:myAnnotation reuseIdentifier:@"pin"];
			}
			
			UIButton* rightButton = [UIButton buttonWithType:UIButtonTypeCustom];
			rightButton.frame = CGRectMake(0, 0, 26, 27);
			[rightButton setImage:[UIImage imageNamed:@"call.png"] forState:UIControlStateNormal];
			
			annotationView.rightCalloutAccessoryView = rightButton;
			annotationView.pinColor = MKPinAnnotationColorRed;
			annotationView.annotation = annotation;
			annotationView.canShowCallout = YES;
			annotationView.animatesDrop = NO;
			
			return annotationView;
		}
	}
	return nil;
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
	unsigned long zoom = mapView.zoomLevel;
//	NSLog(@"change zoom: %lu", zoom);
	if (zoom > _maxZoom) {
		[mapView setCenterCoordinate:mapView.centerCoordinate zoomLevel:_maxZoom animated:YES];
	}
	[self.clusteringController refresh:YES];
}

- (BOOL)clusteringControllerShouldClusterAnnotations:(KPClusteringController *)clusteringController {
	return self.mapView.zoomLevel <= _maxZoom; // Find zoom level that suits your dataset
}

- (void)clusteringControllerWillUpdateVisibleAnnotations:(KPClusteringController *)clusteringController {
//	NSLog(@"Clustering controller %@ will update visible annotations", clusteringController);
}

- (void)clusteringControllerDidUpdateVisibleMapAnnotations:(KPClusteringController *)clusteringController {
//	NSLog(@"Clustering controller %@ did update visible annotations", clusteringController);
}

@end
