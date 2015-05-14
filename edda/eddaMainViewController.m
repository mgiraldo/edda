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
#import "eddaWelcomeViewController.h"
#import "LSViewController.h"
#import "geodesic.h"
#import "utils.h"

@interface eddaMainViewController () {
	NSString *sessionID;
	NSUInteger videoChatOpponentID;
}

@property (nonatomic) UIView *blackView;

@end

@implementation eddaMainViewController {
	int m_mode;
	int m_connectionAttempts;
	NSNumber * m_receiverID;
	NSDate *alignedTimerStart;
}

// first run
static bool _cameraEnabled = false;
static bool _locationEnabled = false;
static bool _microphoneEnabled = false;

// self preview size
static const float _myDiameter = 80;
static const float _opponentDiameter = 260;

static CMMotionManager *motionManager;

static BOOL _videoActive = NO;
static BOOL _rearVideoInited = NO;
static BOOL _haveArrows = NO;
static BOOL _isChatting = NO;
static BOOL _isAligned = NO;
static BOOL _isOpponentAligned = NO;
static BOOL _hasFirstAligned = NO;

static float _headingThreshold = 20.0f;
static float _pitchThreshold = 10.0f;

static NSArray *_places;
static NSArray *_placeCoordinates;

// proj4
static projPJ pj_geoc;
static projPJ pj_geod;

static double _fromLat = 0.0;
static double _fromLon = 0.0;
static double _fromAlt = 0.0;

static double _toLat = 0.0;
static double _toLon = 0.0;
static double _toAlt = 0.0;

static sViewAngle viewAngle;

static float _alignmentError = 1.0f;

// arrows
static float _arrowSize = 44.0f;
static float _arrowMargin = 5.0f;

static int callSize = 160;
static int callTop = 200;

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

	// tutorial stuff
	self.pageTitles = @[@"Tap \"START CALL\" to access the list.", @"Use the list or map to find your friend.", @"Follow the arrows. The circle indicates your friend's location.", @"Maintain orientation during the call or the view will be obscured!"];
	self.pageImages = @[@"tutorial1.mp4", @"tutorial2.mp4", @"tutorial3.mp4", @"tutorial4.mp4"];

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	BOOL didTutorial = [[defaults valueForKey:@"tutorial"] boolValue];

	_cameraEnabled = [[defaults valueForKey:@"cameraEnabled"] boolValue];
	_locationEnabled = [[defaults valueForKey:@"locationEnabled"] boolValue];
	_microphoneEnabled = [[defaults valueForKey:@"microphoneEnabled"] boolValue];

	if (!didTutorial) {
		[self startTutorial:nil];
	}

	if (!_locationEnabled || !_cameraEnabled || !_microphoneEnabled) {
		[self requestPermissions];
	}

	// the rest
	videoChatOpponentID = 0;
	
	self.appDelegate = (eddaAppDelegate*)[[UIApplication sharedApplication] delegate];
	
	self.statusLabel.text = @"";

	self.blockingView.hidden = YES;
	
	// other view
	self.otherView = [[eddaOtherView alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
	self.otherView.hidden = YES;
	self.otherView.delegate = self;
	[self.view insertSubview:self.otherView belowSubview:self.controlsView];
	
	self.tutorialButton.alpha = 0.0;
	self.backgroundView.alpha = 0.0;
	self.settingsButton.alpha = 0.0;
	self.infoButton.alpha = 0.0;
	self.startButton.alpha = 0.0;
	
	[UIView animateKeyframesWithDuration:1.0 delay:0.25 options:UIViewKeyframeAnimationOptionCalculationModeLinear animations:^{
		[UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:0.2 animations:^{
			self.backgroundView.alpha = 1.0;
		}];
		[UIView addKeyframeWithRelativeStartTime:0.2 relativeDuration:0.2 animations:^{
			self.settingsButton.alpha = 1.0;
		}];
		[UIView addKeyframeWithRelativeStartTime:0.4 relativeDuration:0.2 animations:^{
			self.infoButton.alpha = 1.0;
		}];
		[UIView addKeyframeWithRelativeStartTime:0.6 relativeDuration:0.2 animations:^{
			self.startButton.alpha = 1.0;
		}];
		[UIView addKeyframeWithRelativeStartTime:0.8 relativeDuration:0.2 animations:^{
			self.tutorialButton.alpha = 1.0;
		}];
	} completion:nil];
	
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
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	_cameraEnabled = [[defaults valueForKey:@"cameraEnabled"] boolValue];
	_locationEnabled = [[defaults valueForKey:@"locationEnabled"] boolValue];
	_microphoneEnabled = [[defaults valueForKey:@"microphoneEnabled"] boolValue];

	if (!_locationEnabled || !_cameraEnabled || !_microphoneEnabled) return;

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
	self.locationManager = [[CLLocationManager alloc] init];
	self.locationManager.delegate = self;
	self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
	
	// now get the location
	
	// init Proj.4 params
	if (!(pj_geod = pj_init_plus("+proj=latlong +datum=WGS84 +units=m")) )
		NSLog(@"Could not initialise MERCATOR");
	if (!(pj_geoc = pj_init_plus("+proj=geocent +datum=WGS84")) )
		NSLog(@"Could not initialise CARTESIAN");
	
	[self userHasLoggedIn];
	[self setupArrows];
	[self hideArrows];
	[self refreshBackCameraFeed];
	[super viewDidAppear:animated];
}

- (BOOL)checkStatusBarHidden {
	return [UIApplication sharedApplication].statusBarHidden;
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
//	NSLog(@"prepare for segue: [%@] sender: [%@]", [segue identifier], sender);
	if ([[segue identifier] isEqualToString:@"showSettings"]) {
		[[segue destinationViewController] setDelegate:self];
	} else if ([[segue identifier] isEqualToString:@"showList"]) {
		[[segue destinationViewController] setDelegate:self];
	} else if ([[segue identifier] isEqualToString:@"showInfo"]) {
		[[segue destinationViewController] setDelegate:self];
	} else if ([[segue identifier] isEqualToString:@"showGlobe"]) {
		[[segue destinationViewController] setDelegate:self];
	}
}

#pragma mark - Startup

- (void)requestPermissions {
	// Create page view controller
	eddaWelcomeViewController *welcomeViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"WelcomeViewController"];
	
	// Change the size of page view controller
	welcomeViewController.view.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
	
	[self addChildViewController:welcomeViewController];
	[self.view addSubview:welcomeViewController.view];
	[welcomeViewController didMoveToParentViewController:self];
}

