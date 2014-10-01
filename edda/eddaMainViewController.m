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
}

// Change to NO to subscribe to streams other than your own.
static bool subscribeToSelf = NO;

// self preview size
float _previewWidth = 60;
float _previewHeight = 90;

CLLocationManager *locationManager;
CMMotionManager *motionManager;

BOOL _debugActive = NO;
BOOL _videoActive = YES;
BOOL _rearVideoInited = NO;
BOOL _haveArrows = NO;

int _activeCamera = 1; // rear default

float _headingThreshold = 10.0f;
float _pitchThreshold = 5.0f;

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

	// debug view
	[self.debugSwitch setOn:_debugActive];
	
	// other view
	self.otherView = [[eddaOtherView alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
	[self.otherView setActiveState:NO];
	self.otherView.delegate = self;
	[self.view addSubview:self.otherView];
	
	// the indicator
	self.indicatorView.layer.cornerRadius = self.indicatorView.bounds.size.width * .5f;
	self.indicatorView.layer.backgroundColor = [UIColor yellowColor].CGColor;
	self.indicatorView.layer.opacity = 0.0;
	self.indicatorView.layer.borderWidth = 0.0;
	self.indicatorView.layer.borderColor = [UIColor greenColor].CGColor;

	// picker stuff
	_places = @[@"Select", @"Beijing", @"Bogotá", @"Buenos Aires", @"Jakarta", @"Johannesburg", @"Kampala", @"London", @"Los Angeles", @"Madrid", @"Mecca", @"Moscow", @"New York", @"NYC Antipode", @"Paris", @"Perth", @"São Paulo", @"Tokio"];
	_placeCoordinates = @[ @[@0.0f, @0.0f, @0.0f] // "None"
						   , @[@39.904030f, @116.407526f, @52.0f] // "Beijing"
						   , @[@4.598056f, @-74.075833f, @2600.0f] // "Bogotá"
						   , @[@-34.603723f, @-58.381593f, @26.0f] // "Buenos Aires"
						   , @[@-6.208763f, @106.845599f, @5.0f] // "Jakarta"
						   , @[@-26.204103f, @28.047305f, @1755.0f] // "Johannesburg"
						   , @[@0.313611f, @32.581111f, @1222.0f] // "Kampala"
						   , @[@51.507351f, @-0.127758f, @7.0f] // "London"
						   , @[@34.052234f, @-118.243685f, @89.0f] // "Los Angeles"
						   , @[@40.416775f, @-3.703790f, @650.0f] // "Madrid"
						   , @[@21.4167f, @39.8167f, @334.0f] // "Mecca"
						   , @[@55.755826f, @37.617300f, @126.0f] // "Moscow"
						   , @[@40.712784f, @-74.005941f, @10.0f] // "New York"
						   , @[@-40.718315f, @106.043472f, @0.0f] // "NYC Antipode"
						   , @[@48.856614f, @2.352222f, @45.0f] // "Paris"
						   , @[@-31.953004f, @115.857469f, @54.0f] // "Perth"
						   , @[@-23.550520f, @-46.633309f, @733.0f] // "São Paulo"
						   , @[@35.689487f, @139.691706f, @19.0f] // "Tokio"
						];
	
	self.placesPicker.dataSource = self;
    self.placesPicker.delegate = self;
	
	// input
	self.toLatitudeTextField.delegate = self;
	self.toLongitudeTextField.delegate = self;
	self.toAltitudeTextField.delegate = self;
	
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
	self.debugView.frame = CGRectMake(0, -self.debugView.frame.size.height, self.view.bounds.size.width, self.debugView.frame.size.height);
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
}

//if and when a call arrives
- (void) didCallArrive
{
	//pass blank because call has arrived, no need for receiverID.
	[self createSession];
	m_receiverID = @"";
	NSLog(@"RIIIIINGGGG!!!");
	[self.otherView zoomIn];
}

-(void) showReceiverBusyMsg
{
	NSLog(@"Receiver is busy on another call. Please try later.");
}

- (void) didLogin
{
	NSLog(@"logged in!");
	[self userHasLoggedIn];
}

- (void)updateInterface:(NSTimer *)timer {
	if (self.currentHeading == nil || self.currentLocation == nil) return;
	if (_toLat==0 && _toLon==0 && _toAlt==0) return;
	
	// for the elevation indicator
	float pitchDeg = RAD_TO_DEG * self.currentMotion.attitude.pitch;
	float pitchRaw = pitchDeg - 90;
	float correctPitch = viewAngle.elevation - pitchRaw;
	float pitchAdjusted = abs(correctPitch);
	float elevationTransparency = ofMap(pitchAdjusted, 0, 180, 1.0, 0.0, true);
	self.indicatorView.layer.opacity = elevationTransparency;
	
	// for the heading indicator
	float correctHeading = self.currentHeading.trueHeading - viewAngle.azimuth;
	float headingAdjusted = abs(correctHeading);
	float headingTransparency;
	if (headingAdjusted < 180) {
		headingTransparency = ofMap(headingAdjusted, 0, 180, 30.0, 0.0, true);
	} else {
		headingTransparency = ofMap(headingAdjusted, 180, 360, 0.0, 30.0, true);
	}
	self.indicatorView.layer.borderWidth = headingTransparency;
	
	// arrows on/off
	[self hideArrows];

	if ((correctHeading > 180 && correctHeading < 360 - _headingThreshold) || (correctHeading < 0 && headingAdjusted < 180)) {
		self.E_arrowView.hidden = NO;
	} else if ((correctHeading <= 180 && correctHeading > _headingThreshold) || (correctHeading < 0 && headingAdjusted >= 180)) {
		self.W_arrowView.hidden = NO;
	}
	if (correctPitch > _pitchThreshold) {
		self.N_arrowView.hidden = NO;
	} else if (correctPitch < -_pitchThreshold) {
		self.S_arrowView.hidden = NO;
	}

//	float normalizedHeadingTransparency = ofMap(headingTransparency, 0.0, 30.0, 0.0, 1.0, true);

//	NSLog(@"head: %.0f chead: %.0f cheadadj: %.0f cpitch: %.0f pitchdeg: %.0f cpitchadj: %.0f pitchraw: %.0f",
//		  self.currentHeading.trueHeading, correctHeading, headingAdjusted, correctPitch, pitchDeg, pitchAdjusted, pitchRaw);
	
//	float layerTransparency = elevationTransparency * .5 + normalizedHeadingTransparency * .5;
	
	BOOL rightHead = YES;
	BOOL rightPitch = YES;
	
	float newX, newY;
	float radius = 600 * ofMap(correctPitch, -90, 90, 0, 1, true);
	float radians = -DEG_TO_RAD*correctHeading;
	float inverted = radians-M_PI_2;
	newX = radius * cos(inverted) + self.view.window.bounds.size.width * .5;

	newY = ofMap(correctPitch, -90, 90, 600, -600, true) + self.view.frame.size.height*.5f;

	[self.otherView setTappable:(rightHead && rightPitch)];

	[self pointObjects:correctHeading pitch:correctPitch];
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

- (void)updateArrows {
	CGFloat duration = 0.01;
	float h = 0.0;
	
	if (self.currentHeading != nil) {
		h = self.currentHeading.trueHeading;
	}
	
	// azimuth arrow
	CABasicAnimation *animationB = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
	animationB.fromValue = [[self.azimuthImage.layer presentationLayer] valueForKeyPath:@"transform.rotation.z"];
	animationB.toValue = [NSNumber numberWithFloat:-DEG_TO_RAD*(h-viewAngle.azimuth)];;
	animationB.duration = duration;
	animationB.fillMode = kCAFillModeForwards;
	animationB.repeatCount = 0;
	animationB.removedOnCompletion = NO;
	animationB.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
	[self.azimuthImage.layer addAnimation:animationB forKey:@"transform.rotation.z"];
}

- (void)showDebug {
	[UIView beginAnimations:@"hideDebug" context:NULL];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDuration:0.25];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
	self.debugView.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.debugView.frame.size.height);
	[UIView commitAnimations];
}

