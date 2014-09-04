//
//  eddaMainViewController.h
//  edda
//
//  Created by Mauricio Giraldo on 28/8/14.
//  Copyright (c) 2014 Ping Pong Estudio. All rights reserved.
//
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>
#import <AVFoundation/AVFoundation.h>
#import "eddaFlipsideViewController.h"
#import "proj_api.h"

@interface eddaMainViewController : UIViewController <eddaFlipsideViewControllerDelegate, CLLocationManagerDelegate, UITextFieldDelegate, UIPickerViewDataSource, UIPickerViewDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>

struct sViewAngle {
	double azimuth;
	double elevation;
};
typedef struct sViewAngle sViewAngle;

@property (nonatomic, strong) UIImageView *NE_arrowView;
@property (nonatomic, strong) UIImageView *NW_arrowView;
@property (nonatomic, strong) UIImageView *SE_arrowView;
@property (nonatomic, strong) UIImageView *SW_arrowView;
@property (nonatomic, strong) UIImageView *N_arrowView;
@property (nonatomic, strong) UIImageView *S_arrowView;
@property (nonatomic, strong) UIImageView *E_arrowView;
@property (nonatomic, strong) UIImageView *W_arrowView;

@property (weak, nonatomic) IBOutlet UIView *videoView;
@property (weak, nonatomic) IBOutlet UIView *indicatorView;
@property (weak, nonatomic) IBOutlet UIImageView *azimuthImage;
@property (weak, nonatomic) IBOutlet UIPickerView *placesPicker;
@property (weak, nonatomic) IBOutlet UISwitch *debugSwitch;

@property (weak, nonatomic) IBOutlet UILabel *altitudeLabel;
@property (weak, nonatomic) IBOutlet UILabel *latitudeLabel;
@property (weak, nonatomic) IBOutlet UILabel *longitudeLabel;
@property (weak, nonatomic) IBOutlet UILabel *headingLabel;
@property (weak, nonatomic) IBOutlet UILabel *elevationLabel;
@property (weak, nonatomic) IBOutlet UILabel *azimuthLabel;

@property (nonatomic, assign) id currentResponder;
@property (nonatomic, assign) BOOL debugActive;

@property (nonatomic, strong) CLHeading *currentHeading;
@property (nonatomic, strong) CLLocation *currentLocation;
@property (nonatomic, strong) CMDeviceMotion *currentMotion;

@property (weak, nonatomic) IBOutlet UITextField *toLatitudeTextField;
@property (weak, nonatomic) IBOutlet UITextField *toLongitudeTextField;
@property (weak, nonatomic) IBOutlet UITextField *toAltitudeTextField;


- (IBAction)onDebugSwitchTapped:(id)sender;
- (sViewAngle)findViewAngleFromLat:(double)fromLat fromLon:(double)fromLon fromAlt:(double)fromAlt toLat:(double)toLat toLon:(double)toLon toAlt:(double)toAlt;

@end
