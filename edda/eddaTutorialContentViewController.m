//
//  eddaTutorialContentViewController.m
//  Edda
//
//  Created by Mauricio Giraldo on 29/1/15.
//  Copyright (c) 2015 Ping Pong Estudio. All rights reserved.
//

#import "eddaTutorialContentViewController.h"
#import "QBHelper.h"

@interface eddaTutorialContentViewController ()

@end

@implementation eddaTutorialContentViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	if (_pageIndex < _pageCount-1) {
		self.closeButton.hidden = YES;
	} else {
		self.closeButton.hidden = NO;
	}
	NSString *name = [self.imageFile componentsSeparatedByString:@"."].firstObject;
	self.imageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@.png",name]];
	self.titleLabel.text = self.titleText;
}

- (void)viewDidAppear:(BOOL)animated {
	NSString *name = [self.imageFile componentsSeparatedByString:@"."].firstObject;

	NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"mp4"];
	self.player = [[MPMoviePlayerController alloc] initWithContentURL:[NSURL fileURLWithPath:path]];
	[self.player prepareToPlay];
	[self.player.view setFrame:self.imageView.bounds];
	[self.player.view setCenter:self.imageView.center];
	self.player.view.layer.backgroundColor = [UIColor clearColor].CGColor;
	[self.view insertSubview:self.player.view belowSubview:self.imageView];
	self.player.controlStyle = MPMovieControlStyleNone;
	self.player.repeatMode = MPMovieRepeatModeOne;
	[self.player play];

	[[NSNotificationCenter defaultCenter]
	 addObserver:self
	 selector:@selector(swapVideo)
	 name:MPMoviePlayerReadyForDisplayDidChangeNotification
	 object:nil];
}

- (void)swapVideo {
	[self.player.view setCenter:self.imageView.center];
	[self.view bringSubviewToFront:self.player.view];
}

- (void)viewDidDisappear:(BOOL)animated {
	if ([self.imageFile rangeOfString:@"mp4"].location != NSNotFound) {
		[self.player.view removeFromSuperview];
		self.player = nil;
	}
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)closeTutorial:(id)sender {
	[self.parentViewController willMoveToParentViewController:nil];
	[self.parentViewController.view removeFromSuperview];
	[self.parentViewController removeFromParentViewController];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
