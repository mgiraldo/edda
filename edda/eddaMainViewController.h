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
#import <Parse/Parse.h>
#import <Opentok/Opentok.h>
#import "eddaAppDelegate.h"
#import "eddaFlipsideViewController.h"
#import "eddaOtherView.h"
#import "proj_api.h"

@class eddaMainViewController;

@interface eddaMainViewController : UIViewController <eddaFlipsideViewControllerDelegate, eddaOtherViewDelegate, CLLocationManagerDelegate, UITextFieldDelegate, UIPickerViewDataSource, UIPickerViewDelegate, NSFileManagerDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>

enum streamingMode
{
	streamingModeIncoming = 0,
	streamingModeOutgoing = 1
};

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

@property (weak, nonatomic) IBOutlet UIImageView *pointerView;
@property (nonatomic) eddaOtherView *otherView;

@property (weak, nonatomic) IBOutlet UIImageView *previewImage;
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

@property (nonatomic) AVCaptureDevice *rearVideoCaptureDevice;
@property (nonatomic) AVCaptureSession *rearSession;
@property (nonatomic) AVCaptureDeviceInput *rearVideoInput;
@property (nonatomic) AVCaptureVideoPreviewLayer *rearPreviewLayer;
@property (nonatomic) AVCaptureDevice *frontVideoCaptureDevice;
@property (nonatomic) AVCaptureSession *frontSession;
@property (nonatomic) AVCaptureDeviceInput *frontVideoInput;
@property (nonatomic) AVCaptureVideoPreviewLayer *frontPreviewLayer;
@property (nonatomic) AVCaptureStillImageOutput *stillImageOutput;

@property (copy, nonatomic) NSString* callReceiverID;

- (IBAction)onStartTapped:(id)sender;
- (IBAction)onDebugSwitchTapped:(id)sender;
- (sViewAngle)findViewAngleFromLat:(double)fromLat fromLon:(double)fromLon fromAlt:(double)fromAlt toLat:(double)toLat toLon:(double)toLon toAlt:(double)toAlt;
- (void)eddaOtherViewDidZoomIn:(eddaOtherView *)view;
- (void)eddaOtherViewDidZoomOut:(eddaOtherView *)view;

@end
