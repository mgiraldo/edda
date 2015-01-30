//
//  eddaTutorialContentViewController.h
//  Edda
//
//  Created by Mauricio Giraldo on 29/1/15.
//  Copyright (c) 2015 Ping Pong Estudio. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface eddaTutorialContentViewController : UIViewController

@property NSUInteger pageIndex;
@property NSString *titleText;
@property NSString *imageFile;

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;

@end