- (void) userHasLoggedIn
{
	if (!self.appDelegate.bFullyLoggedIn) return;
	[[QBChat instance] addDelegate:self];
	QBUUser *currentUser = [QBUUser user];
	currentUser.ID = self.appDelegate.loggedInUser.ID;
	currentUser.password = [QBHelper uniqueDeviceIdentifier];
	[[QBChat instance] loginWithUser:currentUser];
//	NSLog(@"log in: %@", self.appDelegate.loggedInUser);
	[NSTimer scheduledTimerWithTimeInterval:30
									 target:[QBChat instance]
								   selector:@selector(sendPresence)
								   userInfo:nil
									repeats:YES];
	
	// iOS 8 not authorized by default
	if([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
		[self.locationManager requestWhenInUseAuthorization];
	}
	
	[self.locationManager startUpdatingLocation];
	[self.locationManager startUpdatingHeading];

	// interface refresh timer
	[NSTimer scheduledTimerWithTimeInterval:0.05
									 target:self
								   selector:@selector(updateInterface:)
								   userInfo:nil
									repeats:YES];
	
	[self updateViewAngle];
}

- (void) registerNotifs
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showReceiverBusyMsg) name:kReceiverBusyNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userHasLoggedIn) name:kLoggedInNotification object:nil];
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
	[self playSound:@"Zen_mg_JFK_LO_short" type:@"wav"];
	// show call alert
	//
	if (self.callAlert == nil) {
		NSString *message = [NSString stringWithFormat:@"%@\nis calling!", self.appDelegate.callerTitle];
		self.callAlert = [[UIAlertView alloc] initWithTitle:@"🔊 Incoming call 🔊" message:message delegate:self cancelButtonTitle:@"Decline" otherButtonTitles:@"Accept", nil];
		[self.callAlert show];
	}
	
	// hide call alert if opponent has canceled call
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideCallAlert) object:nil];
	[self performSelector:@selector(hideCallAlert) withObject:nil afterDelay:4];
}

-(void) showReceiverBusyMsg
{
//	NSLog(@"Receiver is busy on another call. Please try later.");
	self.statusLabel.text = @"Receiver is busy. Please try later.";
	[self performSelector:@selector(goBack) withObject:nil afterDelay:5.0];
}

-(void)goBack
{
	[self removeCallAnimation];
}

