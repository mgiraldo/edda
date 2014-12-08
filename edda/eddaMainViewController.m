//
//  eddaMainViewController.m
//  edda
//
//  Created by Mauricio Giraldo on 28/8/14.
//  Copyright (c) 2014 Ping Pong Estudio. All rights reserved.
//

#import <Accelerate/Accelerate.h>
#import <ImageIO/ImageIO.h>
#import "eddaAppDelegate.h"
#import "eddaMainViewController.h"
#import "LSViewController.h"
#import "geodesic.h"
#import "utils.h"

@interface eddaMainViewController ()

@property (strong, nonatomic) NSMutableSet *disconnectListeners;

@end

@implementation eddaMainViewController {
	int m_mode;
	int m_connectionAttempts;
	NSNumber * m_receiverID;
	eddaAppDelegate *appDelegate;
	NSDate *alignedTimerStart;
}

// self preview size
float _previewWidth = 60;
float _previewHeight = 90;

CLLocationManager *locationManager;
CMMotionManager *motionManager;

BOOL _videoActive = YES;
BOOL _rearVideoInited = NO;
BOOL _haveArrows = NO;
BOOL _isChatting = NO;
BOOL _isAligned = NO;

float _timeToWaitForAlignment = 10.0f;

float _headingThreshold = 20.0f;
float _pitchThreshold = 10.0f;

NSArray *_places;
NSArray *_placeCoordinates;

// proj4
projPJ pj_geoc;
projPJ pj_geod;

double _fromLat = 0.0;
double _fromLon = 0.0;
double _fromAlt = 0.0;

double _toLat = 0.0;
double _toLon = 0.0;
double _toAlt = 0.0;

sViewAngle viewAngle;

// arrows
float _arrowSize = 15.0f;
float _arrowMargin = 5.0f;

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	appDelegate = [[UIApplication sharedApplication] delegate];

	// other view
	self.otherView = [[eddaOtherView alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
	self.otherView.hidden = YES;
	self.otherView.delegate = self;
	[self.view addSubview:self.otherView];

	UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(resignOnTap:)];
    [singleTap setNumberOfTapsRequired:1];
    [singleTap setNumberOfTouchesRequired:1];
    [self.view addGestureRecognizer:singleTap];
	
	// init motion manager
	motionManager = [[CMMotionManager alloc] init];
	NSTimeInterval updateInterval = 0.015;
	
	eddaMainViewController * __weak weakSelf = self;
	
	if ([motionManager isDeviceMotionAvailable] == YES) {
		[motionManager setDeviceMotionUpdateInterval:updateInterval];
		[motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion *deviceMotion, NSError *error) {
			// attitude
			weakSelf.currentMotion = deviceMotion;
		}];
	}

	// init location manager
	locationManager = [[CLLocationManager alloc] init];
	locationManager.delegate = self;
	locationManager.desiredAccuracy = kCLLocationAccuracyBest;

	// now get the location

	// init Proj.4 params
	if (!(pj_geod = pj_init_plus("+proj=latlong +datum=WGS84 +units=m")) )
        NSLog(@"Could not initialise MERCATOR");
	if (!(pj_geoc = pj_init_plus("+proj=geocent +datum=WGS84")) )
        NSLog(@"Could not initialise CARTESIAN");
}

- (void)viewDidUnload
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super viewDidUnload];
}

- (void) viewWillAppear:(BOOL)animated
{
	[self registerNotifs];
}

- (void) viewDidAppear:(BOOL)animated
{
	[self refreshVideoFeeds];
	[super viewDidAppear:animated];
}

