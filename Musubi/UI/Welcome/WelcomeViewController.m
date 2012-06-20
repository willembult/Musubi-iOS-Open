/*
 * Copyright 2012 The Stanford MobiSocial Laboratory
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


//
//  WelcomeViewController.m
//  musubi
//
//  Created by Willem Bult on 6/19/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "WelcomeViewController.h"
#import "MAccount.h"
#import "Musubi.h"
#import "Three20/Three20.h"

@implementation WelcomeViewController

@synthesize authMgr = _authMgr, facebookButton = _facebookButton, googleButton = _googleButton, statusLabel = _statusLabel;

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setAuthMgr:[[AccountAuthManager alloc] initWithDelegate:self]];
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Color
    self.navigationController.navigationBar.tintColor = [((id)[TTStyleSheet globalStyleSheet]) navigationBarTintColor];
    
    [[Musubi sharedInstance].notificationCenter addObserver:self selector:@selector(updateImporting:) name:kMusubiNotificationIdentityImported object:nil];
    [[Musubi sharedInstance].notificationCenter addObserver:self selector:@selector(updateImporting:) name:kMusubiNotificationIdentityImportFinished object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [[Musubi sharedInstance].notificationCenter removeObserver:self name:kMusubiNotificationIdentityImported object:nil];
    [[Musubi sharedInstance].notificationCenter removeObserver:self name:kMusubiNotificationIdentityImportFinished object:nil];
}
    
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)authNetwork:(id)sender {
    NSString* type = sender == self.facebookButton ? kAccountTypeFacebook : kAccountTypeGoogle;
    [_authMgr performSelectorInBackground:@selector(connect:) withObject:type];
}

#pragma mark - AccountAuthManager delegate

- (void)accountWithType:(NSString *)type isConnected:(BOOL)connected {
    if (connected) {
        _facebookButton.hidden = YES;
        _googleButton.hidden = YES;
        _statusLabel.text = @"Importing contacts...";
    }
}

- (void) updateImporting: (NSNotification*) notification {
    if (![NSThread currentThread].isMainThread) {
        [self performSelectorOnMainThread:@selector(updateImporting:) withObject:notification waitUntilDone:NO];
        return;
    }    
    
    BOOL importDone = NO;
    
    if ([notification.object objectForKey:@"index"]) {
        NSNumber* index = [notification.object objectForKey:@"index"];
        NSNumber* total = [notification.object objectForKey:@"total"];
        
        int remaining = total.intValue - index.intValue - 1;
        
        if (remaining > 0) {
            [_statusLabel setText:[NSString stringWithFormat: @"Importing %d contacts...", remaining]];
        } else {
            importDone = YES;
        }
    } else {
        importDone = YES;
    }
    
    if (importDone) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

@end