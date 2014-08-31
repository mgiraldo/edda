//
//  eddaFlipsideViewController.h
//  edda
//
//  Created by Mauricio Giraldo on 28/8/14.
//  Copyright (c) 2014 Ping Pong Estudio. All rights reserved.
//

#import <UIKit/UIKit.h>

@class eddaFlipsideViewController;

@protocol eddaFlipsideViewControllerDelegate
- (void)flipsideViewControllerDidFinish:(eddaFlipsideViewController *)controller;
@end

@interface eddaFlipsideViewController : UIViewController

@property (weak, nonatomic) id <eddaFlipsideViewControllerDelegate> delegate;

- (IBAction)done:(id)sender;

@end
