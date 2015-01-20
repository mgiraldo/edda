//
//  eddaFlipsideViewController.m
//  edda
//
//  Created by Mauricio Giraldo on 28/8/14.
//  Copyright (c) 2014 Ping Pong Estudio. All rights reserved.
//

#import "eddaFlipsideViewController.h"
#import "eddaAppDelegate.h"

@interface eddaFlipsideViewController ()

@end

@implementation eddaFlipsideViewController

static BOOL _isPrivate = NO;

- (void)viewDidLoad
{
    [super viewDidLoad];

	UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(resignOnTap:)];
	[singleTap setNumberOfTapsRequired:1];
	[singleTap setNumberOfTouchesRequired:1];
	[self.view addGestureRecognizer:singleTap];

	eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
	self.nickname = appDelegate.userTitle;
	self.nicknameLabel.text = appDelegate.userTitle;
	self.nicknameLabel.delegate = self;

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	_isPrivate = [[defaults valueForKey:@"privacy"] boolValue];
	[self.privacySwitch setOn:_isPrivate];
}

- (BOOL)prefersStatusBarHidden {
	return YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions

- (IBAction)done:(id)sender
{
    [self.delegate flipsideViewControllerDidFinish:self];
}

- (IBAction)privacyChanged:(UISwitch *)sender {
	if (sender.isOn == _isPrivate) {
		return;
	}
	
	_isPrivate = sender.isOn;
	
	[QBHelper saveUserPrivacyToQB:_isPrivate];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:[NSNumber numberWithBool:_isPrivate] forKey:@"privacy"];
	[defaults synchronize];
}

- (void)resignOnTap:(id)sender {
	NSLog(@"tap");
	[self.currentResponder resignFirstResponder];
}

- (void) animateTextField: (UITextField*) textField up: (BOOL) up
{
	const int movementDistance = 80; // tweak as needed
	const float movementDuration = 0.3f; // tweak as needed
	
	int movement = (up ? -movementDistance : movementDistance);
	
	[UIView beginAnimations: @"anim" context: nil];
	[UIView setAnimationBeginsFromCurrentState: YES];
	[UIView setAnimationDuration: movementDuration];
	self.view.frame = CGRectOffset(self.view.frame, 0, movement);
	[UIView commitAnimations];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    [self animateTextField:textField up:YES];
	
	eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
	self.nickname = appDelegate.userTitle;

	self.currentResponder = textField;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
	return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    [self animateTextField:textField up:NO];

	if ([textField.text isEqualToString:@""]) {
		textField.text = self.nickname;
		return;
	}
	if (textField == _nicknameLabel) {
		NSString *newlogin = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		
		self.nickname = newlogin;
		
		textField.text = newlogin;
		
		[QBHelper changeLoginToLogin:newlogin];

		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setObject:newlogin forKey:@"nickname"];
		[defaults synchronize];
	}
	self.currentResponder = nil;
}

@end
