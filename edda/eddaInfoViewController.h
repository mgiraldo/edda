//
//  eddaInfoViewController.h
//  Edda
//
//  Created by Mauricio Giraldo on 25/1/15.
//  Copyright (c) 2015 Ping Pong Estudio. All rights reserved.
//

#import <UIKit/UIKit.h>

@class eddaInfoViewController;

@protocol eddaInfoViewControllerDelegate
- (void)infoViewControllerDidFinish:(eddaInfoViewController *)controller;
@end

@interface eddaInfoViewController : UIViewController

@property (weak, nonatomic) id <eddaInfoViewControllerDelegate> delegate;
@property (weak, nonatomic) IBOutlet UIButton *doneButton;

- (IBAction)done:(id)sender;

@end
