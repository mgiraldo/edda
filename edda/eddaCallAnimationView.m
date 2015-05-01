//
//  eddaCallAnimationView.m
//
//  Code generated using QuartzCode 1.23 on 30/4/15.
//  www.quartzcodeapp.com
//

#import "eddaCallAnimationView.h"
#import "QCMethod.h"


@interface eddaCallAnimationView ()

@property (nonatomic, strong) CAShapeLayer * yellow;
@property (nonatomic, strong) CAShapeLayer * cyan;
@property (nonatomic, strong) CAShapeLayer * magenta;
@property (nonatomic, strong) CAShapeLayer * oval;

@end

@implementation eddaCallAnimationView

- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		[self setupLayers];
	}
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self) {
		[self setupLayers];
	}
	return self;
}


- (void)setFrame:(CGRect)frame{
	[super setFrame:frame];
	[self setupLayerFrames];
}

- (void)setBounds:(CGRect)bounds{
	[super setBounds:bounds];
	[self setupLayerFrames];
}

- (void)setupLayers{
	CAShapeLayer * yellow = [CAShapeLayer layer];
	[self.layer addSublayer:yellow];
	yellow.fillColor = [UIColor colorWithRed:1 green: 1 blue:0 alpha:0.75].CGColor;
	yellow.lineWidth = 0;
	_yellow = yellow;
	
	CAShapeLayer * cyan = [CAShapeLayer layer];
	[self.layer addSublayer:cyan];
	cyan.fillColor = [UIColor colorWithRed:0 green: 1 blue:1 alpha:0.75].CGColor;
	cyan.lineWidth = 0;
	_cyan = cyan;
	
	CAShapeLayer * magenta = [CAShapeLayer layer];
	[self.layer addSublayer:magenta];
	magenta.fillColor = [UIColor colorWithRed:1 green: 0 blue:1 alpha:0.75].CGColor;
	magenta.lineWidth = 0;
	_magenta = magenta;
	
	CAShapeLayer * oval = [CAShapeLayer layer];
	[self.layer addSublayer:oval];
	oval.fillColor = [UIColor blackColor].CGColor;
	oval.lineWidth = 0;
	_oval = oval;
	
	[self setupLayerFrames];
}


- (void)setupLayerFrames{
	_yellow.frame  = CGRectMake(0.21738 * CGRectGetWidth(_yellow.superlayer.bounds), 0.21738 * CGRectGetHeight(_yellow.superlayer.bounds), 0.56524 * CGRectGetWidth(_yellow.superlayer.bounds), 0.56524 * CGRectGetHeight(_yellow.superlayer.bounds));
	_yellow.path   = [self yellowPathWithBounds:_yellow.bounds].CGPath;
	_cyan.frame    = CGRectMake(0.21738 * CGRectGetWidth(_cyan.superlayer.bounds), 0.21738 * CGRectGetHeight(_cyan.superlayer.bounds), 0.56524 * CGRectGetWidth(_cyan.superlayer.bounds), 0.56524 * CGRectGetHeight(_cyan.superlayer.bounds));
	_cyan.path     = [self cyanPathWithBounds:_cyan.bounds].CGPath;
	_magenta.frame = CGRectMake(0.21738 * CGRectGetWidth(_magenta.superlayer.bounds), 0.21738 * CGRectGetHeight(_magenta.superlayer.bounds), 0.56524 * CGRectGetWidth(_magenta.superlayer.bounds), 0.56524 * CGRectGetHeight(_magenta.superlayer.bounds));
	_magenta.path  = [self magentaPathWithBounds:_magenta.bounds].CGPath;
	_oval.frame    = CGRectMake(0.25 * CGRectGetWidth(_oval.superlayer.bounds), 0.25 * CGRectGetHeight(_oval.superlayer.bounds), 0.5 * CGRectGetWidth(_oval.superlayer.bounds), 0.5 * CGRectGetHeight(_oval.superlayer.bounds));
	_oval.path     = [self ovalPathWithBounds:_oval.bounds].CGPath;
}


