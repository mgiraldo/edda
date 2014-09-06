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

@property (nonatomic, assign) id currentResponder;

@property (nonatomic) CLHeading *currentHeading;
@property (nonatomic) CLLocation *currentLocation;
@property (nonatomic) CMDeviceMotion *currentMotion;

@property (nonatomic) UIImageView *NE_arrowView;
@property (nonatomic) UIImageView *NW_arrowView;
@property (nonatomic) UIImageView *SE_arrowView;
@property (nonatomic) UIImageView *SW_arrowView;
@property (nonatomic) UIImageView *N_arrowView;
@property (nonatomic) UIImageView *S_arrowView;
@property (nonatomic) UIImageView *E_arrowView;
@property (nonatomic) UIImageView *W_arrowView;

@property (weak, nonatomic) IBOutlet UIView *otherView;
@property (weak, nonatomic) IBOutlet UIView *debugView;
@property (weak, nonatomic) IBOutlet UIView *videoView;
@property (weak, nonatomic) IBOutlet UIView *indicatorView;
@property (weak, nonatomic) IBOutlet UIImageView *azimuthImage;
@property (weak, nonatomic) IBOutlet UIPickerView *placesPicker;
@property (weak, nonatomic) IBOutlet UISwitch *debugSwitch;
@property (weak, nonatomic) IBOutlet UIButton *startButton;

@property (weak, nonatomic) IBOutlet UILabel *cityLabel;
@property (weak, nonatomic) IBOutlet UILabel *altitudeLabel;
@property (weak, nonatomic) IBOutlet UILabel *latitudeLabel;
@property (weak, nonatomic) IBOutlet UILabel *longitudeLabel;
@property (weak, nonatomic) IBOutlet UILabel *headingLabel;
@property (weak, nonatomic) IBOutlet UILabel *elevationLabel;
@property (weak, nonatomic) IBOutlet UILabel *azimuthLabel;

@property (weak, nonatomic) IBOutlet UITextField *toLatitudeTextField;
@property (weak, nonatomic) IBOutlet UITextField *toLongitudeTextField;
@property (weak, nonatomic) IBOutlet UITextField *toAltitudeTextField;

@property (nonatomic) AVCaptureDevice *videoCaptureDevice;
@property (nonatomic) AVCaptureSession *captureSession;
@property (nonatomic) AVCaptureDeviceInput *videoInput;
@property (nonatomic) AVCaptureVideoPreviewLayer *previewLayer;

- (IBAction)onStartTapped:(id)sender;
- (IBAction)onDebugSwitchTapped:(id)sender;
- (sViewAngle)findViewAngleFromLat:(double)fromLat fromLon:(double)fromLon fromAlt:(double)fromAlt toLat:(double)toLat toLon:(double)toLon toAlt:(double)toAlt;

@end
