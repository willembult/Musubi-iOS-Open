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
//  Musubi.m
//  musubi
//
//  Created by Willem Bult on 10/27/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "Musubi.h"

#import "NSData+Crypto.h"
#import "NSData+Base64.h"

#import "UnverifiedIdentityProvider.h"
#import "AphidIdentityProvider.h"

#import "IBEncryptionScheme.h"

#import "MessageEncoder.h"
#import "MessageEncodeService.h"
#import "MessageDecodeService.h"
#import "AMQPTransport.h"
#import "FacebookIdentityUpdater.h"
#import "ObjPipelineService.h"

#import "PersistentModelStore.h"
#import "FeedManager.h"
#import "AccountManager.h"
#import "IdentityManager.h"
#import "IdentityKeyManager.h"
#import "TransportManager.h"
#import "MApp.h"
#import "MFeed.h"
#import "MIdentity.h"

#import "IntroductionObj.h"
#import "Authorities.h"

@implementation Musubi

static Musubi* _sharedInstance = nil;

@synthesize mainStore, storeFactory, notificationCenter, keyManager, encodeService, decodeService, transport;

+(Musubi*)sharedInstance
{
	@synchronized([Musubi class])
	{
		if (!_sharedInstance)
			[[self alloc] init];
        
		return _sharedInstance;
	}
    
	return nil;
}

+(id)alloc
{
	@synchronized([Musubi class])
	{
		NSAssert(_sharedInstance == nil, @"Attempted to allocate a second instance of a singleton.");
		_sharedInstance = [super alloc];
		return _sharedInstance;
	}
    
	return nil;
}

- (id)init {
    self = [super init];
    
    if (self != nil) {
        // The store factory creates stores for other threads, the main store is used on the main thread
        [self setStoreFactory: [[PersistentModelStoreFactory alloc] initWithName:@"Store"]];
        [self setMainStore: [self newStore]];
        
        // The notification sender informs every major part in the system about what's going on
        [self setNotificationCenter: [[NSNotificationCenter alloc] init]];
                
        [self performSelectorInBackground:@selector(setup) withObject:nil];
    }
    
    return self;
}

- (void) setup {    
    
    
    // The identity provider is our main IBE point of contact
    identityProvider = [[[AphidIdentityProvider alloc] init] autorelease];
        
    // The key manager handles our encryption and signature keys
    [self setKeyManager: [[IdentityKeyManager alloc] initWithIdentityProvider: identityProvider]];
    
    // The encoding service encodes all our messages, to be picked up by the transport
    [self setEncodeService: [[MessageEncodeService alloc] initWithStoreFactory: storeFactory andIdentityProvider:identityProvider]];
    
    // The decoding service decodes incoming encoded messages
    [self setDecodeService: [[MessageDecodeService alloc] initWithStoreFactory: storeFactory andIdentityProvider:identityProvider]];
    
    // The transport sends and receives raw data from the network
    [self setTransport: [[AMQPTransport alloc] initWithStoreFactory:storeFactory]];
    [transport start];
    
    // The obj pipeline will process our objs so we can render them
    [[ObjPipelineService alloc] initWithStoreFactory: storeFactory];
    
    // Make sure we keep the facebook friends up to date
    [[FacebookIdentityUpdater alloc] initWithStoreFactory: storeFactory];
    
    [NSThread sleepForTimeInterval:5];
    
    //[self sendTestMessage];
}

- (PersistentModelStore *) newStore {
    return [storeFactory newStore];
}

- (void)dealloc {    
    [super dealloc];
}

@end
