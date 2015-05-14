//
//  eddaGlobeViewController.h
//  Edda
//
//  Created by Mauricio Giraldo on 10/5/15.
//  Copyright (c) 2015 Ping Pong Estudio. All rights reserved.
//

#import <UIKit/UIKit.h>

@class eddaGlobeViewController;

@protocol eddaGlobeViewControllerDelegate
- (void)globeViewControllerDidFinish:(eddaGlobeViewController *)controller;
@end

@interface eddaGlobeViewController : UIViewController <UIWebViewDelegate>

@property (nonatomic) float fromLat;
@property (nonatomic) float fromLon;
@property (nonatomic) float toLat;
@property (nonatomic) float toLon;

@property (nonatomic) UIImage *screenShot;
@property (weak, nonatomic) IBOutlet UIWebView *globeView;
@property (weak, nonatomic) id <eddaGlobeViewControllerDelegate> delegate;

- (IBAction)shareButtonTapped:(id)sender;
- (IBAction)closeGlobe:(id)sender;

@end
