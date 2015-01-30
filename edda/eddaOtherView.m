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
static const float _borderWidthIn = 1500.0f;
static const float _otherDiameterOut = 50.0f;
static const float _blackDiameter = 310.0f;
static const float _cyanDiameter = 280.0f;
static const float _magentaDiameter = 250.0f;

- (id)initWithFrame:(CGRect)frame
{
	_cyanColor = [UIColor colorWithRed:0 green:1 blue:1 alpha:.9];
	_magentaColor = [UIColor colorWithRed:1 green:0 blue:1 alpha:.9];
	CGRect f = CGRectMake(-_otherDiameterOut, -_otherDiameterOut, _otherDiameterOut, _otherDiameterOut);
    self = [super initWithFrame:f];
    if (self) {
        // Initialization code
//		self.contentMode = UIViewContentModeRedraw;
		self.layer.cornerRadius = _otherDiameterOut * .5;
		self.layer.backgroundColor = [UIColor blackColor].CGColor;
		self.layer.borderColor = [UIColor whiteColor].CGColor;
		self.layer.borderWidth = 1;
		self.cyanView = [[UIView alloc] initWithFrame:f];
		self.magentaView = [[UIView alloc] initWithFrame:f];
		self.blackView = [[UIView alloc] initWithFrame:f];
		self.cyanView.layer.cornerRadius = _otherDiameterOut * .5;
		self.cyanView.layer.backgroundColor = [UIColor clearColor].CGColor;
		self.cyanView.layer.borderColor = _cyanColor.CGColor;
		self.cyanView.layer.borderWidth = 1;
		self.cyanView.hidden = YES;
		self.magentaView.layer.cornerRadius = _otherDiameterOut * .5;
		self.magentaView.layer.backgroundColor = [UIColor clearColor].CGColor;
		self.magentaView.layer.borderColor = _magentaColor.CGColor;
		self.magentaView.layer.borderWidth = 1;
		self.magentaView.hidden = YES;
		self.blackView.layer.cornerRadius = _otherDiameterOut * .5;
		self.blackView.layer.backgroundColor = [UIColor clearColor].CGColor;
		self.blackView.layer.borderColor = [UIColor blackColor].CGColor;
		self.blackView.layer.borderWidth = 1;
		self.blackView.hidden = YES;
		[self addSubview:self.magentaView];
		[self addSubview:self.cyanView];
		[self addSubview:self.blackView];
    }
    return self;
}

#pragma mark - View state

- (void)updatePosition:(CGPoint)position {
	if (!_zoomed) {
		self.cyanView.hidden = YES;
		self.magentaView.hidden = YES;
		self.blackView.hidden = YES;
		[UIView animateWithDuration:0.1
							  delay:0
							options:UIViewAnimationOptionAllowAnimatedContent | UIViewAnimationOptionAllowUserInteraction
						 animations:^{
							 self.center = position;
						 }
						 completion:^(BOOL finished){
							 [self setNeedsDisplay];
						 }];
	} else {
		[UIView animateWithDuration:0.1
							  delay:0
							options:UIViewAnimationOptionAllowAnimatedContent | UIViewAnimationOptionAllowUserInteraction
						 animations:^{
							 CGPoint mPoint = CGPointMake(self.window.frame.size.width * .5, position.y);
							 CGPoint cPoint = CGPointMake(position.x, self.window.frame.size.height * .5);
							 self.magentaView.center = mPoint;
							 self.cyanView.center = cPoint;
							 self.blackView.center = cPoint;
						 }
						 completion:^(BOOL finished){
							 [self setNeedsDisplay];
						 }];
	}
}

- (void)zoomIn {
	if (_zoomed) return;
	[self.delegate eddaOtherViewStartedZoomIn:self];
	_zoomed = YES;
//	[UIView animateWithDuration:_zoomDuration
//					 animations:^{
//						 CGRect frame = CGRectMake(0, 0, self.window.bounds.size.width, self.window.bounds.size.height);
//						 self.layer.cornerRadius = 0;
//						 self.layer.backgroundColor = [UIColor blackColor].CGColor;
//						 self.frame = frame;
//					 }
//					 completion:^(BOOL finished){
//						 // whatever you need to do when animations are complete
//						 [self.delegate eddaOtherViewDidZoomIn:self];
//					 }];

	[UIView animateKeyframesWithDuration:_zoomDuration delay:0.0 options:UIViewKeyframeAnimationOptionCalculationModeLinear animations:^{
		[UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:0.3 animations:^{
			CGRect frame = CGRectMake(0, 0, self.window.bounds.size.width, self.window.bounds.size.height);
			self.layer.cornerRadius = 0;
			self.layer.backgroundColor = [UIColor clearColor].CGColor;
			self.layer.borderColor = [UIColor clearColor].CGColor;
			self.frame = frame;
		}];
		[UIView addKeyframeWithRelativeStartTime:0.3 relativeDuration:0.3 animations:^{
			self.magentaView.hidden = NO;
			float _newSize = _magentaDiameter + (_borderWidthIn * 2);
			CGRect frame = CGRectMake((self.window.bounds.size.width-_newSize)*.5, (self.window.bounds.size.width-_newSize)*.5, _newSize, _newSize);
			self.magentaView.layer.cornerRadius = _newSize * .5;
			self.magentaView.layer.borderWidth = _borderWidthIn;
			self.magentaView.layer.borderColor = _magentaColor.CGColor;
			self.magentaView.frame = frame;
		}];
		[UIView addKeyframeWithRelativeStartTime:0.6 relativeDuration:0.4 animations:^{
			self.cyanView.hidden = NO;
			float _newSize = _cyanDiameter + (_borderWidthIn * 2);
			CGRect frame = CGRectMake((self.window.bounds.size.width-_newSize)*.5, (self.window.bounds.size.width-_newSize)*.5, _newSize, _newSize);
			self.cyanView.layer.cornerRadius = _newSize * .5;
			self.cyanView.layer.borderWidth = _borderWidthIn;
			self.cyanView.layer.borderColor = _cyanColor.CGColor;
			self.cyanView.frame = frame;
			self.cyanView.hidden = NO;

			self.blackView.hidden = NO;
			_newSize = _blackDiameter + (_borderWidthIn * 2);
			frame = CGRectMake((self.window.bounds.size.width-_newSize)*.5, (self.window.bounds.size.width-_newSize)*.5, _newSize, _newSize);
			self.blackView.layer.cornerRadius = _newSize * .5;
			self.blackView.layer.borderWidth = _borderWidthIn;
			self.blackView.frame = frame;
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
						 self.layer.backgroundColor = [UIColor clearColor].CGColor;
					 }
					 completion:^(BOOL finished){
						 // whatever you need to do when animations are complete
						 [self.delegate eddaOtherViewDidZoomOut:self];
						 CGRect frame = CGRectMake((self.window.bounds.size.width-_otherDiameterOut)*.5, (self.window.bounds.size.height-_otherDiameterOut)*.5, _otherDiameterOut, _otherDiameterOut);
						 self.frame = frame;
						 self.layer.cornerRadius = _otherDiameterOut * .5;
						 self.layer.borderWidth = 1;
						 self.layer.borderColor = [UIColor whiteColor].CGColor;
					 }];
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
//- (void)drawRect:(CGRect)rect
//{
//    // Drawing code
//}

@end
