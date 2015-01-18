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
#import "eddaAppDelegate.h"
#import "eddaFlipsideViewController.h"
#import "eddaOtherView.h"
#import "proj_api.h"

@class eddaMainViewController;

@interface eddaMainViewController : UIViewController <eddaFlipsideViewControllerDelegate, eddaOtherViewDelegate, AVAudioPlayerDelegate, UIAlertViewDelegate, QBChatDelegate, CLLocationManagerDelegate, UITextFieldDelegate, NSFileManagerDelegate, AVCaptureVideoDataOutputSampleBufferDelegate> {
	AVAudioPlayer *ringingPlayer;
}

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

@property (nonatomic) UIImageView *N_arrowView;
@property (nonatomic) UIImageView *S_arrowView;
@property (nonatomic) UIImageView *E_arrowView;
@property (nonatomic) UIImageView *W_arrowView;

@property (strong) UIAlertView *callAlert;

@property (nonatomic) eddaOtherView *otherView;

@property (weak, nonatomic) IBOutlet UIView *controlsView;
@property (weak, nonatomic) IBOutlet UIView *videoView;
@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (weak, nonatomic) IBOutlet UIButton *endButton;

@property (weak, nonatomic) IBOutlet UILabel *statusLabel;

@property (nonatomic) AVCaptureDevice *rearVideoCaptureDevice;
@property (nonatomic) AVCaptureSession *rearSession;
@property (nonatomic) AVCaptureDeviceInput *rearVideoInput;
@property (nonatomic) AVCaptureVideoPreviewLayer *rearPreviewLayer;

@property (nonatomic) AVCaptureSession *frontSession;

@property (nonatomic) NSTimer * activeTimer;
@property (nonatomic) NSTimer * alignedTimer;
@property (nonatomic) NSTimer * subscriberTimer;
@property (nonatomic) NSTimer * publisherTimer;
@property (nonatomic) QBUUser * receiverObject;

@property (nonatomic) QBVideoChat *videoChat;
@property (nonatomic) UIView *opponentVideoView;
@property (nonatomic) UIView *myVideoView;

@property (nonatomic, assign) eddaAppDelegate* appDelegate;

- (void)userHasLoggedIn;
- (void)startVideoChat;
- (sViewAngle)findViewAngleFromLat:(double)fromLat fromLon:(double)fromLon fromAlt:(double)fromAlt toLat:(double)toLat toLon:(double)toLon toAlt:(double)toAlt;
- (void) disconnectAndGoBack;

@end
