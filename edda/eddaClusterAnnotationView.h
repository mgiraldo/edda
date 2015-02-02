//
//  eddaClusterAnnotationView.m
//  Edda
//
//  Created by Mauricio Giraldo on 29/1/15.
//  Copyright (c) 2015 Ping Pong Estudio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface eddaClusterAnnotationView : MKAnnotationView <MKAnnotation> {
    UILabel *label;
}
- (void) setClusterText:(NSString *)text;
@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;
@end
