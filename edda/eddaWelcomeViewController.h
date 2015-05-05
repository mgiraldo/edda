//
//  eddaWelcomeViewController.h
//  Edda
//
//  Created by Mauricio Giraldo on 4/5/15.
//  Copyright (c) 2015 Ping Pong Estudio. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@interface eddaWelcomeViewController : UIViewController <CLLocationManagerDelegate>

@property (weak, nonatomic) IBOutlet UIButton *locationButton;
@property (weak, nonatomic) IBOutlet UIButton *cameraButton;
@property (weak, nonatomic) IBOutlet UIButton *microphoneButton;
@property (nonatomic) CLLocationManager * locationManager;

- (IBAction)locationButtonTapped:(id)sender;
- (IBAction)cameraButtonTapped:(id)sender;
- (IBAction)microphoneButtonTapped:(id)sender;
@end
