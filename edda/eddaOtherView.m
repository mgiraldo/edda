//
//  eddaOtherView.m
//  edda
//
//  Created by Mauricio Giraldo on 7/9/14.
//  Copyright (c) 2014 Ping Pong Estudio. All rights reserved.
//

#import "eddaOtherView.h"

@implementation eddaOtherView

static const float _zoomDuration = .25;
static const float _otherSize = 50.0f;
static const float _margin = 30.0f;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:CGRectMake(-_otherSize, -_otherSize, _otherSize, _otherSize)];
    if (self) {
        // Initialization code
//		self.contentMode = UIViewContentModeRedraw;
		self.layer.cornerRadius = _otherSize * .5;
		self.layer.backgroundColor = [UIColor blackColor].CGColor;
		self.layer.borderColor = [UIColor whiteColor].CGColor;
		self.layer.borderWidth = 1;
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
	[UIView animateWithDuration:_zoomDuration
					 animations:^{
						 CGRect frame = CGRectMake(0, 0, self.window.bounds.size.width - _margin, self.window.bounds.size.width - _margin);
						 self.layer.cornerRadius = (self.window.bounds.size.width - _margin) * .5;
						 self.layer.backgroundColor = [UIColor clearColor].CGColor;
						 self.frame = frame;
					 }
					 completion:^(BOOL finished){
						 // whatever you need to do when animations are complete
						 [self.delegate eddaOtherViewDidZoomIn:self];
					 }];
}

- (void)zoomOut {
	if (!_zoomed) return;
	[self.delegate eddaOtherViewStartedZoomOut:self];
	_zoomed = NO;
	[UIView animateWithDuration:_zoomDuration
						  delay:0
						options:UIViewAnimationOptionAllowAnimatedContent
					 animations:^{
						 CGRect frame = CGRectMake((self.window.bounds.size.width-_otherSize)*.5, (self.window.bounds.size.height-_otherSize)*.5, _otherSize, _otherSize);
						 self.layer.cornerRadius = _otherSize * .5;
						 self.layer.backgroundColor = [UIColor blackColor].CGColor;
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
