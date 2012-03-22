//
//  AppDelegate.h
//  musubi
//
//  Created by Willem Bult on 10/5/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Musubi.h"
#import "FacebookAuth.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (retain, nonatomic) UIWindow *window;

// Facebook SingleSignOn always calls back the appDelegate, so we need a reference to the login
@property (nonatomic, assign) FacebookLoginOperation* facebookLoginOperation;

@end