- (void) viewDidLayoutSubviews {
	[self setupArrows];
	[self hideArrows];
	[self.view layoutSubviews];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden {
	return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	NSLog(@"prepare for segue: [%@] sender: [%@]", [segue identifier], sender);
	if ([[segue identifier] isEqualToString:@"showAlternate"]) {
		[[segue destinationViewController] setDelegate:self];
	} else if ([[segue identifier] isEqualToString:@"showList"]) {
		[[segue destinationViewController] setDelegate:self];
	}
}

#pragma mark - Startup

- (void) userHasLoggedIn
{
	// iOS 8 not authorized by default
	if([locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
		[locationManager requestWhenInUseAuthorization];
	}
	
	[locationManager startUpdatingLocation];
	[locationManager startUpdatingHeading];

	// interface refresh timer
	[NSTimer scheduledTimerWithTimeInterval:0.1
									 target:self
								   selector:@selector(updateInterface:)
								   userInfo:nil
									repeats:YES];
	
	[self updateViewAngle];
}

- (void) registerNotifs
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionSaved) name:kSessionSavedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didCallArrive) name:kIncomingCallNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showReceiverBusyMsg) name:kReceiverBusyNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didLogin) name:kLoggedInNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didCallCancel) name:kCallCancelledNotification object:nil];
}

//if and when a call arrives
- (void) didCallCancel
{
	[self endVideoChat];
}

//if and when a call arrives
- (void) didCallArrive
{
	_isChatting = YES;

	m_receiverID = nil;
	NSLog(@"RIIIIINGGGG!!!");
	self.endButton.titleLabel.text = @"Cancel Call";
	// find user location
	[self findCallerData];
	[self startVideoChat];
}

-(void) showReceiverBusyMsg
{
	NSLog(@"Receiver is busy on another call. Please try later.");
	self.statusLabel.text = @"Receiver is busy on another call. Please try later.";
	[self performSelector:@selector(goBack) withObject:nil afterDelay:5.0];
}

-(void)goBack
{
	self.statusLabel.text = @"";
}

- (void) didLogin
{
	NSLog(@"logged in!");
	[self initQBSession];
	[self userHasLoggedIn];
}

- (void)updateInterface:(NSTimer *)timer {
	self.endButton.hidden = !_isChatting;
	self.startButton.hidden = _isChatting;

	if (_videoActive && _isChatting) {
		self.endButton.titleLabel.text = @"Cancel Call";
	} else {
		self.endButton.titleLabel.text = @"End Call";
	}

	if (self.currentHeading == nil || self.currentLocation == nil) return;
	if (_toLat==0 && _toLon==0 && _toAlt==0) return;
	
	// for the elevation indicator
	float pitchDeg = RAD_TO_DEG * self.currentMotion.attitude.pitch;
	float pitchRaw = pitchDeg - 90;
	float correctPitch = viewAngle.elevation - pitchRaw;
	
	// for the heading indicator
	float correctHeading = self.currentHeading.trueHeading - viewAngle.azimuth;
	float headingAdjusted = abs(correctHeading);
	float headingTransparency;
	if (headingAdjusted < 180) {
		headingTransparency = ofMap(headingAdjusted, 0, 180, 30.0, 0.0, true);
	} else {
		headingTransparency = ofMap(headingAdjusted, 180, 360, 0.0, 30.0, true);
	}
	
	// arrows on/off
	[self hideArrows];

	BOOL rightHead = YES;
	BOOL rightPitch = YES;
	
	if ((correctHeading > 180 && correctHeading < 360 - _headingThreshold) || (correctHeading < 0 && headingAdjusted < 180)) {
		self.E_arrowView.hidden = NO;
		rightHead = NO;
	} else if ((correctHeading <= 180 && correctHeading > _headingThreshold) || (correctHeading < 0 && headingAdjusted >= 180)) {
		self.W_arrowView.hidden = NO;
		rightHead = NO;
	}
	if (correctPitch > _pitchThreshold) {
		self.N_arrowView.hidden = NO;
		rightPitch = NO;
	} else if (correctPitch < -_pitchThreshold) {
		self.S_arrowView.hidden = NO;
		rightPitch = NO;
	}

	float newX, newY;
	float radius = 600 * ofMap(correctPitch, -90, 90, 0, 1, true);
	float radians = -DEG_TO_RAD*correctHeading;
	float inverted = radians-M_PI_2;
	newX = radius * cos(inverted) + self.view.window.bounds.size.width * .5;

	newY = ofMap(correctPitch, -90, 90, 600, -600, true) + self.view.frame.size.height*.5f;

	BOOL oldAligned = _isAligned;
	
	_isAligned = (rightHead && rightPitch);

	if (_isChatting && oldAligned != _isAligned) {
		[QBHelper saveUserAlignmentToQB:_isAligned];
	}
	
	if (_isAligned && !self.otherView.zoomed) {
		[self.otherView zoomIn];
	}

	[self.otherView setTappable:_isAligned];

	[self pointObjects:correctHeading pitch:correctPitch];
	
	BOOL otherActive = NO;
	
	if (self.receiverObject != nil) {
		otherActive = [[self.receiverObject valueForKey:@"isAligned"] boolValue];
		[self.otherView setActiveState:otherActive];
	}
	
	if (!_isAligned) {
		[self fireAlignedTimer];
	} else {
		[self stopAlignedTimer];
	}
}

