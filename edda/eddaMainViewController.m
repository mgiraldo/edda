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
<OTSessionDelegate, OTSubscriberDelegate, OTPublisherDelegate>

@property (strong, nonatomic) NSMutableSet *disconnectListeners;

@end

@implementation eddaMainViewController {
	OTSession* _session;
	OTPublisher* _publisher;
	OTSubscriber* _subscriber;
	int m_mode;
	int m_connectionAttempts;
	NSString * m_receiverID;
	eddaAppDelegate *appDelegate;
	NSDate *alignedTimerStart;
}

// Change to NO to subscribe to streams other than your own.
static bool subscribeToSelf = NO;

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
	//pass blank because call has arrived, no need for receiverID.
	[self createSession];

	m_receiverID = @"";
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
		[ParseHelper saveUserAlignmentToParse:_isAligned];
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

#pragma mark - video stuff
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
	
	if (![appDelegate.callReceiverID isEqualToString:@""])
	{
		NSLog(@"outgoing mode");
		[self initOutGoingCall];
		//connect, publish/subscriber -> will be taken care by
		//sessionSaved observer handler.
	}
	else
	{
		NSLog(@"incoming mode");
		[self initIncomingCall];
	}

	[self firePublisherTimer];
	[self fireSubscriberTimer];
}

- (void)endVideoChat {
	[self performSelector:@selector(doneStreaming:) withObject:nil afterDelay:0.0];
}

#pragma mark - UI/Interaction

- (void)pointToUser:(NSString *)nickname withID:(NSString *)userID andLocation:(CLLocation *)location andAltitude:(double)altitude {
	self.otherView.hidden = NO;
	_toLat = location.coordinate.latitude;
	_toLon = location.coordinate.longitude;
	_toAlt = altitude;
	self.cityLabel.text =[NSString stringWithFormat:@"find %@", nickname];
	[self updateViewAngle];
}

- (void)clearReceiver {
	m_receiverID = @"";
	appDelegate.callReceiverID = m_receiverID;
	appDelegate.callReceiverTitle = @"";
	appDelegate.callReceiverLocation = nil;
	appDelegate.callReceiverAltitude = 0;
	
	_toLat=0, _toLon=0, _toAlt=0;
	
	self.cityLabel.text = @"";
	self.receiverObject = nil;
	
	[self stopActiveTimer];
	[self hideArrows];
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
		[ParseHelper saveUserWithLocationToParse:[PFGeoPoint geoPointWithLocation:self.currentLocation] :[NSNumber numberWithDouble:self.currentLocation.altitude]];
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
	PFQuery *query = [PFQuery queryWithClassName:@"ActiveUsers"];
	[query whereKey:@"userID" equalTo:appDelegate.callReceiverID];
	NSLog(@"looking for: [%@]", appDelegate.callReceiverID);
	[query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
		if (!error) {
			// Do something with the found objects
			if (objects.count == 1) {
				self.receiverObject = objects.firstObject;
				[self fireActiveTimer];
				
				// Find user for this activeuser
				PFQuery *userQuery = [PFUser query];
				[userQuery whereKey:@"objectId" equalTo:[self.receiverObject valueForKey:@"userID"]];
				
				// Find devices associated with these users
				PFQuery *pushQuery = [PFInstallation query];
				[pushQuery whereKey:@"user" matchesQuery:userQuery];
				
				// Send push notification to query
				PFPush *push = [[PFPush alloc] init];
				NSTimeInterval interval = 60*2; // 2 minutes
				[push expireAfterTimeInterval:interval];
				[push setQuery:pushQuery]; // Set our Installation query
				[push setMessage:[NSString stringWithFormat:@"You have a call from %@!", appDelegate.userTitle]];
				[push sendPushInBackground];
				NSLog(@"sent push: %@", push);
			} else {
				NSLog(@"error! found %d users", objects.count);
			}
		} else {
			// Log details of the failure
			NSLog(@"Error: %@ %@", error, [error userInfo]);
		}
	}];
}

- (IBAction)unwindToMainViewController:(UIStoryboardSegue *)unwindSegue
{
	NSLog(@"canceled");
	m_receiverID = @"";
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

#pragma mark - Picker methods

// Catpure the picker view selection
- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
	if (row == 0) return;
	_toLat = [_placeCoordinates[row][0] doubleValue];
	_toLon = [_placeCoordinates[row][1] doubleValue];
	_toAlt = [_placeCoordinates[row][2] doubleValue];
	self.cityLabel.text = _places[row];
	[self updateViewAngle];
}

// The number of columns of data
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

// The number of rows of data
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return _places.count;
}

// The data to return for the row and component (column) that's being passed in
- (NSString*)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    return _places[row];
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