- (void)updateInterface:(NSTimer *)timer {
	self.endButton.hidden = !_isChatting;
	self.startButton.hidden = _isChatting;

	if (!_isChatting) return;
	if (self.currentHeading == nil || self.currentLocation == nil) return;
	if (_toLat==0 && _toLon==0 && _toAlt==0) return;
	
	// for the elevation indicator
	float pitchDeg = RAD_TO_DEG * self.currentMotion.attitude.pitch;
	float pitchRaw = pitchDeg - 90;
	float correctPitch = viewAngle.elevation - pitchRaw;
	
	// for the heading indicator
	float correctHeading = self.currentHeading.trueHeading - viewAngle.azimuth;
	float headingAdjusted = fabsf(correctHeading);
	
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
	
	if (!_hasFirstAligned && _isAligned) {
		_hasFirstAligned = YES;
	}

	if (_isChatting && oldAligned != _isAligned) {
		[QBHelper saveUserAlignmentToQB:_isAligned];
	}
	
	if (_isAligned && !self.otherView.zoomed) {
		[self.otherView zoomIn];
	}

	[self pointObjects:correctHeading pitch:correctPitch];
	
	if (self.receiverObject != nil) {
		NSDictionary *custom = [QBHelper QBCustomDataToObject:self.receiverObject.customData];
		BOOL alignment = [[custom valueForKey:@"alignment"] boolValue];
		_isOpponentAligned = alignment;
	}
	
	[self updateVideoChatViews];
}

- (void)pointObjects:(float)heading pitch:(float)pitch {
	float xArrow, yArrow, xBox, yBox, arrowMax = 100, boxMax = self.view.window.frame.size.height * .5;
	float radiusArrow = arrowMax * ofMap(pitch, -90, 90, 0, 1, true);
	float radiusBox = boxMax * ofMap(pitch, -90, 90, 0, 1, true);
	float radians = -DEG_TO_RAD*heading;
	float inverted = radians-M_PI_2;

	float xoffset =  self.view.frame.size.width*.5f;
	float yoffset =  self.view.frame.size.height*.5f;

	xArrow = radiusArrow * cos(inverted) + xoffset;
	yArrow = radiusArrow * sin(inverted) + yoffset;
	xBox = radiusBox * cos(inverted) + xoffset;
	yBox = ofMap(pitch, -90, 90, boxMax, -boxMax, true) + yoffset;
//	yBox = radiusBox * sin(inverted) + self.view.window.bounds.size.height * .5;
	
	[self.otherView updatePosition:CGPointMake(xBox, yBox)];
	
	_alignmentError = ofMap(xBox, 0+xoffset, boxMax+xoffset, 0, 1, true) + ofMap(yBox, boxMax+yoffset, -boxMax+yoffset, 0, 1, true);
	
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
//	UIImage * arrowImage = [UIImage imageNamed:@"arrow.png"];
	UIImage * vImage = [UIImage imageNamed:@"arrowMagenta.png"];
	UIImage * hImage = [UIImage imageNamed:@"arrowCyan.png"];
	
	// help arrows
	self.N_arrowView = [[UIImageView alloc] initWithImage:vImage];
	self.N_arrowView.center = CGPointMake(viewBounds.size.width * .5, topBarOffset + _arrowSize * .5 + _arrowMargin);
	[self.view addSubview:self.N_arrowView];
	
	self.S_arrowView = [[UIImageView alloc] initWithImage:vImage];
	self.S_arrowView.transform = CGAffineTransformMakeRotation(M_PI);
	self.S_arrowView.center = CGPointMake(viewBounds.size.width * .5, viewBounds.size.height - _arrowSize * .5 - _arrowMargin);
	[self.view addSubview:self.S_arrowView];
	
	self.E_arrowView = [[UIImageView alloc] initWithImage:hImage];
	self.E_arrowView.transform = CGAffineTransformMakeRotation(M_PI_2);
	self.E_arrowView.center = CGPointMake(viewBounds.size.width - _arrowSize * .5 - _arrowMargin, viewBounds.size.height * .5);
	[self.view addSubview:self.E_arrowView];
	
	self.W_arrowView = [[UIImageView alloc] initWithImage:hImage];
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
//			NSLog(@"Cannot handle video");
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
	NSString *other = m_mode == streamingModeIncoming ? self.appDelegate.callerTitle : self.appDelegate.callReceiverTitle;

	self.statusLabel.text = @"";

	if (!_hasFirstAligned) {
		self.statusLabel.text = [NSString stringWithFormat:@"find\n%@", other];
	}
	
}

