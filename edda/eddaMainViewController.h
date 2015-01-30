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
#import <GLKit/GLKit.h>

#import "proj_api.h"

#import "eddaAppDelegate.h"
#import "eddaFlipsideViewController.h"
#import "eddaInfoViewController.h"
#import "eddaOtherView.h"
#import "eddaTutorialContentViewController.h"

@class eddaMainViewController;

@interface eddaMainViewController : UIViewController <UIPageViewControllerDataSource, eddaFlipsideViewControllerDelegate, eddaOtherViewDelegate, AVAudioPlayerDelegate, UIAlertViewDelegate, QBChatDelegate, CLLocationManagerDelegate, NSFileManagerDelegate, AVCaptureVideoDataOutputSampleBufferDelegate> {
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
@property (weak, nonatomic) IBOutlet UIView *blockingView;
@property (weak, nonatomic) IBOutlet UIButton *infoButton;
@property (weak, nonatomic) IBOutlet UIButton *settingsButton;
@property (weak, nonatomic) IBOutlet UIImageView *backgroundView;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UIButton *tutorialButton;

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
@property (nonatomic) UIImageView *opponentVideoView;
@property (nonatomic) UIImageView *myVideoView;

// tutorial stuff
@property (strong, nonatomic) UIPageViewController *pageViewController;
@property (strong, nonatomic) NSArray *pageTitles;
@property (strong, nonatomic) NSArray *pageImages;

@property (nonatomic, assign) eddaAppDelegate* appDelegate;

- (void)userHasLoggedIn;
- (void)startVideoChat;
- (sViewAngle)findViewAngleFromLat:(double)fromLat fromLon:(double)fromLon fromAlt:(double)fromAlt toLat:(double)toLat toLon:(double)toLon toAlt:(double)toAlt;
- (void) disconnectAndGoBack;
- (IBAction)startTutorial:(id)sender;

@end