- (void)fireSubscriberTimer {
	if (self.subscriberTimer && [self.subscriberTimer isValid])
		return;
	
	self.subscriberTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
															target:self
														  selector:@selector(onSubscriberTimer:)
														  userInfo:nil
														   repeats:YES];
}

- (void) stopSubscriberTimer {
	if (self.subscriberTimer && [self.subscriberTimer isValid])
		[self.subscriberTimer invalidate];
}

- (void) onSubscriberTimer:(NSTimer *)timer {
	if (self.otherView.zoomed && _subscriber) {
		[_subscriber.view setFrame:self.otherView.frame];
		[self.otherView insertSubview:_subscriber.view atIndex:0];
		[self stopSubscriberTimer];
	}
}

- (void)firePublisherTimer {
	if (self.publisherTimer && [self.publisherTimer isValid])
		return;
	
	self.publisherTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
															target:self
														  selector:@selector(onPublisherTimer:)
														  userInfo:nil
														   repeats:YES];
}

- (void) stopPublisherTimer {
	if (self.publisherTimer && [self.publisherTimer isValid])
		[self.publisherTimer invalidate];
}

- (void) onPublisherTimer:(NSTimer *)timer {
	if (self.otherView.zoomed) {
		[self doPublish];
		[self stopPublisherTimer];
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
		[self.receiverObject refreshInBackgroundWithBlock:^(PFObject *object, NSError *error) {
			//
		}];
	}
}

#pragma mark - Parse stuff

-(void) findCallerData
{
	PFQuery *query = [PFQuery queryWithClassName:@"ActiveUsers"];
	[query whereKey:@"userID" equalTo:appDelegate.callerID];
	
	[query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error)
	 {
		 if (!error)
		 {
			 if (objects.count > 0)
			 {
				 self.receiverObject = objects.firstObject;
				 [self fireActiveTimer];
				 //if for this user, skip it.
				 NSString *userID = [self.receiverObject valueForKey:@"userID"];
				 NSString *userTitle = [self.receiverObject valueForKey:@"userTitle"];
				 PFGeoPoint *coordinate = [self.receiverObject valueForKey:@"userLocation"];
				 NSNumber *userAltitude = [self.receiverObject valueForKey:@"userAltitude"];
				 
				 CLLocation * location = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];

				 [self pointToUser:userTitle withID:userID andLocation:location andAltitude:userAltitude.doubleValue];
			 }
		 }
		 else
		 {
			 NSLog(@"error: %@",[error description]);
		 }
	 }];
}

- (void) initIncomingCall
{
	m_mode = streamingModeIncoming; //connect, publish, subscribe
	m_connectionAttempts = 1;
	[self connectWithPublisherToken];
}

- (void) initOutGoingCall
{
	m_mode = streamingModeOutgoing; //generate session
	NSMutableDictionary * inputDict = [NSMutableDictionary dictionary];
	[inputDict setObject:[ParseHelper loggedInUser].objectId forKey:@"callerID"];
	[inputDict setObject:appDelegate.userTitle forKey:@"callerTitle"];
	[inputDict setObject:appDelegate.callReceiverID forKey:@"receiverID"];
	m_connectionAttempts = 1;
	[ParseHelper saveSessionToParse:inputDict];
}

- (void) sessionSaved
{
	[self createSession];
	[self connectWithSubscriberToken];
}

- (void) connectWithPublisherToken
{
	NSLog(@"connectWithPublisherToken");
	[self doConnect:appDelegate.publisherToken :appDelegate.sessionID];
}

- (void) connectWithSubscriberToken
{
	NSLog(@"connectWithSubscriberToken");
	[self doConnect:appDelegate.subscriberToken :appDelegate.sessionID];
}

- (void)doConnect : (NSString *) token :(NSString *) sessionID
{
//	NSLog(@"token: %@ sessionid: %@", token, sessionID);
	
	OTError *error = nil;
	[_session connectWithToken:token error:&error];

	if (error)
	{
		[self showAlert:[error localizedDescription]];
	}
}

- (void)doDisconnect
{
	OTError *error = nil;
	[_session disconnect:&error];

	if (error)
	{
		[self showAlert:[error localizedDescription]];
	}
}

#pragma mark - OpenTok methods

/**
 * Sets up an instance of OTPublisher to use with this session. OTPubilsher
 * binds to the device camera and microphone, and will provide A/V streams
 * to the OpenTok session.
 */
