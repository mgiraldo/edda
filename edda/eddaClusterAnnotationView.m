//
//  
//    ___  _____   ______  __ _   _________ 
//   / _ \/ __/ | / / __ \/ /| | / / __/ _ \
//  / , _/ _/ | |/ / /_/ / /_| |/ / _// , _/
// /_/|_/___/ |___/\____/____/___/___/_/|_| 
//
//  Created by Bart Claessens. bart (at) revolver . be
//

#import "eddaClusterAnnotationView.h"

static const float _size = 30;

@implementation eddaClusterAnnotationView

@synthesize coordinate;

- (id) initWithAnnotation:(id<MKAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
    if ( self )
    {
		UIView * background = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _size, _size)];
		background.backgroundColor = [UIColor blackColor];
		background.layer.borderWidth = 1;
		background.layer.borderColor = [UIColor whiteColor].CGColor;
		background.layer.cornerRadius = _size * .5;
		[self addSubview:background];

		label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, _size, _size)];
        [self addSubview:label];
        label.textColor = [UIColor yellowColor];
        label.backgroundColor = [UIColor clearColor];
		label.font = [UIFont fontWithName:@"AvenirNextCondensed-Medium" size:12];
        label.textAlignment = NSTextAlignmentCenter;
		
		self.frame = background.frame;
    }
    return self;
}

- (void) setClusterText:(NSString *)text
{
    label.text = text;
}

@end