- (void)pointObjects:(float)heading pitch:(float)pitch {
	float xArrow, yArrow, xBox, yBox, arrowMax = 100, boxMax = 600;
	float radiusArrow = arrowMax * ofMap(pitch, -90, 90, 0, 1, true);
	float radiusBox = boxMax * ofMap(pitch, -90, 90, 0, 1, true);
	float radians = -DEG_TO_RAD*heading;
	float inverted = radians-M_PI_2;
	xArrow = radiusArrow * cos(inverted) + self.view.frame.size.width * .5;
	yArrow = radiusArrow * sin(inverted) + self.view.frame.size.height * .5;
	xBox = radiusBox * cos(inverted) + self.view.frame.size.width * .5;
	yBox = ofMap(pitch, -90, 90, boxMax, -boxMax, true) + self.view.frame.size.height*.5f;
//	yBox = radiusBox * sin(inverted) + self.view.window.bounds.size.height * .5;
	[self.otherView updatePosition:CGPointMake(xBox, yBox)];
//	NSLog(@"head: %.1f, x: %.3f y: %.3f radians: %.3f inverted: %.3f",
//		  heading, xArrow, yArrow, radians, inverted);
//	[UIView animateWithDuration:0.1
//						  delay:0
//						options:UIViewAnimationOptionAllowAnimatedContent
//					 animations:^{
//						 self.pointerView.transform = CGAffineTransformMakeRotation(radians);
//						 self.pointerView.center = CGPointMake(xArrow, yArrow);
//					 }
//					 completion:^(BOOL finished){
//					 }];
}