- (void)doPublish
{
	NSLog(@"publishing...");
	
	_publisher = [[OTPublisher alloc] initWithDelegate:self name:UIDevice.currentDevice.name];
	
    OTError *error = nil;
    [_session publish:_publisher error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }

	CGRect viewBounds = self.view.bounds;
	CGFloat topBarOffset = self.topLayoutGuide.length;
	
	[self.otherView insertSubview:_publisher.view atIndex:1];
	[_publisher.view setFrame:CGRectMake(viewBounds.size.width * .5 - _previewWidth * .5, topBarOffset + _arrowMargin, _previewWidth, _previewHeight)];
}

/**
 * Cleans up the publisher and its view. At this point, the publisher should not
 * be attached to the session any more.
 */
- (void)cleanupPublisher {
    [_publisher.view removeFromSuperview];
    _publisher = nil;
	[self stopPublisherTimer];
    // this is a good place to notify the end-user that publishing has stopped.
}

/**
 * Instantiates a subscriber for the given stream and asynchronously begins the
 * process to begin receiving A/V content for this stream. Unlike doPublish,
 * this method does not add the subscriber to the view hierarchy. Instead, we
 * add the subscriber only after it has connected and begins receiving data.
 */
- (void)doSubscribe:(OTStream*)stream
{
    _subscriber = [[OTSubscriber alloc] initWithStream:stream delegate:self];
    
    OTError *error = nil;
    [_session subscribe:_subscriber error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }
}

/**
 * Cleans the subscriber from the view hierarchy, if any.
 * NB: You do *not* have to call unsubscribe in your controller in response to
 * a streamDestroyed event. Any subscribers (or the publisher) for a stream will
 * be automatically removed from the session during cleanup of the stream.
 */
- (void)cleanupSubscriber
{
    [_subscriber.view removeFromSuperview];
    _subscriber = nil;
	[self stopSubscriberTimer];
}

# pragma mark - OTSession delegate callbacks

- (void)createSession {
	_session = [[OTSession alloc] initWithApiKey:appDelegate.otAPIKey
									   sessionId:appDelegate.sessionID
										delegate:self];
}

- (void)ensureSessionDisconnectedBeforeBlock:(void (^)(void))resumeBlock {
	
	// If the session exists, and it is connected or connecting, then save this block as a listener and start disconnecting
	if (_session && (_session.sessionConnectionStatus == OTSessionConnectionStatusConnected ||
						 _session.sessionConnectionStatus == OTSessionConnectionStatusConnecting)) {
		
		[self.disconnectListeners addObject:resumeBlock];
		NSError *error;
		[_session disconnect:&error];
		
		// Otherwise, we can execute the block right now
	} else {
		resumeBlock();
	}
}

- (void)sessionDidConnect:(OTSession*)session
{
    NSLog(@"sessionDidConnect (%@)", session.sessionId);
    
	self.statusLabel.text = @"Connected, waiting for stream...";
}

- (void)sessionDidDisconnect:(OTSession*)session
{
    NSString* alertMessage =
    [NSString stringWithFormat:@"Session disconnected: (%@)",
     session.sessionId];
    NSLog(@"sessionDidDisconnect (%@)", alertMessage);

	self.statusLabel.text = @"Session disconnected...";

	[self performSelector:@selector(goBack) withObject:nil afterDelay:5.0];
}


- (void)session:(OTSession*)mySession streamCreated:(OTStream *)stream
{
    NSLog(@"session streamCreated (%@)", stream.streamId);
    
    // Step 3a: (if NO == subscribeToSelf): Begin subscribing to a stream we
    // have seen on the OpenTok session.
    if (nil == _subscriber && !subscribeToSelf)
    {
        [self doSubscribe:stream];
    }
}

- (void)session:(OTSession*)mySession didReceiveStream:(OTStream*)stream
{
	NSLog(@"session: didReceiveStream:");
}

- (void)updateSubscriber
{
	for (NSString* streamId in _session.streams) {
		OTStream* stream = [_session.streams valueForKey:streamId];
		if (stream.connection.connectionId != _session.connection.connectionId) {
			_subscriber = [[OTSubscriber alloc] initWithStream:stream delegate:self];
			break;
		}
	}
}

- (void)session:(OTSession*)session didDropStream:(OTStream*)stream
{
	NSLog(@"session didDropStream (%@)", stream.streamId);
	if (!subscribeToSelf
		&& _subscriber
		&& [_subscriber.stream.streamId isEqualToString: stream.streamId]) {
		_subscriber = nil;
		[self updateSubscriber];
		self.statusLabel.text = @"Stream dropped, disconnecting...";
		[self.view bringSubviewToFront:self.statusLabel];
		[self performSelector:@selector(doneStreaming:) withObject:nil afterDelay:5.0];
	}
}

- (void)session:(OTSession*)session streamDestroyed:(OTStream *)stream
{
    NSLog(@"session streamDestroyed (%@)", stream.streamId);
    
    if ([_subscriber.stream.streamId isEqualToString:stream.streamId])
    {
        [self cleanupSubscriber];
    }
}

