//
//  eddaOtherView.h
//  edda
//
//  Created by Mauricio Giraldo on 7/9/14.
//  Copyright (c) 2014 Ping Pong Estudio. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol eddaOtherViewDelegate;

@interface eddaOtherView : UIView {
	UIColor *_cyanColor;
	UIColor *_magentaColor;
	UIColor *_yellowColor;
}

@property (nonatomic, assign) id <eddaOtherViewDelegate> delegate;
@property (nonatomic, assign) BOOL zoomed;
@property (nonatomic) UIView *cyanView;
@property (nonatomic) UIView *magentaView;
@property (nonatomic) UIView *blackView;
@property (nonatomic) UIView *holeView;
@property (nonatomic) UIView *sqCyanView;
@property (nonatomic) UIView *sqMagentaView;
@property (nonatomic) UIView *sqYellowView;

- (void)updatePosition:(CGPoint)position;
- (void)zoomIn;
- (void)zoomOut;

@end

@protocol eddaOtherViewDelegate

- (void)eddaOtherViewStartedZoomIn:(eddaOtherView *)view;
- (void)eddaOtherViewDidZoomIn:(eddaOtherView *)view;
- (void)eddaOtherViewStartedZoomOut:(eddaOtherView *)view;
- (void)eddaOtherViewDidZoomOut:(eddaOtherView *)view;

@end
