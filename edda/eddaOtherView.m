//
//  eddaOtherView.m
//  edda
//
//  Created by Mauricio Giraldo on 7/9/14.
//  Copyright (c) 2014 Ping Pong Estudio. All rights reserved.
//

#import "eddaOtherView.h"

@implementation eddaOtherView

static const float _zoomDuration = 0.5f;
static const float _otherDiameterIn = 240.0f;
static const float _borderWidthIn = 1500.0f;
static const float _otherDiameterOut = 50.0f;

- (id)initWithFrame:(CGRect)frame
{
	_cyanColor = [UIColor colorWithRed:0 green:1 blue:1 alpha:.95];
	_magentaColor = [UIColor colorWithRed:1 green:0 blue:1 alpha:.95];
	CGRect f = CGRectMake(-_otherDiameterOut, -_otherDiameterOut, _otherDiameterOut, _otherDiameterOut);
    self = [super initWithFrame:f];
    if (self) {
        // Initialization code
//		self.contentMode = UIViewContentModeRedraw;
		self.layer.cornerRadius = _otherDiameterOut * .5;
		self.layer.backgroundColor = [UIColor blackColor].CGColor;
		self.layer.borderColor = [UIColor whiteColor].CGColor;
		self.layer.borderWidth = 1;
//		self.cyanView = [[UIView alloc] initWithFrame:f];
//		self.magentaView = [[UIView alloc] initWithFrame:f];
//		self.cyanView.layer.cornerRadius = _otherDiameterOut * .5;
//		self.cyanView.layer.backgroundColor = [UIColor colorWithRed:0 green:1 blue:1 alpha:0.75].CGColor;
//		self.cyanView.layer.borderColor = [UIColor clearColor].CGColor;
//		self.cyanView.layer.borderWidth = 1;
//		self.magentaView.layer.cornerRadius = _otherDiameterOut * .5;
//		self.magentaView.layer.backgroundColor = [UIColor clearColor].CGColor;
//		self.magentaView.layer.borderColor = [UIColor colorWithRed:1 green:0 blue:1 alpha:0.75].CGColor;
//		self.magentaView.layer.borderWidth = 1;
//		[self addSubview:self.magentaView];
//		[self addSubview:self.cyanView];
    }
    return self;
}

#pragma mark - View state

- (void)updatePosition:(CGPoint)position {
//	if (!_zoomed) {
		[UIView animateWithDuration:0.1
							  delay:0
							options:UIViewAnimationOptionAllowAnimatedContent | UIViewAnimationOptionAllowUserInteraction
						 animations:^{
							 self.center = position;
//							 CGPoint mPoint = CGPointMake(position.x, position.y);
//							 self.magentaView.center = mPoint;
//							 CGPoint cPoint = CGPointMake(position.x, position.y);
//							 self.cyanView.center = cPoint;
						 }
						 completion:^(BOOL finished){
							 [self setNeedsDisplay];
						 }];
//	}
}

- (void)zoomIn {
	if (_zoomed) return;
	[self.delegate eddaOtherViewStartedZoomIn:self];
	_zoomed = YES;
//	[UIView animateWithDuration:_zoomDuration
//					 animations:^{
//						 CGRect frame = CGRectMake(0, 0, _otherDiameterIn, _otherDiameterIn);
//						 self.layer.cornerRadius = _otherDiameterIn * .5;
//						 self.layer.backgroundColor = [UIColor clearColor].CGColor;
//						 self.frame = frame;
//					 }
//					 completion:^(BOOL finished){
//						 // whatever you need to do when animations are complete
//						 [self.delegate eddaOtherViewDidZoomIn:self];
//					 }];

	[UIView animateKeyframesWithDuration:_zoomDuration delay:0.0 options:UIViewKeyframeAnimationOptionCalculationModeLinear animations:^{
		[UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:0.5 animations:^{
			CGRect frame = CGRectMake((self.window.bounds.size.width-_otherDiameterIn)*.5, (self.window.bounds.size.width-_otherDiameterIn)*.5, _otherDiameterIn, _otherDiameterIn);
			self.layer.cornerRadius = _otherDiameterIn * .5;
			self.layer.backgroundColor = [UIColor clearColor].CGColor;
			self.frame = frame;
		}];
		[UIView addKeyframeWithRelativeStartTime:0.5 relativeDuration:0.5 animations:^{
			float _newSize = _otherDiameterIn + (_borderWidthIn * 2);
			CGRect frame = CGRectMake((self.window.bounds.size.width-_newSize)*.5, (self.window.bounds.size.width-_newSize)*.5, _newSize, _newSize);
			self.layer.cornerRadius = _newSize * .5;
			self.layer.borderWidth = _borderWidthIn;
			self.layer.borderColor = _cyanColor.CGColor;
			self.frame = frame;
		}];
	} completion:^(BOOL finished){
		// whatever you need to do when animations are complete
		[self.delegate eddaOtherViewDidZoomIn:self];
	}];

}

- (void)zoomOut {
	if (!_zoomed) {
		[self.delegate eddaOtherViewDidZoomOut:self];
		return;
	}
	[self.delegate eddaOtherViewStartedZoomOut:self];
	_zoomed = NO;
	[UIView animateWithDuration:_zoomDuration
						  delay:0
						options:UIViewAnimationOptionAllowAnimatedContent
					 animations:^{
						 CGRect frame = CGRectMake((self.window.bounds.size.width-_otherDiameterOut)*.5, (self.window.bounds.size.height-_otherDiameterOut)*.5, _otherDiameterOut, _otherDiameterOut);
						 self.layer.cornerRadius = _otherDiameterOut * .5;
						 self.layer.backgroundColor = [UIColor blackColor].CGColor;
						 self.layer.borderWidth = 1;
						 self.layer.borderColor = [UIColor whiteColor].CGColor;
						 self.frame = frame;
					 }
					 completion:^(BOOL finished){
						 // whatever you need to do when animations are complete
						 [self.delegate eddaOtherViewDidZoomOut:self];
					 }];
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
//- (void)drawRect:(CGRect)rect
//{
//    // Drawing code
//}

@end
