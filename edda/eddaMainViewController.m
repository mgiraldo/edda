//
//  eddaMainViewController.m
//  edda
//
//  Created by Mauricio Giraldo on 28/8/14.
//  Copyright (c) 2014 Ping Pong Estudio. All rights reserved.
//

#import <Accelerate/Accelerate.h>
#import <ImageIO/ImageIO.h>
#import "eddaMainViewController.h"
#import "LSViewController.h"
#import "geodesic.h"
#import "utils.h"

@interface eddaMainViewController () {
	NSString *sessionID;
	NSUInteger videoChatOpponentID;
}

@property (strong, nonatomic) NSMutableSet *disconnectListeners;

@end

@implementation eddaMainViewController {
	int m_mode;
	int m_connectionAttempts;
	NSNumber * m_receiverID;
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
BOOL _isOpponentAligned = NO;

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
	
	videoChatOpponentID = 0;
	
	self.appDelegate = (eddaAppDelegate*)[[UIApplication sharedApplication] delegate];

	// other view
	self.otherView = [[eddaOtherView alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
	self.otherView.hidden = YES;
	self.otherView.delegate = self;
	[self.view insertSubview:self.otherView belowSubview:self.controlsView];

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
	[self refreshBackCameraFeed];
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
	[QBChat instance].delegate = self;
	QBUUser *currentUser = [QBUUser user];
	currentUser.ID = self.appDelegate.loggedInUser.ID;
	currentUser.password = [QBHelper uniqueDeviceIdentifier];
	[[QBChat instance] loginWithUser:currentUser];
	if (self.videoChat == nil) {
		self.videoChat = [[QBChat instance] createAndRegisterVideoChatInstance];
	}
	[NSTimer scheduledTimerWithTimeInterval:30
									 target:[QBChat instance]
								   selector:@selector(sendPresence)
								   userInfo:nil
									repeats:YES];
	
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
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showReceiverBusyMsg) name:kReceiverBusyNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didLogin) name:kLoggedInNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didCallCancel) name:kCallCancelledNotification object:nil];
}

//if and when a call arrives
- (void) didCallCancel
{
	[self disconnectAndGoBack];
}

//if and when a call arrives
- (void) opponentDidCall
{
	// show call alert
	//
	if (self.callAlert == nil) {
		NSString *message = [NSString stringWithFormat:@"%@ is calling. Would you like to answer?", self.appDelegate.callerTitle];
		self.callAlert = [[UIAlertView alloc] initWithTitle:@"Call" message:message delegate:self cancelButtonTitle:@"Decline" otherButtonTitles:@"Accept", nil];
		[self.callAlert show];
	}
	
	// hide call alert if opponent has canceled call
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideCallAlert) object:nil];
	[self performSelector:@selector(hideCallAlert) withObject:nil afterDelay:4];
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
}

- (void)updateInterface:(NSTimer *)timer {
	self.endButton.hidden = !_isChatting;
	self.startButton.hidden = _isChatting;

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

//	[self.otherView setTappable:_isAligned];

	[self pointObjects:correctHeading pitch:correctPitch];
	
	if (self.receiverObject != nil) {
		NSDictionary *custom = [QBHelper QBCustomDataToObject:self.receiverObject.customData];
		BOOL alignment = [[custom valueForKey:@"alignment"] boolValue];
		_isOpponentAligned = alignment;
		[self.otherView setActiveState:_isOpponentAligned];
	}
	
	[self updateVideoChatViews];
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
}

