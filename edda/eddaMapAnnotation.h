//
//  eddaMapAnnotation.h
//  Edda
//
//  Created by Mauricio Giraldo on 24/1/15.
//  Copyright (c) 2015 Ping Pong Estudio. All rights reserved.
//

#import <MapKit/MapKit.h>

@interface eddaMapAnnotation : NSObject <MKAnnotation>

@property (nonatomic) CLLocationCoordinate2D coordinate;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic) NSInteger index;

@end