- (void)setupArrows {
	if (_haveArrows) return;
	_haveArrows = YES;
	CGRect viewBounds = self.view.bounds;
	CGFloat topBarOffset = self.topLayoutGuide.length;
	UIImage * arrowImage = [UIImage imageNamed:@"arrow.png"];
	// help arrows
	self.NW_arrowView = [[UIImageView alloc] initWithImage:arrowImage];
	self.NW_arrowView.transform = CGAffineTransformMakeRotation(-M_PI_4);
	self.NW_arrowView.center = CGPointMake(_arrowSize * .5 + _arrowMargin, topBarOffset + _arrowSize * .5 + _arrowMargin);
	[self.view addSubview:self.NW_arrowView];
	
	self.NE_arrowView = [[UIImageView alloc] initWithImage:arrowImage];
	self.NE_arrowView.transform = CGAffineTransformMakeRotation(M_PI_4);
	self.NE_arrowView.center = CGPointMake(viewBounds.size.width - _arrowSize * .5 - _arrowMargin, topBarOffset + _arrowSize * .5 + _arrowMargin);
	[self.view addSubview:self.NE_arrowView];
	
	self.SE_arrowView = [[UIImageView alloc] initWithImage:arrowImage];
	self.SE_arrowView.transform = CGAffineTransformMakeRotation(M_PI - M_PI_4);
	self.SE_arrowView.center = CGPointMake(viewBounds.size.width - _arrowSize * .5 - _arrowMargin, viewBounds.size.height - _arrowSize * .5 - _arrowMargin);
	[self.view addSubview:self.SE_arrowView];
	
	self.SW_arrowView = [[UIImageView alloc] initWithImage:arrowImage];
	self.SW_arrowView.transform = CGAffineTransformMakeRotation(M_PI + M_PI_4);
	self.SW_arrowView.center = CGPointMake(_arrowSize * .5 + _arrowMargin, viewBounds.size.height - _arrowSize * .5 - _arrowMargin);
	[self.view addSubview:self.SW_arrowView];
	
	self.N_arrowView = [[UIImageView alloc] initWithImage:arrowImage];
	self.N_arrowView.center = CGPointMake(viewBounds.size.width * .5, topBarOffset + _arrowSize * .5 + _arrowMargin);
	[self.view addSubview:self.N_arrowView];
	
	self.S_arrowView = [[UIImageView alloc] initWithImage:arrowImage];
	self.S_arrowView.transform = CGAffineTransformMakeRotation(M_PI);
	self.S_arrowView.center = CGPointMake(viewBounds.size.width * .5, viewBounds.size.height - _arrowSize * .5 - _arrowMargin);
	[self.view addSubview:self.S_arrowView];
	
	self.E_arrowView = [[UIImageView alloc] initWithImage:arrowImage];
	self.E_arrowView.transform = CGAffineTransformMakeRotation(M_PI_2);
	self.E_arrowView.center = CGPointMake(viewBounds.size.width - _arrowSize * .5 - _arrowMargin, viewBounds.size.height * .5);
	[self.view addSubview:self.E_arrowView];
	
	self.W_arrowView = [[UIImageView alloc] initWithImage:arrowImage];
	self.W_arrowView.transform = CGAffineTransformMakeRotation(M_PI + M_PI_2);
	self.W_arrowView.center = CGPointMake(_arrowSize * .5 + _arrowMargin, viewBounds.size.height * .5);
	[self.view addSubview:self.W_arrowView];
}

- (void)hideArrows {
	self.N_arrowView.hidden = YES;
	self.S_arrowView.hidden = YES;
	self.E_arrowView.hidden = YES;
	self.W_arrowView.hidden = YES;
	self.NE_arrowView.hidden = YES;
	self.NW_arrowView.hidden = YES;
	self.SE_arrowView.hidden = YES;
	self.SW_arrowView.hidden = YES;
}

#pragma mark - Video stuff
- (void)initRearCamera {
	if (!_rearVideoInited) {
		_rearVideoInited = YES;
		NSError *error = nil;
		self.rearSession = [[AVCaptureSession alloc] init];
		self.rearVideoCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
		self.rearVideoInput = [AVCaptureDeviceInput deviceInputWithDevice:self.rearVideoCaptureDevice error:&error];
		if (self.rearVideoInput) {
			[self.rearSession addInput:self.rearVideoInput];
			self.rearPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.rearSession];
			self.rearPreviewLayer.frame = self.videoView.bounds; // Assume you want the preview layer to fill the view.
		} else {
			// Handle the failure.
			NSLog(@"Cannot handle video");
			_rearVideoInited = NO;
		}
	}
}

- (void)startRearCapture {
	[self initRearCamera];
	if (_rearVideoInited) {
		[self.videoView.layer addSublayer:self.rearPreviewLayer];
		[self.rearSession startRunning];
	}
}

- (void)stopRearCapture {
	if (_rearVideoInited) {
		[self.rearSession stopRunning];
		[self.rearPreviewLayer removeFromSuperlayer];
	}
}

# pragma mark - Video chat stuff
- (void)refreshVideoFeeds {
	[self stopRearCapture];
	if (_videoActive) {
		[self startRearCapture];
		if (_isChatting) {
			self.otherView.hidden = NO;
		} else {
			self.otherView.hidden = YES;
		}
	}
}

- (void)startVideoChat {
	_isChatting = YES;
	
	if (appDelegate.callReceiverID != nil)
	{
		[QBChat instance].delegate = self;
		[self.videoChat callUser:appDelegate.callReceiverID.integerValue conferenceType:QBVideoChatConferenceTypeAudioAndVideo];
	}
}

