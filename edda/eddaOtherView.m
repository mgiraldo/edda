//
//  eddaOtherView.m
//  edda
//
//  Created by Mauricio Giraldo on 7/9/14.
//  Copyright (c) 2014 Ping Pong Estudio. All rights reserved.
//

#import "eddaOtherView.h"

@implementation eddaOtherView

BOOL _zoomed = NO;
BOOL _touchDown = NO;
BOOL _isTappable = NO;
BOOL _isActive = NO;

float _borderWidth = 5;
float _zoomDuration = .25;
float _otherSize = 50.0f;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:CGRectMake(-_otherSize, -_otherSize, _otherSize, _otherSize)];
    if (self) {
        // Initialization code
//		self.contentMode = UIViewContentModeRedraw;
		self.layer.cornerRadius = _otherSize * .5;
		self.layer.backgroundColor = [UIColor blackColor].CGColor;
		self.layer.borderWidth = _borderWidth;
		self.layer.borderColor = [UIColor yellowColor].CGColor;
    }
    return self;
}

- (void)refreshView {
	if (_isTappable) {
//		self.layer.backgroundColor = [UIColor greenColor].CGColor;
		self.layer.opacity = 1.0;
	} else {
//		self.layer.backgroundColor = [UIColor blackColor].CGColor;
		self.layer.opacity = 0.5;
	}
	if (_isActive) {
		self.layer.borderColor = [UIColor greenColor].CGColor;
	} else {
		self.layer.borderColor = [UIColor grayColor].CGColor;
	}
}

#pragma mark - View state

- (void)updatePosition:(CGPoint)position {
	if (!_zoomed) {
		[UIView animateWithDuration:0.1
							  delay:0
							options:UIViewAnimationOptionAllowAnimatedContent | UIViewAnimationOptionAllowUserInteraction
						 animations:^{
							 self.center = position;
						 }
						 completion:^(BOOL finished){
							 [self setNeedsDisplay];
						 }];
	}
}

- (void)setTappable:(BOOL)tappable {
	_isTappable = tappable;
	[self refreshView];
}

- (void)setActiveState:(BOOL)active {
	_isActive = active;
	[self refreshView];
}

- (void)zoomIn {
	[self.delegate eddaOtherViewStartedZoomIn:self];
	_zoomed = YES;
	[UIView animateWithDuration:_zoomDuration
					 animations:^{
						 CGRect frame = CGRectMake(0, 0, self.window.bounds.size.width, self.window.bounds.size.height);
						 self.layer.cornerRadius = 0;
						 self.frame = frame;
						 self.videoLayer.frame = frame;
					 }
					 completion:^(BOOL finished){
						 // whatever you need to do when animations are complete
						 [self.delegate eddaOtherViewDidZoomIn:self];
					 }];
}

- (void)zoomOut {
	[self.delegate eddaOtherViewStartedZoomOut:self];
	_zoomed = NO;
	[UIView animateWithDuration:_zoomDuration
						  delay:0
						options:UIViewAnimationOptionAllowAnimatedContent
					 animations:^{
						 CGRect frame = CGRectMake((self.window.bounds.size.width-_otherSize)*.5, -_otherSize*5, _otherSize, _otherSize);
						 self.layer.cornerRadius = _otherSize * .5;
						 self.frame = frame;
						 self.videoLayer.frame = frame;
					 }
					 completion:^(BOOL finished){
						 // whatever you need to do when animations are complete
						 [self.delegate eddaOtherViewDidZoomOut:self];
					 }];
}

#pragma mark - Interaction

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
//	NSLog(@"touchbegan");
	_touchDown = YES;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
//	NSLog(@"touchend");
    // Triggered when touch is released
    if (_touchDown) {
        if (_zoomed) {
			[self zoomOut];
		} else {
			[self zoomIn];
		}
    }
	_touchDown = NO;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
//	NSLog(@"touchcancel");
	if (_zoomed) {
		[self zoomOut];
	} else {
		[self zoomIn];
	}
	_touchDown = NO;
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
//- (void)drawRect:(CGRect)rect
//{
//    // Drawing code
//}

@end
