//
//  eddaTutorialContentViewController.m
//  Edda
//
//  Created by Mauricio Giraldo on 29/1/15.
//  Copyright (c) 2015 Ping Pong Estudio. All rights reserved.
//

#import "eddaTutorialContentViewController.h"

@interface eddaTutorialContentViewController ()

@end

@implementation eddaTutorialContentViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	self.imageView.image = [UIImage imageNamed:self.imageFile];
	self.titleLabel.text = self.titleText;
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
