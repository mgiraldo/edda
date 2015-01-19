//
//  eddaOtherView.h
//  edda
//
//  Created by Mauricio Giraldo on 7/9/14.
//  Copyright (c) 2014 Ping Pong Estudio. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol eddaOtherViewDelegate;

@interface eddaOtherView : UIView

@property (nonatomic, assign) id <eddaOtherViewDelegate> delegate;
@property (nonatomic, assign) BOOL zoomed;

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