- (void)hideDebug {
	[UIView beginAnimations:@"showDebug" context:NULL];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDuration:0.25];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	self.debugView.frame = CGRectMake(0, -self.debugView.frame.size.height, self.view.bounds.size.width, self.debugView.frame.size.height);
	[UIView commitAnimations];
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
	}
}

- (void)startVideoChat {
	if (![appDelegate.callReceiverID isEqualToString:@""])
	{
		NSLog(@"outgoing mode");
		m_mode = streamingModeOutgoing; //generate session
		[self initOutGoingCall];
		//connect, publish/subscriber -> will be taken care by
		//sessionSaved observer handler.
	}
	else
	{
		NSLog(@"incoming mode");
		m_mode = streamingModeIncoming; //connect, publish, subscribe
		m_connectionAttempts = 1;
		[self connectWithPublisherToken];
//		[self connectWithSubscriberToken];
	}
}

- (void)endVideoChat {
	OTError* error = nil;
	[_session disconnect:&error];
	if (error) {
		NSLog(@"disconnect failed with error: (%@)", error);
	}
	[self cleanupPublisher];
	[self cleanupSubscriber];
	_toLat=0, _toLon=0, _toAlt=0;
	[self hideArrows];
}

#pragma mark - UI Interaction

- (void)onOtherTapped:(UITapGestureRecognizer *)recognizer {
	NSLog(@"TAPPED!");
}

