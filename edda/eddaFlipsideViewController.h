//
//  eddaFlipsideViewController.h
//  edda
//
//  Created by Mauricio Giraldo on 28/8/14.
//  Copyright (c) 2014 Ping Pong Estudio. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MFMailComposeViewController.h>

@class eddaFlipsideViewController;

@protocol eddaFlipsideViewControllerDelegate
- (void)flipsideViewControllerDidFinish:(eddaFlipsideViewController *)controller;
@end

@interface eddaFlipsideViewController : UIViewController <UITextFieldDelegate, MFMailComposeViewControllerDelegate>

@property (nonatomic, assign) id currentResponder;

@property (weak, nonatomic) IBOutlet UISwitch *privacySwitch;
@property (weak, nonatomic) id <eddaFlipsideViewControllerDelegate> delegate;
@property (weak, nonatomic) NSString *nickname;
@property (weak, nonatomic) NSString *password;
@property (weak, nonatomic) IBOutlet UITextField *nicknameLabel;
@property (weak, nonatomic) IBOutlet UIImageView *backgroundView;
@property (weak, nonatomic) IBOutlet UIButton *feedbackButton;
@property (weak, nonatomic) IBOutlet UITextField *passwordLabel;

- (IBAction)done:(id)sender;
- (IBAction)privacyChanged:(UISwitch *)sender;
- (IBAction)feedbackPressed:(id)sender;

@end
