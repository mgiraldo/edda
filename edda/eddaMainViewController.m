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
#import "geodesic.h"
#include "utils.h"

@interface eddaMainViewController ()

@end

@implementation eddaMainViewController

CLLocationManager *locationManager;

CMMotionManager *motionManager;

BOOL _debugActive = NO;
BOOL _videoActive = YES;
BOOL _rearVideoInited = NO;
BOOL _frontVideoInited = NO;
BOOL _haveImage = NO;

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

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	// debug view
	[self.debugSwitch setOn:_debugActive];
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
	// now get the location
	locationManager.delegate = self;
    locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    [locationManager startUpdatingLocation];
	[locationManager startUpdatingHeading];

	// init Proj.4 params
	if (!(pj_geod = pj_init_plus("+proj=latlong +datum=WGS84 +units=m")) )
        NSLog(@"Could not initialise MERCATOR");
	if (!(pj_geoc = pj_init_plus("+proj=geocent +datum=WGS84")) )
        NSLog(@"Could not initialise CARTESIAN");
	
	// interface refresh timer
	[NSTimer scheduledTimerWithTimeInterval:0.1
									 target:self
								   selector:@selector(updateInterface:)
								   userInfo:nil
									repeats:YES];
	[self.placesPicker selectRow:1 inComponent:0 animated:NO];
	_toLat = [_placeCoordinates[1][0] doubleValue];
	_toLon = [_placeCoordinates[1][1] doubleValue];
	_toAlt = [_placeCoordinates[1][2] doubleValue];
	self.cityLabel.text = _places[1];

	[self updateViewAngle];
}

- (void)viewDidAppear:(BOOL)animated {
	self.debugView.frame = CGRectMake(0, -self.debugView.frame.size.height, self.view.bounds.size.width, self.debugView.frame.size.height);
	[self refreshVideoFeeds];
	[super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)updateInterface:(NSTimer *)timer {
	if (self.currentHeading == nil || self.currentLocation == nil) return;
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
	
	float normalizedHeadingTransparency = ofMap(headingTransparency, 0.0, 30.0, 0.0, 1.0, true);
//	NSLog(@"head: %.0f chead: %.0f cheadadj: %.0f cpitch: %.0f pitchdeg: %.0f cpitchadj: %.0f pitchraw: %.0f",
//		  self.currentHeading.trueHeading, correctHeading, headingAdjusted, correctPitch, pitchDeg, pitchAdjusted, pitchRaw);
	
	float layerTransparency = elevationTransparency * .5 + normalizedHeadingTransparency * .5;
	self.frontPreviewLayer.opacity = layerTransparency;
	
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
	[UIView animateWithDuration:0.1
						  delay:0
						options:UIViewAnimationOptionAllowAnimatedContent
					 animations:^{
						 self.pointerView.transform = CGAffineTransformMakeRotation(radians);
						 self.pointerView.center = CGPointMake(xArrow, yArrow);
					 }
					 completion:^(BOOL finished){
					 }];
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
- (void)takePicture {
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in self.stillImageOutput.connections){
        for (AVCaptureInputPort *port in [connection inputPorts]){
            if ([[port mediaType] isEqual:AVMediaTypeVideo]){
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) {
			break;
        }
    }
	
    NSLog(@"about to request a capture from: %@ connections: %lu", self.stillImageOutput, (unsigned long)self.stillImageOutput.connections.count);
	if (self.stillImageOutput.connections.count > 0) {
		[self.stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler: ^(CMSampleBufferRef imageSampleBuffer, NSError *error){
			
			CFDictionaryRef exifAttachments = CMGetAttachment( imageSampleBuffer, kCGImagePropertyExifDictionary, NULL);
			if (exifAttachments) {
				// Do something with the attachments if you want to.
				NSLog(@"attachements: %@", exifAttachments);
			} else {
				NSLog(@"no attachments");
			}
			NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
			UIImage *image = [[UIImage alloc] initWithData:imageData];
			
			self.previewImage.image = image;
		}];
	}
}

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

- (void)initFrontCamera {
	if (!_frontVideoInited) {
		_frontVideoInited = YES;
		self.frontSession = [[AVCaptureSession alloc] init];
		self.frontSession.sessionPreset = AVCaptureSessionPresetLow;
		
		NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
		self.frontVideoCaptureDevice = nil;
		
		for (AVCaptureDevice *d in videoDevices){
			if (d.position == AVCaptureDevicePositionFront){
				self.frontVideoCaptureDevice = d;
				break;
			}
		}
		
		NSError *error = nil;
		self.frontVideoInput = [AVCaptureDeviceInput deviceInputWithDevice:self.frontVideoCaptureDevice error:&error];
		if (self.frontVideoInput) {
			[self.frontSession addInput:self.frontVideoInput];
			
			//			self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
			//			NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil];
			//			[self.stillImageOutput setOutputSettings:outputSettings];
			//			[self.frontSession addOutput:self.stillImageOutput];
			
			self.frontPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.frontSession];
			self.frontPreviewLayer.frame = self.otherView.bounds;
		} else {
			// Handle the error appropriately.
			NSLog(@"ERROR: trying to open camera: %@", error);
			_frontVideoInited = NO;
		}
	}
}

- (void)startFrontCapture {
	[self initFrontCamera];
	if (_frontVideoInited) {
		[self.otherView setVideo:self.frontPreviewLayer];
		[self.frontSession startRunning];
	}
}

- (void)stopFrontCapture {
	if (_frontVideoInited) {
		[self.frontSession stopRunning];
		[self.otherView removeVideo];
	}
}

- (void)refreshVideoFeeds {
	[self stopRearCapture];
	[self stopFrontCapture];
	if (_videoActive) {
		if (_activeCamera==0) {
			[self startFrontCapture];
		} else {
			[self startRearCapture];
		}
	}
}

#pragma mark - UI Interaction

- (void)onOtherTapped:(UITapGestureRecognizer *)recognizer {
	NSLog(@"TAPPED!");
}

- (IBAction)onStartTapped:(id)sender {
	_videoActive = !_videoActive;
	if (_videoActive) {
		[self.startButton setTitle:@"Stop Video" forState:UIControlStateNormal];
	} else {
		[self.startButton setTitle:@"Start Video" forState:UIControlStateNormal];
	}
	[self refreshVideoFeeds];
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
	_activeCamera = 0;
	[self refreshVideoFeeds];
}

- (void)eddaOtherViewStartedZoomOut:(eddaOtherView *)view {
	_activeCamera = 0;
	_videoActive = NO;
	[self refreshVideoFeeds];
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
	//    NSLog(@"didUpdateToLocation: %@", newLocation);
    self.currentLocation = newLocation;
	
	if (self.currentLocation != nil) {
		[locationManager stopUpdatingLocation];
		[self updateViewAngle];
	}
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
	//    NSLog(@"didUpdateHeading: %@", newHeading);
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

#pragma mark - Flipside View

- (void)flipsideViewControllerDidFinish:(eddaFlipsideViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showAlternate"]) {
        [[segue destinationViewController] setDelegate:self];
    }
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

@end
