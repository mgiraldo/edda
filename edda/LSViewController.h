//
//  LSViewController.h
//  LiveSessions
//
//  Created by Mauricio Giraldo on 29/1/15.
//  Copyright (c) 2015 Ping Pong Estudio. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import "QBHelper.h"
#import "eddaAppDelegate.h"

@interface LSViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, MKMapViewDelegate>
{
	NSMutableArray * m_userArray;
	NSMutableArray * m_annotationArray;
	NSNumber * m_receiverID;
	NSString * m_receiverTitle;
	CLLocation * m_receiverLocation;
	NSNumber * m_receiverAltitude;
	UIRefreshControl *m_refreshControl;
    __weak IBOutlet UITableView *m_userTableView;
}

@property (nonatomic, assign) eddaAppDelegate* appDelegate;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;

- (IBAction)touchRefresh:(id)sender;

@end