- (void)refreshBackCameraFeed {
	[self stopRearCapture];
	if (_videoActive) {
		[self startRearCapture];
//		if (_isChatting) {
//			self.otherView.hidden = NO;
//		} else {
//			self.otherView.hidden = YES;
//		}
	}
}

- (void)createVideoChatViews {
//	NSLog(@"createChatViews");
	CGRect viewBounds = self.view.bounds;
	CGFloat topBarOffset = self.topLayoutGuide.length + _arrowSize + (_arrowMargin * 2);
	
	if (self.opponentVideoView == nil) {
		self.blackView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, viewBounds.size.width, viewBounds.size.height)];
		self.blackView.backgroundColor = [UIColor blackColor];
		[self.view insertSubview:self.blackView belowSubview:self.otherView];
		self.blackView.hidden = YES;
		self.opponentVideoView = [[UIImageView alloc] initWithFrame:CGRectMake(viewBounds.size.width * .5 - (_opponentDiameter * .5), (viewBounds.size.height * .5 - (_opponentDiameter * .5)), _opponentDiameter, _opponentDiameter)];
		self.opponentVideoView.layer.cornerRadius = _opponentDiameter * .5;
		self.opponentVideoView.layer.masksToBounds = YES;
		[self.view insertSubview:self.opponentVideoView belowSubview:self.otherView];
		self.opponentVideoView.hidden = YES;
	}
	
	if (self.myVideoView == nil) {
		self.myVideoView = [[UIImageView alloc] initWithFrame:CGRectMake(viewBounds.size.width * .5 - _myDiameter * .5, topBarOffset + _arrowMargin, _myDiameter, _myDiameter)];
		self.myVideoView.layer.cornerRadius = _myDiameter * .5;
		self.myVideoView.layer.masksToBounds = YES;
		[self.view insertSubview:self.myVideoView belowSubview:self.otherView];
		self.myVideoView.hidden = YES;
	}
	
}