- (void)endVideoChat {
	[self performSelector:@selector(doneStreaming:) withObject:nil afterDelay:0.0];
}

- (void) sessionSaved {
}

#pragma mark - UI/Interaction

- (void)pointToUser:(NSString *)nickname withID:(NSNumber *)userID andLocation:(CLLocation *)location andAltitude:(double)altitude {
	self.otherView.hidden = NO;
	_toLat = location.coordinate.latitude;
	_toLon = location.coordinate.longitude;
	_toAlt = altitude;
	self.cityLabel.text =[NSString stringWithFormat:@"find %@", nickname];
	[self updateViewAngle];
}

- (IBAction)endButtonTapped:(id)sender {
	[self endVideoChat];
}

- (void)onOtherTapped:(UITapGestureRecognizer *)recognizer {
	NSLog(@"TAPPED!");
}

- (void)resignOnTap:(id)sender {
    [self.currentResponder resignFirstResponder];
	[self updateViewAngle];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    self.currentResponder = textField;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if ([textField.text isEqualToString:@""])
        return;
	self.currentResponder = nil;
	[self updateViewAngle];
}

#pragma mark - eddaOtherViewDelegate

- (void)eddaOtherViewStartedZoomIn:(eddaOtherView *)view {
	//	[view setNeedsDisplay];
}

- (void)eddaOtherViewDidZoomIn:(eddaOtherView *)view {
	_videoActive = NO;
	if (_isChatting) {
		[self connect];
	}
	[self refreshVideoFeeds];
	[self.view bringSubviewToFront:self.statusLabel];
}

- (void)eddaOtherViewStartedZoomOut:(eddaOtherView *)view {
	_videoActive = YES;
	[self endVideoChat];
	[self refreshVideoFeeds];
}

- (void)eddaOtherViewDidZoomOut:(eddaOtherView *)view {
	self.otherView.hidden = YES;
}

#pragma mark - CLLocationManagerDelegate
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"didFailWithError: %@", error);
    UIAlertView *errorAlert = [[UIAlertView alloc]
							   initWithTitle:@"Error" message:@"Failed to Get Your Location" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [errorAlert show];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
	NSLog(@"didUpdateToLocation: %@", newLocation);
    self.currentLocation = newLocation;
	
	if (self.currentLocation != nil) {
		[locationManager stopUpdatingLocation];
		appDelegate.currentLocation = self.currentLocation;
		QBLPlace *place = [QBLPlace place];
		place.latitude = self.currentLocation.coordinate.latitude;
		place.longitude = self.currentLocation.coordinate.longitude;
		[QBHelper saveUserWithLocationToQB:place altitude:[NSNumber numberWithDouble:self.currentLocation.altitude]];
		[self updateViewAngle];
	}
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
//	NSLog(@"didUpdateHeading: %@", newHeading);
    self.currentHeading = newHeading;
}

- (BOOL)locationManagerShouldDisplayHeadingCalibration:(CLLocationManager *)manager{
	if( !self.currentHeading ) return YES; // Got nothing, We can assume we got to calibrate.
	else if( self.currentHeading.headingAccuracy < 0 ) return YES; // 0 means invalid heading. we probably need to calibrate
	else if( self.currentHeading.headingAccuracy > 5 )return YES; // 5 degrees is a small value correct for my needs. Tweak yours according to your needs.
	else return NO; // All is good. Compass is precise enough.
}

#pragma mark - GIS stuff

- (void)updateViewAngle {
	if (self.currentLocation == nil) return;
	
	_fromLat = self.currentLocation.coordinate.latitude;
	_fromLon = self.currentLocation.coordinate.longitude;
	_fromAlt = self.currentLocation.altitude;

	viewAngle = [self findViewAngleFromLat:_fromLat fromLon:_fromLon fromAlt:_fromAlt toLat:_toLat toLon:_toLon toAlt:_toAlt];
}

