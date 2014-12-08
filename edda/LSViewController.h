//
//  LSViewController.h
//  LiveSessions
//
//  Created by Nirav Bhatt on 4/13/13.
//  Copyright (c) 2013 IPhoneGameZone. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "QBHelper.h"
#import "eddaAppDelegate.h"

@interface LSViewController : UIViewController<UITableViewDataSource, UITableViewDelegate>
{
    NSMutableArray * m_userArray; 
	NSNumber * m_receiverID;
	NSString * m_receiverTitle;
	CLLocation * m_receiverLocation;
	NSNumber * m_receiverAltitude;
    __weak IBOutlet UITableView *m_userTableView;
    bool bAudioOnly;
    eddaAppDelegate * appDelegate;
}
- (IBAction)touchRefresh:(id)sender;

@end
