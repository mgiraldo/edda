//
//  eddaMainViewController.m
//  edda
//
//  Created by Mauricio Giraldo on 28/8/14.
//  Copyright (c) 2014 Ping Pong Estudio. All rights reserved.
//

#import "eddaMainViewController.h"
#import <Accelerate/Accelerate.h>
#include "geodesic.h"

@interface eddaMainViewController ()

@end

@implementation eddaMainViewController

CLLocationManager *locationManager;

NSArray *_places;
NSArray *_placeCoordinates;
CLHeading *_currentHeading;
CLLocation *_currentLocation;

// proj4
projPJ pj_geoc;
projPJ pj_geod;

double fromLat = 0.0;
double fromLon = 0.0;
double fromAlt = 0.0;

double toLat = 0.0;
double toLon = 0.0;
double toAlt = 0.0;

sViewAngle viewAngle;

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.debugActive = NO;
	
	[self.debugSwitch setOn:self.debugActive];
	
	// picker stuff
	_places = @[@"Select", @"Bogotá", @"Jakarta", @"Johannesburg", @"Kampala", @"London", @"Los Angeles", @"Madrid", @"New York", @"NYC Antipode", @"Paris", @"Perth", @"São Paulo", @"Tokio"];
	_placeCoordinates = @[ @[@0.0f, @0.0f, @0.0f] // "None"
						   , @[@4.598056f, @-74.075833f, @2600.0f] // "Bogotá"
						   , @[@-6.208763f, @106.845599f, @5.0f] // "Jakarta"
						   , @[@-26.204103f, @28.047305f, @1755.0f] // "Johannesburg"
						   , @[@0.313611f, @32.581111f, @1222.0f] // "Kampala"
						   , @[@51.507351f, @-0.127758f, @7.0f] // "London"
						   , @[@34.052234f, @-118.243685f, @89.0f] // "Los Angeles"
						   , @[@40.416775f, @-3.703790f, @650.0f] // "Madrid"
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
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
    _currentLocation = newLocation;
	
	if (_currentLocation != nil) {
		[locationManager stopUpdatingLocation];
		[self updateViewAngle];
	}
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
//    NSLog(@"didUpdateHeading: %@", newHeading);
    _currentHeading = newHeading;
	
    if (_currentHeading != nil) {
        [self headingLabel].text = [NSString stringWithFormat:@"%.1f", _currentHeading.trueHeading];
		[self updateArrows];
	}
}

#pragma mark - UI Interaction

- (IBAction)onDebugSwitchTapped:(id)sender {
	self.debugActive = self.debugSwitch.on;
	
	self.toLatitudeTextField.enabled = !self.debugActive;
	self.toLongitudeTextField.enabled = !self.debugActive;
	self.toAltitudeTextField.enabled = !self.debugActive;

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
		toLat = textField.text.doubleValue;
	} else if (textField == _toLongitudeTextField) {
		toLon = textField.text.doubleValue;
	} else if (textField == _toAltitudeTextField) {
		toAlt = textField.text.doubleValue;
	}
	self.currentResponder = nil;
	[self.placesPicker selectRow:0 inComponent:0 animated:YES];
	[self updateViewAngle];
}

#pragma mark - GIS stuff

- (void)updateArrows {
	CGFloat duration = 0.01;
	float h = 0.0;

	if (_currentHeading != nil) {
		h = _currentHeading.trueHeading;
		// north arrow
		
		CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
		animation.fromValue = [[self.northImage.layer presentationLayer] valueForKeyPath:@"transform.rotation.z"];
		animation.toValue = [NSNumber numberWithFloat:-DEG_TO_RAD*h];;
		animation.duration = duration;
		animation.fillMode = kCAFillModeForwards;
		animation.repeatCount = 0;
		animation.removedOnCompletion = NO;
		animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
		[self.northImage.layer addAnimation:animation forKey:@"transform.rotation.z"];
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

- (void)updateViewAngle {
	if (self.debugActive) {
		[self.placesPicker selectRow:0 inComponent:0 animated:YES];
		fromLat = 39;
		fromLon = -75;
		fromAlt = 4000;
		toLat = 39;
		toLon = -76;
		toAlt = 12000;
	} else if (_currentLocation != nil) {
		fromLat = _currentLocation.coordinate.latitude;
		fromLon = _currentLocation.coordinate.longitude;
		fromAlt = _currentLocation.altitude;
	}

	[self latitudeLabel].text = [NSString stringWithFormat:@"%.4f", fromLat];
	[self longitudeLabel].text = [NSString stringWithFormat:@"%.4f", fromLon];
	[self altitudeLabel].text = [NSString stringWithFormat:@"%.2f", fromAlt];
	
	self.toLatitudeTextField.text = [NSString stringWithFormat:@"%f", toLat];
	self.toLongitudeTextField.text = [NSString stringWithFormat:@"%f", toLon];
	self.toAltitudeTextField.text = [NSString stringWithFormat:@"%f", toAlt];
	
	viewAngle = [self findViewAngleFromLat:fromLat fromLon:fromLon fromAlt:fromAlt toLat:toLat toLon:toLon toAlt:toAlt];
	
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
	toLat = [_placeCoordinates[row][0] doubleValue];
	toLon = [_placeCoordinates[row][1] doubleValue];
	toAlt = [_placeCoordinates[row][2] doubleValue];
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