- (sViewAngle)findViewAngleFromLat:(double)fromLat fromLon:(double)fromLon fromAlt:(double)fromAlt toLat:(double)toLat toLon:(double)toLon toAlt:(double)toAlt {
	//	http://gis.stackexchange.com/questions/58923/calculate-view-angle
	//	Cos(azimuth) = (-z*x*dx - z*y*dy + (x^2+y^2)*dz) / Sqrt((x^2+y^2)(x^2+y^2+z^2)(dx^2+dy^2+dz^2))
	//	Sin(azimuth) = (-y*dx + x*dy) / Sqrt((x^2+y^2)(dx^2+dy^2+dz^2))
	//	Cos(elevation) = (x*dx + y*dy + z*dz) / Sqrt((x^2+y^2+z^2)*(dx^2+dy^2+dz^2))
	
	double x, y, z, toX, toY, toZ, dx, dy, dz;
	
	x = DEG_TO_RAD * fromLon;
	y = DEG_TO_RAD * fromLat;
	z = fromAlt;
	
	pj_transform(pj_geod, pj_geoc, 1, 0, &x, &y, &z );

	toX = DEG_TO_RAD * toLon;
	toY = DEG_TO_RAD * toLat;
	toZ = toAlt;

	pj_transform(pj_geod, pj_geoc, 1, 0, &toX, &toY, &toZ );
	
	dx = toX-x;
	dy = toY-y;
	dz = toZ-z;
		
	double cosElevation = (x*dx + y*dy + z*dz) / sqrt(((x*x)+(y*y)+(z*z))*((dx*dx)+(dy*dy)+(dz*dz)));
	
	double elevation = 90 - RAD_TO_DEG * (acos(cosElevation));
	
	double azimuth;
	
	double a = 6378137, f = 1/298.257223563; /* WGS84 */
	double azi2, s12;
	struct geod_geodesic g;
	
	geod_init(&g, a, f);
	geod_inverse(&g, fromLat, fromLon, toLat, toLon, &s12, &azimuth, &azi2);
	
	sViewAngle output;
	
	if (isnan(azimuth)) azimuth = 0.0;
	if (isnan(elevation)) elevation = 0.0;
	
	if (azimuth < 0) {
		azimuth += 360;
	}
		
	output.azimuth = azimuth;
	output.elevation = elevation;

	return output;
}

#pragma mark - LS View

- (IBAction)unwindToVideoChat:(UIStoryboardSegue *)unwindSegue
{
	NSLog(@"came back with nickname: %@ location: %@ altitude: %@", appDelegate.callReceiverTitle, appDelegate.callReceiverLocation, appDelegate.callReceiverAltitude);
	_isChatting = YES;

	[self pointToUser:appDelegate.callReceiverTitle withID:appDelegate.callReceiverID andLocation:appDelegate.callReceiverLocation andAltitude:appDelegate.callReceiverAltitude.doubleValue];

	[self startVideoChat];

	// push notify the reciever
//	PFQuery *query = [PFQuery queryWithClassName:@"ActiveUsers"];
//	[query whereKey:@"userID" equalTo:appDelegate.callReceiverID];
//	NSLog(@"looking for: [%@]", appDelegate.callReceiverID);
//	[query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
//		if (!error) {
//			// Do something with the found objects
//			if (objects.count == 1) {
//				self.receiverObject = objects.firstObject;
//				[self fireActiveTimer];
//				
//				// Find user for this activeuser
//				PFQuery *userQuery = [PFUser query];
//				[userQuery whereKey:@"objectId" equalTo:[self.receiverObject valueForKey:@"userID"]];
//				
//				// Find devices associated with these users
//				PFQuery *pushQuery = [PFInstallation query];
//				[pushQuery whereKey:@"user" matchesQuery:userQuery];
//				
//				// Send push notification to query
//				PFPush *push = [[PFPush alloc] init];
//				NSTimeInterval interval = 60*2; // 2 minutes
//				[push expireAfterTimeInterval:interval];
//				[push setQuery:pushQuery]; // Set our Installation query
//				[push setMessage:[NSString stringWithFormat:@"You have a call from %@!", appDelegate.userTitle]];
//				[push sendPushInBackground];
//				NSLog(@"sent push: %@", push);
//			} else {
//				NSLog(@"error! found %d users", objects.count);
//			}
//		} else {
//			// Log details of the failure
//			NSLog(@"Error: %@ %@", error, [error userInfo]);
//		}
//	}];
}

