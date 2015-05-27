//
//  eddaGlobeViewController.m
//  Edda
//
//  Created by Mauricio Giraldo on 10/5/15.
//  Copyright (c) 2015 Ping Pong Estudio. All rights reserved.
//

#import "eddaGlobeViewController.h"
#import "eddaAppDelegate.h"

@interface eddaGlobeViewController ()

@end

@implementation eddaGlobeViewController

- (void)viewDidLoad {
    [super viewDidLoad];

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	self.fromLat = [[defaults valueForKey:@"last_fromLat"] floatValue];
	self.fromLon = [[defaults valueForKey:@"last_fromLon"] floatValue];
	self.toLat = [[defaults valueForKey:@"last_toLat"] floatValue];
	self.toLon = [[defaults valueForKey:@"last_toLon"] floatValue];
	self.distance = [[defaults valueForKey:@"last_distance"] floatValue];
	self.toNickname = [defaults valueForKey:@"last_nickname"];

	NSString *path = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html" inDirectory:@"globe"];
	NSURL *url = [NSURL fileURLWithPath:path];

	NSURLRequest *request = [NSURLRequest requestWithURL:url];

	self.globeView.delegate = self;
	
	[self.globeView loadRequest:request];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)shareButtonTapped:(id)sender {
	float km = self.distance / 1000;
	NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
	[formatter setNumberStyle:NSNumberFormatterDecimalStyle];
	[formatter setMaximumFractionDigits:0];
	
	NSString *formattedOutput;
	
	if (km > 5) {
		formattedOutput = [formatter stringFromNumber:[NSNumber numberWithFloat:km]];
	} else {
		formattedOutput = [formatter stringFromNumber:[NSNumber numberWithFloat:self.distance]];
	}
	
	NSString *textToShare = [NSString stringWithFormat:@"I just had a connection %@%@ away with %@!", formattedOutput, (km > 5 ? @"km" : @"m"), self.toNickname];
	
	[self takeScreenShot];
	
	NSArray *objectsToShare;
	
	objectsToShare = @[textToShare, self.screenShot];
	
	UIActivityViewController *activityViewController =
	[[UIActivityViewController alloc] initWithActivityItems:objectsToShare
									  applicationActivities:nil];

	NSArray *excludeActivities = @[UIActivityTypePrint,
								   UIActivityTypeAssignToContact,
								   UIActivityTypeAddToReadingList,
								   UIActivityTypeAirDrop,
								   UIActivityTypeMessage,
								   UIActivityTypeMail,
								   UIActivityTypePostToVimeo,
								   UIActivityTypePostToTencentWeibo];

	activityViewController.excludedActivityTypes = excludeActivities;

	[self presentViewController:activityViewController
									   animated:YES
									 completion:^{
										 // ...
									 }];
}

- (IBAction)closeGlobe:(id)sender {
	[self.delegate globeViewControllerDidFinish:self];
}

#pragma mark - activity view delegate stuff

- (void)takeScreenShot {
	UIGraphicsBeginImageContextWithOptions(self.globeView.bounds.size,
										   YES, 0.0);
	[self.globeView drawViewHierarchyInRect:self.globeView.bounds afterScreenUpdates:NO];
	self.screenShot = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	// now pass it to the web view and parse the result
//	NSString * base64String;
//
//	base64String = [self.globeView stringByEvaluatingJavaScriptFromString:
//						[NSString stringWithFormat:@"takeScreenshot()"]];
//
//	if (base64String != nil) [self processWebString: base64String];
}

- (void)processWebString:(NSString *)base64String {
	NSData *encodedData = [[NSData alloc] initWithBase64EncodedString:base64String options:0];

	//Now data is decoded. You can convert them to UIImage
	self.screenShot = [UIImage imageWithData:encodedData];
}

- (id)activityViewController:(UIActivityViewController *)activityViewController
		 itemForActivityType:(NSString *)activityType {
	if ([activityType isEqualToString:UIActivityTypePostToFacebook]) {
		return @"Like this!";
	} else if ([activityType isEqualToString:UIActivityTypePostToTwitter]) {
		return @"Retweet this!";
	} else {
		return nil;
	}
}

#pragma mark - web view delegate stuff

// In your implementation file
//-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
//	NSLog(@"web view jump: %@", request);
//	// Break apart request URL
//	NSString *requestString = [[request URL] absoluteString];
//	NSArray *components = [requestString componentsSeparatedByString:@":"];
//	
//	// Check for your protocol
//	if ([components count] > 1 &&
//		[(NSString *)[components objectAtIndex:0] isEqualToString:@"edda"])
//	{
//		// Look for specific actions
//		if ([(NSString *)[components objectAtIndex:1] isEqualToString:@"screenshot"])
//		{
//			// Your parameters can be found at
//			NSString *imageString = [components objectAtIndex:2];
//			[self processWebString:imageString];
//			// where 'n' is the ordinal position of the colon-delimited parameter
//		}
//		
//		// Return 'NO' to prevent navigation
//		return NO;
//	}
//	
//	// Return 'YES', navigate to requested URL as normal
//	return YES;
//}

-(void) webViewDidFinishLoad:(UIWebView *)webView {
	NSLog(@"me: %f,%f them:%f,%f dist:%f", self.fromLat, self.fromLon, self.toLat, self.toLon, self.distance);
	
	[self.globeView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"createGlobe(%f, %f, %f, %f)",
															self.fromLat,
															self.fromLon,
															self.toLat,
															self.toLon
															]];
	
}

@end
