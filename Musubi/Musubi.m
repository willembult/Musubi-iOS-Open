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

@implementation Musubi

static Musubi* _sharedInstance = nil;

@synthesize feedListeners;


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
        transport = [[RabbitMQMessengerService alloc] initWithListener:self];
        feedListeners = [[NSMutableDictionary alloc] init];
        messageFormat = [[MessageFormat defaultMessageFormat] retain];
        identity = [Identity sharedInstance];
    }
    
    return self;
}

- (void)dealloc {
    [messageFormat release];
    [feedListeners release];
    [transport release];
    
    [super dealloc];
}

- (void)startTransport {
    [NSThread detachNewThreadSelector:@selector(run) toTarget:transport withObject:nil];
}


- (int)handleIncoming:(EncodedMessage *)encoded {
    // decode
    SignedMessage* msg = [messageFormat decodeMessage:encoded withKeyPair:[identity keyPair]];
    NSLog(@"Incoming: %@", msg);
    
    // save
    ManagedFeed* feed = [[ObjectStore sharedInstance] feedForSession: [msg feedName]];
    [feed storeMessage:msg];

    // and notify
    NSArray* listeners = [feedListeners objectForKey: [msg feedName]];
    if (listeners != nil) {
        for (id<MusubiFeedListener> listener in listeners) {
            [listener newMessage:msg];
        }
    }
    
    return 1;
}

- (NSArray *)groups {
    NSMutableArray* groups = [NSMutableArray array];
    for (ManagedFeed* feed in [[ObjectStore sharedInstance] feeds]) {
        Feed* group = [[Feed alloc] initWithName:[feed name] feedUri:[NSURL URLWithString:[feed url]]];

        NSMutableArray* members = [NSMutableArray array];
        for (ManagedUser* member in [feed allMembers]) {
            [members addObject:[member user]];
        }
        [group setMembers:members];
        
        [groups addObject: group];
    }
    return groups;
}

- (ManagedFeed*) joinGroup:(Feed *)group {
    ManagedFeed* existing = [[ObjectStore sharedInstance] feedForSession:[group session]];
    if (existing != nil) {
        [[[[GroupProvider alloc] init] autorelease] updateGroup:group sinceVersion:-1];
        JoinNotificationObj* jno = [[[JoinNotificationObj alloc] initWithURI:[[group feedUri] absoluteString]] autorelease];
        [self sendObj: jno forApp:kMusubiAppId toGroup:group];

        return existing;
    }
    
    [[[[GroupProvider alloc] init] autorelease] updateGroup:group sinceVersion:-1];
    
    ManagedFeed* feed = [[ObjectStore sharedInstance] storeFeed: group];
    
    JoinNotificationObj* jno = [[[JoinNotificationObj alloc] initWithURI:[[group feedUri] absoluteString]] autorelease];
    [self sendObj: jno forApp:kMusubiAppId toGroup:group];
    
    return feed;
}

- (ManagedFeed *)feedForGroup:(Feed *)group {
    return [[ObjectStore sharedInstance] feedForSession:[group session]];
}


- (void)listenToGroup:(Feed *)group withListener:(id<MusubiFeedListener>)listener {
    NSMutableArray* listeners = [feedListeners objectForKey: [group session]];
    if (listeners == nil) {
        listeners = [NSMutableArray arrayWithCapacity:1];
        [feedListeners setObject:listeners forKey:[group session]];
    }
    
    [listeners addObject:listener];
}

- (void) sendMessage: (Message*) msg {
    EncodedMessage* encoded = [messageFormat encodeMessage:msg withKeyPair:[identity keyPair]];
    SignedMessage* signedMsg = [SignedMessage createFromMessage:msg withHash: [[[encoded signature] sha1Digest] hex]];
    
    // send
    [transport sendMessage:encoded to:[msg recipients]];
    
    // and save
    ManagedFeed* feed = [[ObjectStore sharedInstance] feedForSession: [msg feedName]];
    [feed storeMessage:signedMsg];
    
    // and notify
    NSArray* listeners = [feedListeners objectForKey: [msg feedName]];
    if (listeners != nil) {
        for (id<MusubiFeedListener> listener in listeners) {
            [listener newMessage:signedMsg];
        }
    }
}

- (void)sendObj:(Obj *)obj forApp:(NSString *)appId toGroup:(Feed *)group {
    NSMutableArray* pubKeys = [NSMutableArray arrayWithArray:[group publicKeys]];
    NSString* myPubKey = [[Identity sharedInstance] publicKeyBase64];
    while ([pubKeys containsObject:myPubKey]) {
        [pubKeys removeObject: myPubKey];
    }
    
    Message* msg = [[Message alloc] init];
    [msg setObj:obj];
    [msg setSender:[[Identity sharedInstance] user]];
    [msg setRecipients:pubKeys];
    [msg setAppId:appId];
    [msg setFeedName:[group session]];
    [msg setTimestamp:[NSDate date]];

    [self sendMessage:msg];
}

- (User *)userWithPublicKey:(NSData *)publicKey {
    ManagedUser* user = [[ObjectStore sharedInstance] userWithPublicKey:publicKey];
    return [user user];
}

@end
