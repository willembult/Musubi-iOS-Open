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
//  AccountAuthManager.h
//  Musubi
//
//  Created by Willem Bult on 3/21/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MAccount.h"
#import "MIdentity.h"
#import "MFeed.h"
#import "IBEncryptionScheme.h"
#import "IdentityManager.h"


@protocol AccountAuthManagerDelegate

- (void) accountWithType: (NSString*) type isConnected: (BOOL) connected;

@end


@interface AccountAuthManager : NSObject {
    id<AccountAuthManagerDelegate> delegate;
    NSOperationQueue* queue;
}

@property (nonatomic, assign) id<AccountAuthManagerDelegate> delegate;
@property (nonatomic, retain) NSOperationQueue* queue;

- (id) initWithDelegate: (id<AccountAuthManagerDelegate>) d;

- (BOOL) isConnected: (NSString*) type;
- (void) checkStatus: (NSString*) type;
- (void) connect: (NSString*) type;
- (void) disconnect: (NSString*) type;

// private
- (void) populateIdentity: (MIdentity*) mIdent fromIBEIdentity: (IBEncryptionIdentity*) ibeId andOriginal: (MIdentity*) original withManager: (IdentityManager*) identityManager andAccountName: (NSString*) accountName;
- (MAccount*) storeAccount: (NSString*) type name: (NSString*) name principal: (NSString*) principal;
- (void) onAccount: (NSString*) type isValid: (BOOL) valid;

@end