- (IBAction)unwindToMainViewController:(UIStoryboardSegue *)unwindSegue
{
	NSLog(@"canceled");
	m_receiverID = nil;
	appDelegate.callReceiverID = m_receiverID;
	appDelegate.callReceiverTitle = @"";
	appDelegate.callReceiverLocation = nil;
	appDelegate.callReceiverAltitude = 0;
	_toLat = 0;
	_toLon = 0;
	_toAlt = 0;
	self.cityLabel.text = appDelegate.callReceiverTitle;
	[self hideArrows];
	_isChatting = NO;
	self.otherView.hidden = YES;
}

#pragma mark - Flipside View

- (void)flipsideViewControllerDidFinish:(eddaFlipsideViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark -
#pragma mark QBChatDelegate

-(void) initQBSession {
	// set Chat delegate
	[QBChat instance].delegate = self;
}

// Chat delegate
-(void) chatDidLogin{
	// You have successfully signed in to QuickBlox Chat
	NSLog(@"chat logged in!");
}

-(void) chatDidNotLogin{
	// You have successfully signed in to QuickBlox Chat
	NSLog(@"ERROR! chat NOT logged in!");
}

-(void) chatDidReceiveCallRequestFromUser:(NSUInteger)userID withSessionID:(NSString *)_sessionID conferenceType:(enum QBVideoChatConferenceType)conferenceType{
	m_mode = streamingModeIncoming; //connect, publish, subscribe
	m_connectionAttempts = 1;
	self.videoChat = [[QBChat instance] createAndRegisterVideoChatInstanceWithSessionID:_sessionID];
	[self.videoChat acceptCallWithOpponentID:userID conferenceType:conferenceType];
}

-(void) chatCallDidAcceptByUser:(NSUInteger)userID{
	NSLog(@"call accepted by: %d", (int)userID);
}

- (void)chatCallDidStartWithUser:(NSUInteger)userID sessionID:(NSString *)sessionID{
	NSLog(@"call started with user: %d session: %@", userID, sessionID);
}

#pragma mark - Timers

- (void) fireAlignedTimer
{
	if (self.alignedTimer && [self.alignedTimer isValid])
		return;
	
	alignedTimerStart = [[NSDate alloc] init];
	
	self.alignedTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
													 target:self
												   selector:@selector(onAlignedTimer:)
												   userInfo:nil
													   repeats:YES];
}

- (void) stopAlignedTimer {
	if (self.alignedTimer && [self.alignedTimer isValid])
		[self.alignedTimer invalidate];
	[self.otherView hideAlert];
	alignedTimerStart = nil;
}

- (void) onAlignedTimer:(NSTimer *)timer {
	NSDate *now = [[NSDate alloc] init];
	NSTimeInterval timeElapsed = [now timeIntervalSinceDate:alignedTimerStart];
	int timeRemaining = _timeToWaitForAlignment - timeElapsed;
	if (!_isAligned) {
		[self.otherView showAlert:[NSString stringWithFormat:@"Conversation will close if not aligned in %i!", timeRemaining]];
		if (timeRemaining<0) {
			[self.otherView zoomOut];
		}
	} else {
		[self stopAlignedTimer];
	}
}

- (void) fireActiveTimer
{
	if (self.activeTimer && [self.activeTimer isValid])
		return;
	
	self.activeTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
													 target:self
												   selector:@selector(onActiveTimer:)
												   userInfo:nil
													   repeats:YES];
}

- (void) stopActiveTimer {
	if (self.activeTimer && [self.activeTimer isValid])
		[self.activeTimer invalidate];
}

