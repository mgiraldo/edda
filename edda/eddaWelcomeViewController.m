//
//  eddaWelcomeViewController.m
//  Edda
//
//  Created by Mauricio Giraldo on 4/5/15.
//  Copyright (c) 2015 Ping Pong Estudio. All rights reserved.
//

#import "eddaWelcomeViewController.h"
#import "eddaCallAnimationView.h"

static int callSize = 100;

static bool _cameraEnabled = false;
static bool _locationEnabled = false;
static bool _microphoneEnabled = false;

@interface eddaWelcomeViewController ()

@end

@implementation eddaWelcomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	_cameraEnabled = [[defaults valueForKey:@"cameraEnabled"] boolValue];
	_locationEnabled = [[defaults valueForKey:@"locationEnabled"] boolValue];
	_microphoneEnabled = [[defaults valueForKey:@"microphoneEnabled"] boolValue];
	
	if([[UIDevice currentDevice].systemVersion intValue] < 8) {
		_microphoneEnabled = true;
		self.microphoneButton.hidden = YES;
		_cameraEnabled = true;
		self.cameraButton.hidden = YES;
	}
}

- (void)viewDidAppear:(BOOL)animated {
	eddaCallAnimationView * callAnimation = [[eddaCallAnimationView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - callSize) *.5, 100, callSize, callSize)];
	[self.view addSubview:callAnimation];
	[callAnimation startAllAnimations:nil];
	[self updateEnabledStatuses];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)updateEnabledStatuses {
	self.locationButton.enabled = !_locationEnabled;
	self.cameraButton.enabled = !_cameraEnabled;
	self.microphoneButton.enabled = !_microphoneEnabled;

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:[NSNumber numberWithBool:_locationEnabled] forKey:@"locationEnabled"];
	[defaults setObject:[NSNumber numberWithBool:_cameraEnabled] forKey:@"cameraEnabled"];
	[defaults setObject:[NSNumber numberWithBool:_microphoneEnabled] forKey:@"microphoneEnabled"];
	[defaults synchronize];

	if (_locationEnabled && _cameraEnabled && _microphoneEnabled) {
		[self.delegate eddaWelcomeViewControllerFinished:self];
	}
}

- (IBAction)locationButtonTapped:(id)sender {
	if ([CLLocationManager authorizationStatus]) {
		_locationEnabled = true;
		[self updateEnabledStatuses];
		return;
	}

	// init location manager
	self.locationManager = [[CLLocationManager alloc] init];
	self.locationManager.delegate = self;
	self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;

	// iOS 8 not authorized by default
	if([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
		[self.locationManager requestWhenInUseAuthorization];
	}

	[self.locationManager startUpdatingLocation];
}

- (IBAction)microphoneButtonTapped:(id)sender {
	[[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
		if (granted) {
			_microphoneEnabled = true;
		}
		[self updateEnabledStatuses];
	}];
}

- (IBAction)cameraButtonTapped:(id)sender {
	if ([AVCaptureDevice respondsToSelector:@selector(requestAccessForMediaType: completionHandler:)]) {
		[AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
			// Will get here on both iOS 7 & 8 even though camera permissions weren't required
			// until iOS 8. So for iOS 7 permission will always be granted.
			if (granted) {
				// Permission has been granted. Use dispatch_async for any UI updating
				// code because this block may be executed in a thread.
				_cameraEnabled = true;
			}
			dispatch_async(dispatch_get_main_queue(), ^{
				[self updateEnabledStatuses];
			});
		}];
	}
}

# pragma mark - misc delegate methods

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
	[manager stopUpdatingLocation];
	NSLog(@"didUpdateToLocation: %@", newLocation);
	_locationEnabled = [CLLocationManager authorizationStatus];
	NSLog(@"location enabled: %i", _locationEnabled);
	[self updateEnabledStatuses];
}

@end