#pragma mark - Video stuff
- (void)initRearCamera {
	if (!_rearVideoInited) {
		_rearVideoInited = YES;
		NSError *error = nil;
		self.rearSession = [[AVCaptureSession alloc] init];
		
		if ([self.rearSession canSetSessionPreset:AVCaptureSessionPresetMedium]) {
			[self.rearSession setSessionPreset:AVCaptureSessionPresetMedium];
		}
		
		self.rearVideoCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
		self.rearVideoInput = [AVCaptureDeviceInput deviceInputWithDevice:self.rearVideoCaptureDevice error:&error];
		if (self.rearVideoInput) {
			[self.rearSession addInput:self.rearVideoInput];
			self.rearPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.rearSession];
			self.rearPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
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

- (void)updateVideoChatViews {
	if (_isOpponentAligned) {
		self.opponentVideoView.layer.borderColor = [UIColor greenColor].CGColor;
		self.statusLabel.text = @"";
	} else {
		self.opponentVideoView.layer.borderColor = [UIColor grayColor].CGColor;
		self.statusLabel.text = [NSString stringWithFormat:@"%@ is not aligned!", m_mode == streamingModeIncoming ? self.appDelegate.callerTitle : self.appDelegate.callReceiverTitle];
		// TODO: apply some blur to video
	}
	
	if (!_isAligned) {
		self.statusLabel.text = @"You are not aligned!";
		// TODO: apply some blur to video
	}
}

- (void)refreshBackCameraFeed {
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

- (void)createVideoChatViews {
	NSLog(@"createChatViews");
	CGRect viewBounds = self.view.bounds;
	CGFloat topBarOffset = self.topLayoutGuide.length + _arrowSize + _arrowSize;
	
	if (self.opponentVideoView == nil) {
		self.opponentVideoView = [[UIView alloc] initWithFrame:self.view.frame];
		[self.view insertSubview:self.opponentVideoView belowSubview:self.controlsView];
		self.opponentVideoView.layer.borderWidth = 5;
		self.opponentVideoView.hidden = YES;
	}
	
	if (self.myVideoView == nil) {
		self.myVideoView = [[UIView alloc] initWithFrame:CGRectMake(viewBounds.size.width * .5 - _previewWidth * .5, topBarOffset + _arrowMargin, _previewWidth, _previewHeight)];
		[self.view insertSubview:self.myVideoView belowSubview:self.controlsView];
		self.myVideoView.hidden = YES;
	}
}

- (void)startVideoChat {
	_isChatting = YES;
	
	if (self.appDelegate.callReceiverID != nil && m_mode != streamingModeIncoming) {
		NSLog(@"calling: %@", self.appDelegate.callReceiverID);
		if(self.videoChat == nil){
			self.videoChat = [[QBChat instance] createAndRegisterVideoChatInstance];
		}
		
		self.videoChat.isUseCustomVideoChatCaptureSession = YES;

		[self.videoChat callUser:self.appDelegate.callReceiverID.integerValue conferenceType:QBVideoChatConferenceTypeAudioAndVideo];
		
		[self createVideoChatViews];
		
		[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
		
		// push notify the reciever
		NSString * message = [NSString stringWithFormat:@"You have a call from %@!", self.appDelegate.userTitle];
		NSString * userid = [NSString stringWithFormat:@"%@", self.appDelegate.callReceiverID];
		
		QBMPushMessage * myMessage = [QBMPushMessage pushMessage];
		myMessage.alertBody = message;
		myMessage.additionalInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%@",[NSNumber numberWithInt:(int)self.appDelegate.loggedInUser.ID]], @"callerID", self.appDelegate.userTitle, @"callerTitle", nil];
		
		[QBRequest sendPush:myMessage toUsers:userid successBlock:^(QBResponse *response, QBMEvent *event) {
			[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
		} errorBlock:^(QBError *error) {
			NSLog(@"Errors=%@", [error.reasons description]);
			[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
		}];
	}
}

-(void) setupVideoCapture{
	NSLog(@"setupVideoCapture");
	self.frontSession = [[AVCaptureSession alloc] init];
 
	__block NSError *error = nil;
 
	// set preset
	[self.frontSession setSessionPreset:AVCaptureSessionPresetLow];
 
 
	// Setup the Video input
	AVCaptureDevice *videoDevice = [self frontFacingCamera];

	//
	AVCaptureDeviceInput *captureVideoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
	if(error){
		QBDLogEx(@"deviceInputWithDevice Video error: %@", error);
	}else{
		if ([self.frontSession canAddInput:captureVideoInput]){
			[self.frontSession addInput:captureVideoInput];
		}else{
			QBDLogEx(@"cantAddInput Video");
		}
	}
 
	// Setup Video output
	AVCaptureVideoDataOutput *videoCaptureOutput = [[AVCaptureVideoDataOutput alloc] init];
	videoCaptureOutput.alwaysDiscardsLateVideoFrames = YES;
	
	// set FPS
	int _frameRate = 5;
	if ([videoDevice respondsToSelector:@selector(setActiveVideoMinFrameDuration:)] &&
		[videoDevice respondsToSelector:@selector(setActiveVideoMaxFrameDuration:)]) {
		
		NSError *error;
		[videoDevice lockForConfiguration:&error];
		if (error == nil) {
#if defined(__IPHONE_7_0)
			[videoDevice setActiveVideoMinFrameDuration:CMTimeMake(1, _frameRate)];
			[videoDevice setActiveVideoMaxFrameDuration:CMTimeMake(1, _frameRate)];
#endif
		}
		[videoDevice unlockForConfiguration];
		
	} else {
		
		for (AVCaptureConnection *connection in videoCaptureOutput.connections)
		{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
			if ([connection respondsToSelector:@selector(setVideoMinFrameDuration:)])
				connection.videoMinFrameDuration = CMTimeMake(1, _frameRate);
			
			if ([connection respondsToSelector:@selector(setVideoMaxFrameDuration:)])
				connection.videoMaxFrameDuration = CMTimeMake(1, _frameRate);
#pragma clang diagnostic pop
		}
	}
	// end FPS
 
	//
	// Set the video output to store frame in BGRA (It is supposed to be faster)
	NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
	NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
	NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
	[videoCaptureOutput setVideoSettings:videoSettings];
	/*And we create a capture session*/
	if([self.frontSession canAddOutput:videoCaptureOutput]){
		[self.frontSession addOutput:videoCaptureOutput];
	}else{
		QBDLogEx(@"cantAddOutput");
	}
 
	/*We create a serial queue to handle the processing of our frames*/
	dispatch_queue_t callbackQueue= dispatch_queue_create("cameraQueue", NULL);
	[videoCaptureOutput setSampleBufferDelegate:self queue:callbackQueue];
 
	// Add preview layer
	AVCaptureVideoPreviewLayer *prewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.frontSession];
	[prewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
	CGRect layerRect = [[self.myVideoView layer] bounds];
	[prewLayer setBounds:layerRect];
	[prewLayer setPosition:CGPointMake(CGRectGetMidX(layerRect),CGRectGetMidY(layerRect))];
	self.myVideoView.hidden = NO;
	[self.myVideoView.layer addSublayer:prewLayer];
 
 
	/*We start the capture*/
	[self.frontSession startRunning];
}

- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition) position{
	NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
	for (AVCaptureDevice *device in devices) {
		if ([device position] == position) {
			return device;
		}
	}
	return nil;
}

- (AVCaptureDevice *) frontFacingCamera{
	return [self cameraWithPosition:AVCaptureDevicePositionFront];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput  didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
	// Usually we just forward camera frames to QuickBlox SDK
	// But we also can do something with them before, for example - apply some video filters or so
	if ([connection isVideoOrientationSupported]) {
		[connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
	}
	[self.videoChat processVideoChatCaptureVideoSample:sampleBuffer];
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
	[self disconnectAndGoBack];
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
	_videoActive = NO;
	[view setNeedsDisplay];
}

- (void)eddaOtherViewDidZoomIn:(eddaOtherView *)view {
	_videoActive = NO;
	if (_isChatting) {
		[self connect];
	}
	[self refreshBackCameraFeed];
}

- (void)eddaOtherViewStartedZoomOut:(eddaOtherView *)view {
	_videoActive = YES;
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
		self.appDelegate.currentLocation = self.currentLocation;
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
	NSLog(@"came back with nickname: %@ location: %@ altitude: %@", self.appDelegate.callReceiverTitle, self.appDelegate.callReceiverLocation, self.appDelegate.callReceiverAltitude);
	_isChatting = YES;
	
	m_mode = streamingModeOutgoing;

	[self pointToUser:self.appDelegate.callReceiverTitle withID:self.appDelegate.callReceiverID andLocation:self.appDelegate.callReceiverLocation andAltitude:self.appDelegate.callReceiverAltitude.doubleValue];

	[self startVideoChat];
}

- (IBAction)unwindToMainViewController:(UIStoryboardSegue *)unwindSegue
{
	NSLog(@"canceled");
	m_receiverID = nil;
	self.appDelegate.callReceiverID = m_receiverID;
	self.appDelegate.callReceiverTitle = @"";
	self.appDelegate.callReceiverLocation = nil;
	self.appDelegate.callReceiverAltitude = 0;
	_toLat = 0;
	_toLon = 0;
	_toAlt = 0;
	self.cityLabel.text = self.appDelegate.callReceiverTitle;
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
	NSString *login = [NSString stringWithFormat:@"%@_%@", self.appDelegate.userTitle, [QBHelper uniqueDeviceIdentifier]];
	NSString *password = [QBHelper uniqueDeviceIdentifier];
	NSString *username = self.appDelegate.userTitle;
	@weakify(self);
	[QBRequest logInWithUserLogin:login password:password successBlock:^(QBResponse *response, QBUUser *user) {
		@strongify(self);
		// success
		NSLog(@"log in success!");
		eddaAppDelegate * mainDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
		mainDelegate.loggedInUser = user;
		[self userHasLoggedIn];
	} errorBlock:^(QBResponse *response) {
		// error / try sign up
		[QBHelper signUpUser:username];
	}];
}

- (void)reject{
	NSLog(@"reject");
	_isChatting = NO;
	// Reject call
	//
	if(self.videoChat == nil){
		self.videoChat = [[QBChat instance] createAndRegisterVideoChatInstanceWithSessionID:sessionID];
	}
	[self.videoChat rejectCallWithOpponentID:videoChatOpponentID];
	//
	//
	[self disconnectAndGoBack];
}

- (void)accept{
	NSLog(@"accept id: %@", sessionID);
	_isChatting = YES;
	
	// Setup video chat
	//
	if(self.videoChat == nil){
		self.videoChat = [[QBChat instance] createAndRegisterVideoChatInstanceWithSessionID:sessionID];
	}

	self.videoChat.isUseCustomVideoChatCaptureSession = YES;

	// Accept call
	//
	[self.videoChat acceptCallWithOpponentID:videoChatOpponentID conferenceType:QBVideoChatConferenceTypeAudioAndVideo];
	
	[self createVideoChatViews];
}

- (void)hideCallAlert{
	[self.callAlert dismissWithClickedButtonIndex:-1 animated:YES];
	self.callAlert = nil;
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
	NSLog(@"RIIIING! id:%lu session:%@", (unsigned long)userID, _sessionID);
	videoChatOpponentID = userID;
	sessionID = _sessionID;
	m_mode = streamingModeIncoming; //connect, publish, subscribe
	m_connectionAttempts = 1;

	[self findCallerData];
	
	// play call music
	//
//	if(ringingPlayer == nil){
//		NSString *path =[[NSBundle mainBundle] pathForResource:@"ringing" ofType:@"wav"];
//		NSURL *url = [NSURL fileURLWithPath:path];
//		ringingPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:NULL];
//		ringingPlayer.delegate = self;
//		[ringingPlayer setVolume:1.0];
//		[ringingPlayer play];
//	}
}

-(void) chatCallUserDidNotAnswer:(NSUInteger)userID{
	NSLog(@"chatCallUserDidNotAnswer %lu", (unsigned long)userID);
	[self disconnectAndGoBack];
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Edda" message:@"User isn't answering. Please try again later." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
}

-(void) chatCallDidAcceptByUser:(NSUInteger)userID{
	NSLog(@"call accepted by: %d", (int)userID);
}

-(void) chatCallDidRejectByUser:(NSUInteger)userID{
	NSLog(@"chatCallDidRejectByUser %lu", (unsigned long)userID);
	[self disconnectAndGoBack];
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Edda" message:@"User has rejected your call." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
}

- (void)chatCallDidStartWithUser:(NSUInteger)userID sessionID:(NSString *)sID{
	NSLog(@"call started with user: %d session: %@", (int)userID, sID);
	videoChatOpponentID = userID;
	[self fireOpponentAlignedTimer];
}

-(void) chatCallDidStopByUser:(NSUInteger)userID status:(NSString *)status{
	NSLog(@"chatCallDidStopByUser %lu purpose %@", (unsigned long)userID, status);
	
	if([status isEqualToString:kStopVideoChatCallStatus_OpponentDidNotAnswer]){
		
		self.callAlert.delegate = nil;
		[self.callAlert dismissWithClickedButtonIndex:0 animated:YES];
		self.callAlert = nil;
		
	}
	
	[self disconnectAndGoBack];
}

- (void)didReceiveAudioBuffer:(AudioBuffer)buffer{
	NSLog(@"received audio buffer");
}

#pragma mark - Timers

- (void) fireOpponentAlignedTimer
{
	if (self.activeTimer && [self.activeTimer isValid])
		return;
	self.activeTimer = [NSTimer scheduledTimerWithTimeInterval:1
														target:self
													  selector:@selector(onOpponentAlignedTimer:)
													  userInfo:nil
													   repeats:YES];
}
- (void) stopOpponentAlignedTimer {
	if (self.activeTimer && [self.activeTimer isValid])
		[self.activeTimer invalidate];
}
- (void) onOpponentAlignedTimer:(NSTimer *)timer {
//	 NSLog(@"mode: %d, id: %lu", m_mode, (unsigned long)videoChatOpponentID);
	if (videoChatOpponentID != 0) {
		@weakify(self);
		[QBRequest userWithID:videoChatOpponentID successBlock:^(QBResponse *response, QBUUser *user) {
			@strongify(self);
			// success
			self.receiverObject = user;
		} errorBlock:^(QBResponse *response) {
			// error
		}];
	}
}

#pragma mark - QB stuff

-(void) findCallerData
{
	@weakify(self);
	[QBRequest userWithID:videoChatOpponentID successBlock:^(QBResponse *response, QBUUser *user) {
		@strongify(self);
		// success
		self.receiverObject = user;

		NSNumber *userID = [NSNumber numberWithInteger:user.ID];
		NSRange underscore = [user.login rangeOfString:@"_" options:NSBackwardsSearch];
		NSString *userTitle = [user.login substringToIndex:underscore.location];
		NSDictionary *custom = [QBHelper QBCustomDataToObject:user.customData];
		
		CLLocation * location = [[CLLocation alloc] initWithLatitude:[[custom valueForKey:@"latitude"] doubleValue] longitude:[[custom valueForKey:@"longitude"] doubleValue]];
		NSNumber *userAltitude = [custom valueForKey:@"altitude"];
		
		self.appDelegate.callerTitle = userTitle;
		self.appDelegate.callerID = userID.stringValue;
		
		[self opponentDidCall];
		[self pointToUser:userTitle withID:userID andLocation:location andAltitude:userAltitude.doubleValue];
	} errorBlock:^(QBResponse *response) {
		// error
	}];
}

- (void)connect
{
	NSLog(@"connecting");
	[self.view bringSubviewToFront:self.myVideoView];
	[self.view bringSubviewToFront:self.controlsView];
	[self setupVideoCapture];
	self.videoChat.viewToRenderOpponentVideoStream = self.opponentVideoView;
	self.videoChat.viewToRenderOwnVideoStream = self.myVideoView;
	self.myVideoView.hidden = NO;
	self.opponentVideoView.hidden = NO;
	NSLog(@"me: %@, opponent: %@", self.myVideoView,self.opponentVideoView);
}

- (void)disconnect
{
	[self.videoChat finishCall];
	
	[self.opponentVideoView removeFromSuperview];
	[self.myVideoView removeFromSuperview];
	self.opponentVideoView = nil;
	self.myVideoView = nil;

	[[QBChat instance] unregisterVideoChatInstance:self.videoChat];
	self.videoChat = nil;
}

- (void) disconnectAndGoBack {
	_isChatting = NO;
	
	[self disconnect];

	self.endButton.hidden = YES;
	self.startButton.hidden = NO;
	self.statusLabel.text = @"";

	m_receiverID = nil;
	self.appDelegate.callReceiverID = m_receiverID;
	self.appDelegate.callReceiverTitle = @"";
	self.appDelegate.callReceiverLocation = nil;
	self.appDelegate.callReceiverAltitude = 0;
	
	videoChatOpponentID = 0;
	
	_toLat=0, _toLon=0, _toAlt=0;
	
	self.cityLabel.text = @"";
	self.receiverObject = nil;
	
	[self stopOpponentAlignedTimer];
	[self hideArrows];
	[self.otherView zoomOut];
	[self refreshBackCameraFeed];
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

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
	
	// Call alert
	switch (buttonIndex) {
			// Reject
		case 0:
			[self reject];
			break;
			// Accept
		case 1:
			[self accept];
			break;
			
		default:
			break;
	}
	
	self.callAlert = nil;
}


@end