- (void)  session:(OTSession *)session connectionCreated:(OTConnection *)connection
{
    NSLog(@"session connectionCreated (%@)", connection.connectionId);
}

- (void)    session:(OTSession *)session connectionDestroyed:(OTConnection *)connection
{
    NSLog(@"session connectionDestroyed (%@)", connection.connectionId);
//    if ([_subscriber.stream.connection.connectionId
//         isEqualToString:connection.connectionId])
//    {
        [self endVideoChat];
//    }
}

- (void) session:(OTSession*)session didFailWithError:(OTError*)error
{
	NSLog(@"session: didFailWithError:");
	NSLog(@"- description: %@", error.localizedDescription);
	NSString * errorMsg;
	if (m_connectionAttempts < 10)
	{
		m_connectionAttempts++;
		errorMsg = [NSString stringWithFormat:@"Session failed to connect - Reconnecting attempt %d",m_connectionAttempts];
		self.statusLabel.text = errorMsg;
		if (m_mode == streamingModeOutgoing)
		{
			[self performSelector:@selector(connectWithSubscriberToken) withObject:nil afterDelay:15.0];
		}
		else
		{
			[self performSelector:@selector(connectWithPublisherToken) withObject:nil afterDelay:15.0];
		}
	}
	else
	{
		m_connectionAttempts = 1;
		errorMsg = [NSString stringWithFormat:@"Session failed to connect - disconnecting now"];
		self.statusLabel.text = errorMsg;
		[self performSelector:@selector(doneStreaming:) withObject:nil afterDelay:10.0];
	}
}

# pragma mark - OTSubscriber delegate callbacks
- (void)subscriberVideoDataReceived:(OTSubscriber *)subscriber {
}

- (void)subscriberDidConnectToStream:(OTSubscriber*)subscriber
{
    NSLog(@"subscriberDidConnectToStream (%@)",
          subscriber.stream.connection.connectionId);
	self.statusLabel.text = @"Connected and streaming...";

	assert(_subscriber == subscriber);
}

- (void)subscriber:(OTSubscriber*)subscriber didFailWithError:(OTError*)error
{
    NSLog(@"subscriber %@ didFailWithError %@",
          subscriber.stream.streamId,
          error);
	self.statusLabel.text = @"Error receiving video feed, disconnecting...";

	[self performSelector:@selector(doneStreaming:) withObject:nil afterDelay:5.0];
}

- (IBAction)doneStreaming:(id)sender {
	[self.otherView zoomOut];
    [self disConnectAndGoBack];
}

- (void) disConnectAndGoBack {
	_isChatting = NO;
	
	OTError* error = nil;

	[_session disconnect:&error];
	if (error) {
		NSLog(@"disconnect failed with error: (%@)", error);
	}
	
	self.endButton.hidden = YES;
	self.startButton.hidden = NO;
	self.statusLabel.text = @"";
	[self clearReceiver];
	[self cleanupPublisher];
	[self cleanupSubscriber];
    [ParseHelper deleteActiveSession];
    [ParseHelper setPollingTimer:YES];
}

# pragma mark - OTPublisher delegate callbacks

- (void)publisher:(OTPublisher *)publisher streamCreated:(OTStream *)stream
{
    // Step 3b: (if YES == subscribeToSelf): Our own publisher is now visible to
    // all participants in the OpenTok session. We will attempt to subscribe to
    // our own stream. Expect to see a slight delay in the subscriber video and
    // an echo of the audio coming from the device microphone.
    if (nil == _subscriber && subscribeToSelf)
    {
        [self doSubscribe:stream];
    }
}

- (void)publisher:(OTPublisher*)publisher streamDestroyed:(OTStream *)stream
{
    if ([_subscriber.stream.streamId isEqualToString:stream.streamId])
    {
        [self cleanupSubscriber];
    }
    
    [self cleanupPublisher];
}

- (void)publisher:(OTPublisher*)publisher didFailWithError:(OTError*) error
{
    NSLog(@"publisher didFailWithError %@", error);
	self.statusLabel.text = @"Failed to share your camera feed, disconnecting...";

	[self performSelector:@selector(doneStreaming:) withObject:nil afterDelay:5.0];
}

- (void)publisherDidStartStreaming:(OTPublisher *)publisher
{
	NSLog(@"publisherDidStartStreaming: %@", publisher);
	self.statusLabel.text = @"Started your camera feed...";
}

-(void)publisherDidStopStreaming:(OTPublisher*)publisher
{
	NSLog(@"publisherDidStopStreaming:%@", publisher);
	self.statusLabel.text = @"Stopping your camera feed...";
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