- (IBAction)onStartTapped:(id)sender {
}

- (IBAction)onDebugSwitchTapped:(id)sender {
	_debugActive = self.debugSwitch.on;
	
	if (_debugActive) {
		[self showDebug];
	} else {
		[self hideDebug];
	}

	[self updateViewAngle];
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
	if (textField == _toLatitudeTextField) {
		_toLat = textField.text.doubleValue;
	} else if (textField == _toLongitudeTextField) {
		_toLon = textField.text.doubleValue;
	} else if (textField == _toAltitudeTextField) {
		_toAlt = textField.text.doubleValue;
	}
	self.currentResponder = nil;
	[self.placesPicker selectRow:0 inComponent:0 animated:YES];
	[self updateViewAngle];
}

#pragma mark - eddaOtherViewDelegate

- (void)eddaOtherViewStartedZoomIn:(eddaOtherView *)view {
	//	[view setNeedsDisplay];
}

- (void)eddaOtherViewDidZoomIn:(eddaOtherView *)view {
//	_activeCamera = 0;
	_videoActive = NO;
	[self refreshVideoFeeds];

	[self startVideoChat];
}

- (void)eddaOtherViewStartedZoomOut:(eddaOtherView *)view {
//	_activeCamera = 0;
//	_videoActive = NO;
//	[self refreshVideoFeeds];
	[self endVideoChat];
}

- (void)eddaOtherViewDidZoomOut:(eddaOtherView *)view {
	_activeCamera = 1;
	_videoActive = YES;
	[self refreshVideoFeeds];
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
		PFUser * thisUser = [ParseHelper loggedInUser] ;
		[ParseHelper saveUserWithLocationToParse:thisUser :[PFGeoPoint geoPointWithLocation:self.currentLocation] :[NSNumber numberWithDouble:self.currentLocation.altitude]];
		[self updateViewAngle];
	}
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
//	NSLog(@"didUpdateHeading: %@", newHeading);
    self.currentHeading = newHeading;
	
    if (self.currentHeading != nil) {
        [self headingLabel].text = [NSString stringWithFormat:@"%.1f", self.currentHeading.trueHeading];
		[self updateArrows];
	}
}

- (BOOL)locationManagerShouldDisplayHeadingCalibration:(CLLocationManager *)manager{
	if( !self.currentHeading ) return YES; // Got nothing, We can assume we got to calibrate.
	else if( self.currentHeading.headingAccuracy < 0 ) return YES; // 0 means invalid heading. we probably need to calibrate
	else if( self.currentHeading.headingAccuracy > 5 )return YES; // 5 degrees is a small value correct for my needs. Tweak yours according to your needs.
	else return NO; // All is good. Compass is precise enough.
}

#pragma mark - Geocoding

- (void)geocodeLocation:(CLLocation*)location
{
	CLGeocoder *geocoder = [[CLGeocoder alloc] init];
	
	[geocoder reverseGeocodeLocation:location completionHandler:
	 ^(NSArray* placemarks, NSError* error){
		 if ([placemarks count] > 0)
		 {
			 NSLog(@"found: %@", [[placemarks objectAtIndex:0] locality]);
			 NSString *title = [NSString stringWithFormat:@"%@",[[placemarks objectAtIndex:0] locality]];
			 appDelegate.userTitle = title;
		 }
	 }];
}

#pragma mark - GIS stuff

