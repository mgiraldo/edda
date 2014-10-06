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

- (void)viewDidLoad
{
    [super viewDidLoad];

	UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(resignOnTap:)];
	[singleTap setNumberOfTapsRequired:1];
	[singleTap setNumberOfTouchesRequired:1];
	[self.view addGestureRecognizer:singleTap];

	eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
	self.nicknameLabel.text = appDelegate.userTitle;
	self.nicknameLabel.delegate = self;
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

	self.currentResponder = textField;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
	return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    [self animateTextField: textField up:NO];

	if ([textField.text isEqualToString:@""])
		return;
	if (textField == _nicknameLabel) {
		eddaAppDelegate * appDelegate = (eddaAppDelegate *)[[UIApplication sharedApplication] delegate];
		appDelegate.userTitle = textField.text;
		[ParseHelper saveCurrentUserToParse];
	}
	self.currentResponder = nil;
}

@end
