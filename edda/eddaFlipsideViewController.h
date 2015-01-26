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

@interface eddaFlipsideViewController : UIViewController <UITextFieldDelegate>

@property (nonatomic, assign) id currentResponder;

@property (weak, nonatomic) IBOutlet UISwitch *privacySwitch;
@property (weak, nonatomic) id <eddaFlipsideViewControllerDelegate> delegate;
@property (weak, nonatomic) NSString *nickname;
@property (weak, nonatomic) IBOutlet UITextField *nicknameLabel;
@property (weak, nonatomic) IBOutlet UIImageView *backgroundView;

- (IBAction)done:(id)sender;
- (IBAction)privacyChanged:(UISwitch *)sender;

@end