- (void)updateViewAngle {
	if (self.currentLocation == nil) return;
	
	_fromLat = self.currentLocation.coordinate.latitude;
	_fromLon = self.currentLocation.coordinate.longitude;
	_fromAlt = self.currentLocation.altitude;

	[self latitudeLabel].text = [NSString stringWithFormat:@"%.4f", _fromLat];
	[self longitudeLabel].text = [NSString stringWithFormat:@"%.4f", _fromLon];
	[self altitudeLabel].text = [NSString stringWithFormat:@"%.2f", _fromAlt];
	
	self.toLatitudeTextField.text = [NSString stringWithFormat:@"%f", _toLat];
	self.toLongitudeTextField.text = [NSString stringWithFormat:@"%f", _toLon];
	self.toAltitudeTextField.text = [NSString stringWithFormat:@"%f", _toAlt];
	
	viewAngle = [self findViewAngleFromLat:_fromLat fromLon:_fromLon fromAlt:_fromAlt toLat:_toLat toLon:_toLon toAlt:_toAlt];
	
	self.azimuthLabel.text = [NSString stringWithFormat:@"%.2f", viewAngle.azimuth];
	self.elevationLabel.text = [NSString stringWithFormat:@"%.2f", viewAngle.elevation];

	[self updateArrows];
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

- (IBAction)unwindToMainViewController:(UIStoryboardSegue *)unwindSegue
{
	NSLog(@"came back with place: %@ location: %@ altitude: %@", appDelegate.callReceiverTitle, appDelegate.callReceiverLocation, appDelegate.callReceiverAltitude);
	_toLat = appDelegate.callReceiverLocation.coordinate.latitude;
	_toLon = appDelegate.callReceiverLocation.coordinate.longitude;
	_toAlt = [appDelegate.callReceiverAltitude doubleValue];
	self.cityLabel.text = appDelegate.callReceiverTitle;
	[self updateViewAngle];
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

#pragma mark - Parse stuff

- (void) initOutGoingCall
{
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
	NSLog(@"token: %@ sessionid: %@", token, sessionID);
//	_session = [[OTSession alloc] initWithApiKey:appDelegate.otAPIKey
//									   sessionId:sessionID
//										delegate:self];
	
//	[_session addObserver:self forKeyPath:@"connectionCount"
//				  options:NSKeyValueObservingOptionNew
//				  context:nil];
	
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
 * Asynchronously begins the session connect process. Some time later, we will
 * expect a delegate method to call us back with the results of this action.
 */
//- (void)doConnect
//{
//    OTError *error = nil;
//    
//    [_session connectWithToken:kToken error:&error];
//    if (error)
//    {
//        [self showAlert:[error localizedDescription]];
//    }
//}

/**
 * Sets up an instance of OTPublisher to use with this session. OTPubilsher
 * binds to the device camera and microphone, and will provide A/V streams
 * to the OpenTok session.
 */
- (void)doPublish
{
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
    
    // Step 2: We have successfully connected, now instantiate a publisher and
    // begin pushing A/V streams into OpenTok.
    [self doPublish];
}

- (void)sessionDidDisconnect:(OTSession*)session
{
    NSString* alertMessage =
    [NSString stringWithFormat:@"Session disconnected: (%@)",
     session.sessionId];
    NSLog(@"sessionDidDisconnect (%@)", alertMessage);
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

- (void)session:(OTSession*)session didDropStream:(OTStream*)stream
{
	NSLog(@"session didDropStream (%@)", stream.streamId);
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
    if ([_subscriber.stream.connection.connectionId
         isEqualToString:connection.connectionId])
    {
        [self cleanupSubscriber];
    }
}

- (void) session:(OTSession*)session didFailWithError:(OTError*)error
{
    NSLog(@"didFailWithError: (%@)", error);
}

# pragma mark - OTSubscriber delegate callbacks
- (void)subscriberVideoDataReceived:(OTSubscriber *)subscriber {
}

- (void)subscriberDidConnectToStream:(OTSubscriber*)subscriber
{
    NSLog(@"subscriberDidConnectToStream (%@)",
          subscriber.stream.connection.connectionId);
    assert(_subscriber == subscriber);
    [_subscriber.view setFrame:self.otherView.frame];
	[self.otherView insertSubview:_subscriber.view atIndex:0];
}

- (void)subscriber:(OTSubscriber*)subscriber didFailWithError:(OTError*)error
{
    NSLog(@"subscriber %@ didFailWithError %@",
          subscriber.stream.streamId,
          error);
    [self performSelector:@selector(doneStreaming:) withObject:nil afterDelay:5.0];
}

- (IBAction)doneStreaming:(id)sender {
    [self disConnectAndGoBack];
}

- (void) disConnectAndGoBack {
	[self endVideoChat];
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
    [self cleanupPublisher];
}

- (void)publisherDidStartStreaming:(OTPublisher *)publisher
{
	NSLog(@"publisherDidStartStreaming: %@", publisher);
}

-(void)publisherDidStopStreaming:(OTPublisher*)publisher
{
	NSLog(@"publisherDidStopStreaming:%@", publisher);
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
