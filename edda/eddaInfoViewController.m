//
//  eddaInfoViewController.m
//  Edda
//
//  Created by Mauricio Giraldo on 25/1/15.
//  Copyright (c) 2015 Ping Pong Estudio. All rights reserved.
//

#import "eddaInfoViewController.h"

@interface eddaInfoViewController ()

@end

@implementation eddaInfoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	
	CGFloat margin = 20;
	CGFloat topMargin = 80;
	
	UIColor *linkColor = [UIColor colorWithRed:255.0f green:255.0f blue:0.0f alpha:1];
	NSDictionary *attributes = @{NSForegroundColorAttributeName:linkColor};

	// Create an NSURL pointing to the HTML file
	NSURL *htmlString = [[NSBundle mainBundle]
						 URLForResource: @"info" withExtension:@"html"];
	
	// Transform HTML into an attributed string
	NSAttributedString *stringWithHTMLAttributes = [[NSAttributedString alloc]   initWithFileURL:htmlString options:@{NSDocumentTypeDocumentAttribute:NSHTMLTextDocumentType} documentAttributes:nil error:nil];
	
	// main view with blurs
	UIView *blurView = [[UIView alloc] initWithFrame:CGRectMake(margin, topMargin, self.view.frame.size.width-(margin*4), self.view.frame.size.height-(margin*4))];
	
	// Instantiate UITextView object
	UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, blurView.bounds.size.width, blurView.bounds.size.height)];
	
	// Add attributed string to text view
	textView.attributedText=stringWithHTMLAttributes;
	textView.backgroundColor = [UIColor clearColor];
	textView.editable = NO;
	textView.linkTextAttributes = attributes;
	
	// blur
	CAGradientLayer* maskLayer = [CAGradientLayer layer];
	
	maskLayer.bounds = CGRectMake(0, 0,
								  self.view.frame.size.width,
								  self.view.frame.size.height);
	
	CGColorRef outerColor = [UIColor colorWithWhite:0.0 alpha:1.0].CGColor;
	CGColorRef innerColor = [UIColor colorWithWhite:0.0 alpha:0.0].CGColor;
	
	maskLayer.colors = [NSArray arrayWithObjects:(__bridge id)outerColor, (__bridge id)innerColor,
						(__bridge id)innerColor, (__bridge id)outerColor, nil];
	
	maskLayer.locations = [NSArray arrayWithObjects:[NSNumber numberWithFloat:0.0],
						   [NSNumber numberWithFloat:0.1],
						   [NSNumber numberWithFloat:0.9],
						   [NSNumber numberWithFloat:1.0], nil];
	
	maskLayer.anchorPoint = CGPointZero;
	
	[blurView addSubview:textView];
	
	[blurView.layer addSublayer:maskLayer];

	// Add the text view to the view hierarchy
	[self.view insertSubview:blurView belowSubview:self.doneButton];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)checkStatusBarHidden {
	return [UIApplication sharedApplication].statusBarHidden;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)done:(id)sender {
	[self.delegate infoViewControllerDidFinish:self];
}

@end