- (void) onActiveTimer:(NSTimer *)timer {
//	NSLog(@"mode: %d receiverObject: %@", m_mode, self.receiverObject);
	if (self.receiverObject != nil) {
//		[self.receiverObject refreshInBackgroundWithBlock:^(PFObject *object, NSError *error) {
//			//
//		}];
	}
}

#pragma mark - QB stuff

-(void) findCallerData
{
//	PFQuery *query = [PFQuery queryWithClassName:@"ActiveUsers"];
//	[query whereKey:@"userID" equalTo:appDelegate.callerID];
//	
//	[query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error)
//	 {
//		 if (!error)
//		 {
//			 if (objects.count > 0)
//			 {
//				 self.receiverObject = objects.firstObject;
//				 [self fireActiveTimer];
//				 //if for this user, skip it.
//				 NSNumber *userID = [[self.receiverObject valueForKey:@"userID"] numberValue];
//				 NSString *userTitle = [self.receiverObject valueForKey:@"userTitle"];
//				 PFGeoPoint *coordinate = [self.receiverObject valueForKey:@"userLocation"];
//				 NSNumber *userAltitude = [self.receiverObject valueForKey:@"userAltitude"];
//				 
//				 CLLocation * location = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
//
//				 [self pointToUser:userTitle withID:userID andLocation:location andAltitude:userAltitude.doubleValue];
//			 }
//		 }
//		 else
//		 {
//			 NSLog(@"error: %@",[error description]);
//		 }
//	 }];
}

- (void)connect
{
	NSLog(@"connecting");
	self.videoChat = [[QBChat instance] createAndRegisterVideoChatInstance];

	CGRect viewBounds = self.view.bounds;
	CGFloat topBarOffset = self.topLayoutGuide.length;
	
	self.opponentVideoView = [[UIView alloc] initWithFrame:CGRectMake(viewBounds.size.width * .5 - _previewWidth * .5, topBarOffset + _arrowMargin, _previewWidth, _previewHeight)];
	self.myVideoView = [[UIView alloc] initWithFrame:self.otherView.frame];

	[self.otherView insertSubview:self.opponentVideoView atIndex:1];
	[self.otherView insertSubview:self.myVideoView atIndex:0];

	self.videoChat.viewToRenderOpponentVideoStream = self.opponentVideoView;
	self.videoChat.viewToRenderOwnVideoStream = self.myVideoView;
}

- (void)disconnect
{
	[self.opponentVideoView removeFromSuperview];
	[self.myVideoView removeFromSuperview];
	self.opponentVideoView = nil;
	self.myVideoView = nil;

	[[QBChat instance] unregisterVideoChatInstance:self.videoChat];
	self.videoChat = nil;
}

- (IBAction)doneStreaming:(id)sender {
	[self.otherView zoomOut];
    [self disconnectAndGoBack];
}

- (void) disconnectAndGoBack {
	_isChatting = NO;
	
	[self.videoChat finishCall];
	
	[self disconnect];

	[[QBChat instance] unregisterVideoChatInstance:self.videoChat];
	self.videoChat = nil;

	self.endButton.hidden = YES;
	self.startButton.hidden = NO;
	self.statusLabel.text = @"";

	m_receiverID = nil;
	appDelegate.callReceiverID = m_receiverID;
	appDelegate.callReceiverTitle = @"";
	appDelegate.callReceiverLocation = nil;
	appDelegate.callReceiverAltitude = 0;
	
	_toLat=0, _toLon=0, _toAlt=0;
	
	self.cityLabel.text = @"";
	self.receiverObject = nil;
	
	[self stopActiveTimer];
	[self hideArrows];
	
    [QBHelper deleteActiveSession];
    [QBHelper setPollingTimer:YES];
}

#pragma mark - Alert

- (void)showAlert:(NSString *)string
{
    // show alertview on main UI
	dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"OTError"
														message:string
													   delegate:self
											  cancelButtonTitle:@"OK"
											  otherButtonTitles:nil] ;
        [alert show];
    });
}

@end