- (void)startVideoChat {
	_isChatting = YES;
	
	if (self.appDelegate.callReceiverID != nil && m_mode != streamingModeIncoming) {
		if(self.videoChat == nil){
			self.videoChat = [[QBChat instance] createAndRegisterVideoChatInstance];
		}
		
		self.videoChat.isUseCustomVideoChatCaptureSession = YES;
		self.videoChat.useHeadphone = [self isHeadsetPluggedIn];

		[self.videoChat callUser:self.appDelegate.callReceiverID.integerValue conferenceType:QBVideoChatConferenceTypeAudioAndVideo];
		
//		NSLog(@"calling: %@ chat: %@", self.appDelegate.callReceiverID, self.videoChat);

		[self createVideoChatViews];
		
		[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
		
		// push notify the reciever
		NSString * message = [NSString stringWithFormat:@"You have a call from %@!", self.appDelegate.userTitle];
		NSString * userid = [NSString stringWithFormat:@"%@", self.appDelegate.callReceiverID];
		
		QBMPushMessage * myMessage = [QBMPushMessage pushMessage];
		myMessage.alertBody = message;
		myMessage.soundFile = @"Zen_mg_JFK_LO_short.wav";
		myMessage.additionalInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%@",[NSNumber numberWithInt:(int)self.appDelegate.loggedInUser.ID]], @"callerID", self.appDelegate.userTitle, @"callerTitle", nil];
		
		[QBRequest sendPush:myMessage toUsers:userid successBlock:^(QBResponse *response, QBMEvent *event) {
//			NSLog(@"sent push: %@",response);
			[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
		} errorBlock:^(QBError *error) {
//			NSLog(@"Errors=%@", [error.reasons description]);
			[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
		}];
	}
}

-(void) setupVideoCapture{
//	NSLog(@"setupVideoCapture");
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
	
	// end filter
	[self.videoChat processVideoChatCaptureVideoSample:sampleBuffer];
}

#pragma mark - UI/Interaction

- (void)pointToUser {
	self.otherView.hidden = NO;
	[self updateViewAngle];
//	NSLog(@"from %f %f %f to %f %f %f", _fromLat, _fromLon, _fromAlt, _toLat, _toLon, _toAlt);
}

- (IBAction)endButtonTapped:(id)sender {
	[self playSound:@"hangup" type:@"mp3"];

	[self saveLastLatLon];

	[self removeCallAnimation];
	[self disconnectAndGoBack];
}

#pragma mark - Globe view

- (void)saveLastLatLon {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	NSData *dataOut = [defaults objectForKey:@"callLog"];
	
	NSMutableArray *callLog;
	
	if (dataOut != nil) {
		callLog = [NSKeyedUnarchiver unarchiveObjectWithData:dataOut];
	} else {
		callLog = [[NSMutableArray alloc] init];
	}

//	NSLog(@"callLog 1: %@", callLog);

	NSArray *keys = [NSArray arrayWithObjects:
					 @"fromLat",
					 @"fromLon",
					 @"toLat",
					 @"toLon",
					 @"distance",
					 @"toNick",
					 nil];
	NSLog(@"a:%@: b:%@:", self.appDelegate.callerTitle, self.appDelegate.callReceiverTitle);
	NSString *nick = (self.appDelegate.callerTitle != nil) ? [NSString stringWithString:self.appDelegate.callerTitle] : [NSString stringWithString:self.appDelegate.callReceiverTitle];

	NSArray *objects = [NSArray arrayWithObjects:
						[NSNumber numberWithFloat:self.appDelegate.currentLocation.coordinate.latitude],
						[NSNumber numberWithFloat:self.appDelegate.currentLocation.coordinate.longitude],
						[NSNumber numberWithFloat:_toLat],
						[NSNumber numberWithFloat:_toLon],
						[NSNumber numberWithFloat:viewAngle.distance],
						nick,
						nil];
	
//	NSLog(@"objects: %@", objects);
//	NSLog(@"keys: %@", keys);
	
	NSDictionary *newLog = [NSDictionary dictionaryWithObjects:objects forKeys:keys];

	[callLog addObject:newLog];

//	NSLog(@"callLog: %@", callLog);

	NSData *dataIn = [NSKeyedArchiver archivedDataWithRootObject:callLog];

	[defaults setObject:dataIn forKey:@"callLog"];
	
	[defaults setObject:[objects objectAtIndex:0] forKey:@"last_fromLat"];
	[defaults setObject:[objects objectAtIndex:1] forKey:@"last_fromLon"];
	[defaults setObject:[objects objectAtIndex:2] forKey:@"last_toLat"];
	[defaults setObject:[objects objectAtIndex:3] forKey:@"last_toLon"];
	[defaults setObject:[objects objectAtIndex:4] forKey:@"last_distance"];

	[defaults synchronize];
}

- (void)showGlobeView {
	if ([[[UIDevice currentDevice] systemVersion] compare:@"8.0" options:NSNumericSearch] != NSOrderedAscending) {
		[self performSegueWithIdentifier:@"showGlobe" sender:self];
	}
}

- (void)globeViewControllerDidFinish:(eddaGlobeViewController *)controller
{
	[self dismissViewControllerAnimated:YES completion:nil];
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
	_videoActive = NO;
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
//	NSLog(@"didUpdateToLocation: %@", newLocation);
	self.currentLocation = newLocation;
	
	if (self.currentLocation != nil) {
		[self.locationManager stopUpdatingLocation];
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
	
	double distance = sqrt(dx*dx + dy*dy + dz*dz);
		
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
	output.distance = distance;

	return output;
}

#pragma mark - Call Animation

- (void)showCallAnimation {
	self.statusLabel.text = [NSString stringWithFormat:@"waiting for\n%@\nto accept",  self.appDelegate.callReceiverTitle];
	if (self.callAnimation == nil) {
		self.callAnimation = [[eddaCallAnimationView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - callSize) *.5, callTop, callSize, callSize)];
	}
	[self.view insertSubview:self.callAnimation belowSubview:self.statusLabel];
	[self.callAnimation startAllAnimations:nil];
}

- (void)removeCallAnimation {
	self.statusLabel.text = @"";
	[self.callAnimation removeFromSuperview];
	self.callAnimation = nil;
}

#pragma mark - LS View

- (IBAction)unwindToVideoChat:(UIStoryboardSegue *)unwindSegue
{
//	NSLog(@"came back with nickname: %@ location: %@ altitude: %@", self.appDelegate.callReceiverTitle, self.appDelegate.callReceiverLocation, self.appDelegate.callReceiverAltitude);

	self.blockingView.hidden = NO;
	
	m_mode = streamingModeOutgoing;
	
	[self showCallAnimation];

	[self startVideoChat];
}

- (IBAction)unwindToMainViewController:(UIStoryboardSegue *)unwindSegue
{
//	NSLog(@"canceled");
	m_receiverID = nil;
	self.appDelegate.callReceiverID = m_receiverID;
	self.appDelegate.callReceiverTitle = @"";
	self.appDelegate.callReceiverLocation = nil;
	self.appDelegate.callReceiverAltitude = 0;
	_toLat = 0;
	_toLon = 0;
	_toAlt = 0;
	[self hideArrows];
	_isChatting = NO;
	self.otherView.hidden = YES;
}

#pragma mark - Modal Views

- (void)flipsideViewControllerDidFinish:(eddaFlipsideViewController *)controller
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)infoViewControllerDidFinish:(eddaInfoViewController *)controller
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark -
#pragma mark QBChatDelegate

- (void)reject{
//	NSLog(@"reject");
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
//	NSLog(@"accept id: %@", sessionID);
	_isChatting = YES;
	
	ringingPlayer = nil;
	_videoActive = YES;

	// dismiss any modal dialogs
	[self dismissViewControllerAnimated:YES completion:nil];

	// destroy tutorial in case it is open
	if (self.pageViewController != nil) {
		[self.pageViewController willMoveToParentViewController:nil];
		[self.pageViewController.view removeFromSuperview];
		[self.pageViewController removeFromParentViewController];
		self.pageViewController = nil;
	}
	
	[self refreshBackCameraFeed];
	
	[self pointToUser];

	// Setup video chat
	//
	if(self.videoChat == nil){
		self.videoChat = [[QBChat instance] createAndRegisterVideoChatInstanceWithSessionID:sessionID];
	}

	self.videoChat.isUseCustomVideoChatCaptureSession = YES;
	self.videoChat.useHeadphone = [self isHeadsetPluggedIn];

	// Accept call
	//
	NSArray *keys = [NSArray arrayWithObjects:@"latitude", @"longitude", @"altitude", nil];
	NSArray *objects = [NSArray arrayWithObjects:
						[NSNumber numberWithDouble:self.currentLocation.coordinate.latitude],
						[NSNumber numberWithDouble:self.currentLocation.coordinate.longitude],
						[NSNumber numberWithDouble:self.currentLocation.altitude],
						nil];
	NSDictionary *custom = [NSDictionary dictionaryWithObjects:objects forKeys:keys];
	[self.videoChat acceptCallWithOpponentID:videoChatOpponentID conferenceType:QBVideoChatConferenceTypeAudioAndVideo customParameters:custom];
	
//	NSLog(@"sent custom: %@", custom);
	
	[self createVideoChatViews];
}

- (void)hideCallAlert{
	[self.callAlert dismissWithClickedButtonIndex:-1 animated:YES];
	self.callAlert = nil;
}

// Chat delegate
-(void) chatDidLogin{
	// You have successfully signed in to QuickBlox Chat
//	NSLog(@"chat logged in!");
}

-(void) chatDidNotLogin{
	// Sign in to QuickBlox Chat failed
//	NSLog(@"ERROR! chat NOT logged in!");
}

-(void) chatDidReceiveCallRequestFromUser:(NSUInteger)userID withSessionID:(NSString *)_sessionID conferenceType:(enum QBVideoChatConferenceType)conferenceType{
//	NSLog(@"RIIIING! id:%lu session:%@", (unsigned long)userID, _sessionID);
	videoChatOpponentID = userID;
	sessionID = _sessionID;
	m_mode = streamingModeIncoming; //connect, publish, subscribe
	m_connectionAttempts = 1;

	[self findCallerData];
}

-(void) chatCallUserDidNotAnswer:(NSUInteger)userID{
//	NSLog(@"chatCallUserDidNotAnswer %lu", (unsigned long)userID);
	_isChatting = NO;
	[self removeCallAnimation];
	NSString *msg = [NSString stringWithFormat:@"%@\nisn't answering.\nPlease try again later.", self.appDelegate.callReceiverTitle];
	[self disconnectAndGoBack];
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No answer" message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
}

/*
 added this function to allow for updating opponent position on accept
 eg: opponent has moved since they last used the app
 */
-(void) chatCallDidAcceptByUser:(NSUInteger)userID customParameters:(NSDictionary *)customParameters{
//	NSLog(@"call accepted by: %d params: %@", (int)userID, customParameters);
	[self removeCallAnimation];
	self.blockingView.hidden = YES;
	
	_videoActive = YES;
	[self refreshBackCameraFeed];
	
	if ([customParameters objectForKey:@"latitude"] != nil) {
		CLLocationDegrees lat = [[customParameters valueForKey:@"latitude"] doubleValue];
		CLLocationDegrees lon = [[customParameters valueForKey:@"longitude"] doubleValue];
		CLLocationDistance alt = [[customParameters valueForKey:@"altitude"] doubleValue];
		CLLocation *opponentLocation = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(lat, lon) altitude:alt horizontalAccuracy:1 verticalAccuracy:1 timestamp:nil];
		self.appDelegate.callReceiverLocation = opponentLocation;
		self.appDelegate.callReceiverAltitude = [NSNumber numberWithDouble:opponentLocation.altitude];
		
//		NSLog(@"opponentLocation: %@ alt: %f", opponentLocation, alt);
	}

//	NSLog(@"callReceiverLocation: %@ callReceiverAltitude %@", self.appDelegate.callReceiverLocation, self.appDelegate.callReceiverAltitude);

	_toLat = self.appDelegate.callReceiverLocation.coordinate.latitude;
	_toLon = self.appDelegate.callReceiverLocation.coordinate.longitude;
	_toAlt = self.appDelegate.callReceiverAltitude.doubleValue;
	
	[self pointToUser];
}

-(void) chatCallDidRejectByUser:(NSUInteger)userID{
//	NSLog(@"chatCallDidRejectByUser %lu", (unsigned long)userID);
	NSString *msg = [NSString stringWithFormat:@"%@\nhas rejected your call.", self.appDelegate.callReceiverTitle];
	_isChatting = NO;
	[self removeCallAnimation];
	[self disconnectAndGoBack];
	[self playSound:@"rechaza" type:@"mp3"];
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Call rejected 😕" message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
}

- (void)chatCallDidStartWithUser:(NSUInteger)userID sessionID:(NSString *)sID{
//	NSLog(@"call started with user: %d session: %@", (int)userID, sID);
	self.blockingView.hidden = YES;
	videoChatOpponentID = userID;
	[self fireOpponentAlignedTimer];
}

-(void) chatCallDidStopByUser:(NSUInteger)userID status:(NSString *)status {
//	NSLog(@"chatCallDidStopByUser %lu purpose %@", (unsigned long)userID, status);

	[self playSound:@"hangup" type:@"mp3"];

	if([status isEqualToString:kStopVideoChatCallStatus_OpponentDidNotAnswer]){
		self.callAlert.delegate = nil;
		[self.callAlert dismissWithClickedButtonIndex:0 animated:YES];
		self.callAlert = nil;
	} else {
		[self saveLastLatLon];
	}

	[self disconnectAndGoBack];
}

- (void)didReceiveAudioBuffer:(AudioBuffer)buffer{
//	NSLog(@"received audio buffer");
}

#pragma mark -
#pragma mark AVAudioPlayerDelegate

- (BOOL)isHeadsetPluggedIn {
	AVAudioSessionRouteDescription* route = [[AVAudioSession sharedInstance] currentRoute];
	for (AVAudioSessionPortDescription* desc in [route outputs]) {
		if ([[desc portType] isEqualToString:AVAudioSessionPortHeadphones])
			return YES;
	}
	return NO;
}

-(void) playSound:(NSString *)sound type:(NSString *)type {
	if(ringingPlayer != nil){
		[ringingPlayer stop];
		ringingPlayer = nil;
	}
	NSString *path =[[NSBundle mainBundle] pathForResource:sound ofType:type];
	NSURL *url = [NSURL fileURLWithPath:path];
	ringingPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:NULL];
	ringingPlayer.delegate = self;
	[ringingPlayer setVolume:1.0];
	[ringingPlayer play];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag{
	ringingPlayer = nil;
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
//	NSLog(@"PUSH!");
	@weakify(self);
	[QBRequest userWithID:videoChatOpponentID successBlock:^(QBResponse *response, QBUUser *user) {
		@strongify(self);
		// success
		self.receiverObject = user;

		NSNumber *userID = [NSNumber numberWithInteger:user.ID];
		NSDictionary *custom = [QBHelper QBCustomDataToObject:user.customData];

		NSString *userTitle = [QBHelper decodeText:[custom valueForKey:@"username"]];
		
		CLLocation * location = [[CLLocation alloc] initWithLatitude:[[custom valueForKey:@"latitude"] doubleValue] longitude:[[custom valueForKey:@"longitude"] doubleValue]];
		NSNumber *userAltitude = [custom valueForKey:@"altitude"];
		
		self.appDelegate.callerTitle = [NSString stringWithString:userTitle];
		self.appDelegate.callerID = [NSString stringWithString:userID.stringValue];
		
		[self opponentDidCall];

		_toLat = location.coordinate.latitude;
		_toLon = location.coordinate.longitude;
		_toAlt = userAltitude.doubleValue;

	} errorBlock:^(QBResponse *response) {
		// error
	}];
}

- (void)connect
{
//	NSLog(@"connecting");
	[self.view bringSubviewToFront:self.myVideoView];
	[self.view bringSubviewToFront:self.controlsView];
	[self.view bringSubviewToFront:self.statusLabel];
	[self setupVideoCapture];
	self.videoChat.viewToRenderOpponentVideoStream = self.opponentVideoView;
	self.videoChat.viewToRenderOwnVideoStream = self.myVideoView;
	self.myVideoView.hidden = NO;
	self.opponentVideoView.hidden = NO;
	self.blackView.hidden = NO;
//	NSLog(@"me: %@, opponent: %@", self.myVideoView,self.opponentVideoView);
}

- (void)disconnect
{
	if (self.videoChat != nil)
		[self.videoChat finishCall];
	
	[self.blackView removeFromSuperview];
	[self.opponentVideoView removeFromSuperview];
	[self.myVideoView removeFromSuperview];
	self.blackView = nil;
	self.opponentVideoView = nil;
	self.myVideoView = nil;

	[[QBChat instance] unregisterVideoChatInstance:self.videoChat];
	self.videoChat = nil;
}

- (void) disconnectAndGoBack {
	if (_isChatting)
		[self showGlobeView];

	_isChatting = NO;
	_videoActive = NO;
	
	[self disconnect];

	self.blockingView.hidden = YES;
	self.endButton.hidden = YES;
	self.startButton.hidden = NO;
	self.statusLabel.text = @"";

	m_receiverID = nil;
	self.appDelegate.callReceiverID = m_receiverID;
	self.appDelegate.callReceiverTitle = @"";
	self.appDelegate.callReceiverLocation = nil;
	self.appDelegate.callReceiverAltitude = 0;
	self.appDelegate.callerTitle = nil;
	self.appDelegate.callerID = nil;
	
	videoChatOpponentID = 0;
	
	_toLat=0, _toLon=0, _toAlt=0;
	
	self.receiverObject = nil;
	[self.otherView zoomOut];
	[self stopOpponentAlignedTimer];
	[self hideArrows];
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

#pragma mark - Page View Controller Data Source

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController
{
	NSUInteger index = ((eddaTutorialContentViewController*) viewController).pageIndex;
	
	if ((index == 0) || (index == NSNotFound)) {
		return nil;
	}
	
	index--;
	return [self viewControllerAtIndex:index];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController
{
	NSUInteger index = ((eddaTutorialContentViewController*) viewController).pageIndex;
	
	if (index == NSNotFound) {
		return nil;
	}
	
	index++;
	if (index == [self.pageTitles count]) {
		return nil;
	}
	return [self viewControllerAtIndex:index];
}

- (eddaTutorialContentViewController *)viewControllerAtIndex:(NSUInteger)index
{
	if ((self.pageTitles.count == 0) || (index >= self.pageTitles.count)) {
		return nil;
	}
	
	// Create a new view controller and pass suitable data.
	eddaTutorialContentViewController *pageContentViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"TutorialContentViewController"];
	pageContentViewController.imageFile = self.pageImages[index];
	pageContentViewController.titleText = self.pageTitles[index];
	pageContentViewController.pageIndex = index;
	pageContentViewController.pageCount = self.pageTitles.count;
	
	return pageContentViewController;
}

- (NSInteger)presentationCountForPageViewController:(UIPageViewController *)pageViewController
{
	return self.pageTitles.count;
}

- (NSInteger)presentationIndexForPageViewController:(UIPageViewController *)pageViewController
{
	return 0;
}

- (IBAction)startTutorial:(id)sender {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:[NSNumber numberWithBool:YES] forKey:@"tutorial"];
	[defaults synchronize];
	
	// Create page view controller
	self.pageViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"TutorialViewController"];
	self.pageViewController.dataSource = self;
	
	eddaTutorialContentViewController *startingViewController = [self viewControllerAtIndex:0];
	NSArray *viewControllers = @[startingViewController];
	[self.pageViewController setViewControllers:viewControllers direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
	
	// Change the size of page view controller
	self.pageViewController.view.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
	self.pageViewController.view.backgroundColor = [UIColor blackColor];
	
	[self addChildViewController:self.pageViewController];
	[self.view addSubview:self.pageViewController.view];
	[self.pageViewController didMoveToParentViewController:self];
}

@end