- (IBAction)startAllAnimations:(id)sender{
	[self.yellow addAnimation:[self yellowAnimation] forKey:@"yellowAnimation"];
	[self.cyan addAnimation:[self cyanAnimation] forKey:@"cyanAnimation"];
	[self.magenta addAnimation:[self magentaAnimation] forKey:@"magentaAnimation"];
}

- (CAKeyframeAnimation*)yellowAnimation{
	CAKeyframeAnimation * transformAnim = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
	transformAnim.values                = @[@(400 * M_PI/180),
											@(220 * M_PI/180),
											@(220 * M_PI/180)];
	transformAnim.keyTimes              = @[@0, @0.807, @1];
	transformAnim.duration              = 2;
	transformAnim.timingFunction        = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
	transformAnim.repeatCount           = INFINITY;
	transformAnim.fillMode = kCAFillModeBoth;
	transformAnim.removedOnCompletion = NO;
	
	return transformAnim;
}

- (CAKeyframeAnimation*)cyanAnimation{
	CAKeyframeAnimation * transformAnim = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
	transformAnim.values                = @[@(-20 * M_PI/180),
											@(-200 * M_PI/180),
											@(-200 * M_PI/180)];
	transformAnim.keyTimes              = @[@0, @0.807, @1];
	transformAnim.duration              = 2;
	transformAnim.timingFunction        = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
	transformAnim.repeatCount           = INFINITY;
	transformAnim.fillMode = kCAFillModeBoth;
	transformAnim.removedOnCompletion = NO;
	
	return transformAnim;
}

- (CAKeyframeAnimation*)magentaAnimation{
	CAKeyframeAnimation * transformAnim = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
	transformAnim.values                = @[@(0),
											@(360 * M_PI/180),
											@(360 * M_PI/180)];
	transformAnim.keyTimes              = @[@0, @0.807, @1];
	transformAnim.duration              = 2;
	transformAnim.timingFunction        = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
	transformAnim.repeatCount           = INFINITY;
	transformAnim.fillMode = kCAFillModeBoth;
	transformAnim.removedOnCompletion = NO;
	
	return transformAnim;
}

#pragma mark - Bezier Path

- (UIBezierPath*)yellowPathWithBounds:(CGRect)bound{
	UIBezierPath*  yellowPath = [UIBezierPath bezierPathWithRect:bound];
	return yellowPath;
}

- (UIBezierPath*)cyanPathWithBounds:(CGRect)bound{
	UIBezierPath*  cyanPath = [UIBezierPath bezierPathWithRect:bound];
	return cyanPath;
}

- (UIBezierPath*)magentaPathWithBounds:(CGRect)bound{
	UIBezierPath*  magentaPath = [UIBezierPath bezierPathWithRect:bound];
	return magentaPath;
}

- (UIBezierPath*)ovalPathWithBounds:(CGRect)bound{
	UIBezierPath *ovalPath = [UIBezierPath bezierPath];
	CGFloat minX = CGRectGetMinX(bound), minY = CGRectGetMinY(bound), w = CGRectGetWidth(bound), h = CGRectGetHeight(bound);
	
	[ovalPath moveToPoint:CGPointMake(minX + 0.5 * w, minY)];
	[ovalPath addCurveToPoint:CGPointMake(minX, minY + 0.5 * h) controlPoint1:CGPointMake(minX + 0.22386 * w, minY) controlPoint2:CGPointMake(minX, minY + 0.22386 * h)];
	[ovalPath addCurveToPoint:CGPointMake(minX + 0.5 * w, minY + h) controlPoint1:CGPointMake(minX, minY + 0.77614 * h) controlPoint2:CGPointMake(minX + 0.22386 * w, minY + h)];
	[ovalPath addCurveToPoint:CGPointMake(minX + w, minY + 0.5 * h) controlPoint1:CGPointMake(minX + 0.77614 * w, minY + h) controlPoint2:CGPointMake(minX + w, minY + 0.77614 * h)];
	[ovalPath addCurveToPoint:CGPointMake(minX + 0.5 * w, minY) controlPoint1:CGPointMake(minX + w, minY + 0.22386 * h) controlPoint2:CGPointMake(minX + 0.77614 * w, minY)];
	
	return ovalPath;
}

@end