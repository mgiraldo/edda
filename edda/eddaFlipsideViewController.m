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

	eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
	self.nickname = appDelegate.userTitle;

	self.backgroundView.transform = CGAffineTransformMakeScale(-1, 1);

	CALayer *bottomBorder = [CALayer layer];
	bottomBorder.frame = CGRectMake(0.0f, self.nicknameLabel.frame.size.height - 1, self.nicknameLabel.frame.size.width, 1.0f);
	bottomBorder.backgroundColor = [UIColor yellowColor].CGColor;
	[self.nicknameLabel.layer addSublayer:bottomBorder];
	self.nicknameLabel.text = self.nickname;
	self.nicknameLabel.delegate = self;
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	self.password = [defaults valueForKey:@"password"];

	UIImageView *lockView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"lock.png"]];
	lockView.frame = CGRectMake(0, 0, 22, 32);
	UIView *leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 32, 40)];
	[leftView addSubview:lockView];
	lockView.center = CGPointMake(16, 20);

	CALayer *passwordBorder = [CALayer layer];
	passwordBorder.frame = CGRectMake(0.0f, self.passwordLabel.frame.size.height - 1, self.passwordLabel.frame.size.width, 1.0f);
	passwordBorder.backgroundColor = [UIColor yellowColor].CGColor;
	[self.passwordLabel.layer addSublayer:passwordBorder];
	self.passwordLabel.leftView = leftView;
	self.passwordLabel.leftViewMode = UITextFieldViewModeAlways;
	self.passwordLabel.text = self.password;
	self.passwordLabel.delegate = self;
	
	UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(resignOnTap:)];
	[singleTap setNumberOfTapsRequired:1];
	[singleTap setNumberOfTouchesRequired:1];
	[self.view addGestureRecognizer:singleTap];

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

- (IBAction)feedbackPressed:(id)sender {
	MFMailComposeViewController* controller = [[MFMailComposeViewController alloc] init];
	controller.mailComposeDelegate = self;
	[controller setToRecipients:[NSArray arrayWithObjects:@"feedback@edda.info", nil]];
	[controller setSubject:@"Edda feedback"];
	[controller setMessageBody:@"" isHTML:NO];
	[self presentViewController:controller animated:YES completion:nil];
}

- (void)mailComposeController:(MFMailComposeViewController*)controller
		  didFinishWithResult:(MFMailComposeResult)result
						error:(NSError*)error {
	if (result == MFMailComposeResultSent) {
		NSLog(@"sent feedback email");
	}
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)resignOnTap:(id)sender {
	NSLog(@"tap");
	[self.currentResponder resignFirstResponder];
}

- (void) animateTextField: (UITextField*) textField up: (BOOL) up
{
	int movementDistance = 80; // tweak as needed
	const float movementDuration = 0.3f; // tweak as needed

	if (textField != _nicknameLabel) {
		movementDistance = 220;
	}
	
	int movement = (up ? -movementDistance : movementDistance);
	
	[UIView beginAnimations: @"anim" context: nil];
	[UIView setAnimationBeginsFromCurrentState: YES];
	[UIView setAnimationDuration: movementDuration];
	self.view.frame = CGRectOffset(self.view.frame, 0, movement);
	[UIView commitAnimations];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    [self animateTextField:textField up:YES];
	
	if (textField == _nicknameLabel) {
		eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
		self.nickname = appDelegate.userTitle;
	}

	self.currentResponder = textField;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
	return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    [self animateTextField:textField up:NO];

	if ([textField.text isEqualToString:@""] && textField == _nicknameLabel) {
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
	} else if (textField == _passwordLabel) {
		NSString *newpassword = textField.text;
		
		self.password = newpassword;
		
		[QBHelper setPassword:newpassword];
		
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setObject:newpassword forKey:@"password"];
		[defaults synchronize];
	}

	self.currentResponder = nil;
}

@end
