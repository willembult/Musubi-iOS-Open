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
//  FacebookAuth.m
//  Musubi
//
//  Created by Willem Bult on 3/20/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "FacebookAuth.h"
#import "AppDelegate.h"

@implementation FacebookConnectOperation

@synthesize facebook, manager;

- (id)initWithManager:(AccountAuthManager *)m {
    self = [super init];
    if (self) {
        [self setFacebook: [[Facebook alloc] initWithAppId:kFacebookAppId andDelegate:self]];
        [self setManager: m];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults objectForKey:@"FBAccessTokenKey"] 
            && [defaults objectForKey:@"FBExpirationDateKey"]) {
            facebook.accessToken = [defaults objectForKey:@"FBAccessTokenKey"];
            facebook.expirationDate = [defaults objectForKey:@"FBExpirationDateKey"];
        }
    }
    
    return self;
}

- (void)fbDidLogin {
}

- (NSArray *)facebookAtIndexes:(NSIndexSet *)indexes {
    return nil;
}

- (void)fbDidLogout {
    
}

- (void)fbDidNotLogin:(BOOL)cancelled {
    
}

- (void)fbSessionInvalidated {
    
}

- (void)fbDidExtendToken:(NSString *)accessToken expiresAt:(NSDate *)expiresAt {
}

@end


@implementation FacebookCheckValidOperation

- (void)main {
    if ([facebook isSessionValid]) {
        [facebook requestWithGraphPath:@"me" andDelegate:self];
    } else {
        [manager onAccount:kAccountTypeFacebook isValid:NO];
    }
}

- (void)request:(FBRequest *)request didLoad:(id)result {
    BOOL valid = result != nil && [result objectForKey:@"id"] != nil;
    [manager onAccount:kAccountTypeFacebook isValid:valid];
}

@end


@implementation FacebookLoginOperation

- (void)main {
    finished = NO;
    
//    if (![facebook isSessionValid]) {
        // App delegate is the one who gets called back after login, needs a reference here
        [((AppDelegate*) [[UIApplication sharedApplication] delegate]) setFacebookLoginOperation: self];

        NSArray *permissions = [[[NSArray alloc] initWithObjects:
                                 @"read_friendlists", 
                                 @"email",
                                 @"offline_access",
                                 @"publish_stream",
                                 nil] autorelease];
        [facebook authorize:permissions];
//    }
}

// Because the SSO runs asynchronously, we have to make sure the thread doesn't get destroyed until we're completely done
- (BOOL)isFinished {
    return [super isFinished] && finished;
}

- (BOOL)handleOpenURL:(NSURL *)url {
    // Remove the reference
    [((AppDelegate*) [[UIApplication sharedApplication] delegate]) setFacebookLoginOperation: nil];
    return [facebook handleOpenURL:url];
}

- (void)fbDidLogin {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[facebook accessToken] forKey:@"FBAccessTokenKey"];
    [defaults setObject:[facebook expirationDate] forKey:@"FBExpirationDateKey"];
    [defaults synchronize];
    
    // Request "me" from Graph API to create the account with
    [facebook requestWithGraphPath:@"me" andDelegate:self];
}

- (void)request:(FBRequest *)request didLoad:(id)result {
    if (result != nil && [result objectForKey:@"id"] != nil) {
        MAccount* account = [manager storeAccount:kAccountTypeFacebook name:[result objectForKey:@"email"] principal:[result objectForKey:@"id"]];
        [manager onAccount:kAccountTypeFacebook isValid:account != nil];
    } else {
        [manager onAccount:kAccountTypeFacebook isValid:NO];
    }
    
    finished = YES;
}

@end
