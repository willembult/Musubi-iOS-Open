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
//  MessageDecoder.m
//  Musubi
//
//  Created by Willem Bult on 2/29/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MessageDecoder.h"
#import "NSData+Crypto.h"
#import "NSData+Base64.h"
#import "Musubi.h"

#import "BSONEncoder.h"
#import "PersistentModelStore.h"
#import "MIncomingSecret.h"
#import "MIdentity.h"
#import "MDevice.h"
#import "MEncodedMessage.h"

#import "IncomingMessage.h"

#import "IBEncryptionScheme.h"
#import "Sender.h"
#import "Recipient.h"
#import "Message.h"
#import "Secret.h"
#import "Authorities.h"

@implementation MessageDecoder

@synthesize transportDataProvider, encryptionScheme, signatureScheme;

- (id)initWithTransportDataProvider:(id<TransportDataProvider>)tdp {
    self = [super init];
    if (self) {
        [self setTransportDataProvider: tdp];
        [self setEncryptionScheme: [tdp encryptionScheme]];
        [self setSignatureScheme: [tdp signatureScheme]];        
    }
    return self;
}

- (MIdentity*) addIdentityWithKey: (NSData*) key {
    return [transportDataProvider addClaimedIdentity:[[[IBEncryptionIdentity alloc] initWithKey:key] autorelease]];
}

- (MDevice*) addDevice: (MIdentity*) ident withId:(NSData*)devId {
    return [transportDataProvider addDeviceWithName:CFSwapInt64BigToHost(*(uint64_t*)[devId bytes]) forIdentity:ident];
}


- (NSData*) computeSignatureWithKey: (NSData*) key andDeviceId: (uint64_t) deviceId {
    uint64_t deviceIdBigEndian = CFSwapInt64HostToBig(deviceId);
    
    NSMutableData* sigData = [NSMutableData dataWithData: key];
    [sigData appendBytes:&deviceIdBigEndian length:sizeof(deviceIdBigEndian)];
    return [sigData sha256Digest];
}

- (void) checkDuplicateFromDevice: (MDevice*) from withRawHash: (NSData*) hash {
    if ([transportDataProvider haveHash: hash]) {
        @throw [NSException exceptionWithName:kMusubiExceptionDuplicateMessage reason:[NSString stringWithFormat:@"Duplicate message from device %@", from] userInfo:[NSDictionary dictionaryWithObjectsAndKeys:from, @"from", nil]];
    }
    
    /*else {
        @throw [NSException exceptionWithName:kMusubiExceptionCollission reason:[NSString stringWithFormat:@"Collision message from device %lld", from.id] userInfo:nil];
    }*/
}

- (MIncomingSecret *)addIncomingSecretFrom:(MIdentity *)from atDevice:(MDevice *)device to:(MIdentity *)to sender:(Sender *)s recipient:(Recipient *)me {
    
    IBEncryptionIdentity* meTimed = [[[IBEncryptionIdentity alloc] initWithKey: me.i] autorelease];
    IBEncryptionIdentity* sid = [[[IBEncryptionIdentity alloc] initWithKey: s.i] autorelease];
    
    //TODO: make sure not to waste time computing the same secret twice if someone uses
    //this in a multi-threaded way
    MIncomingSecret* is = [transportDataProvider lookupIncomingSecretFrom:from onDevice:device to:to withSignature:me.s otherIdentity:meTimed myIdentity:sid];
    if(is != nil)
        return is;
    
    is = (MIncomingSecret*)[[transportDataProvider store] createEntity:@"IncomingSecret"];
    [is setMyIdentity: to];
    [is setOtherIdentity: from];
    [is setDevice: device];

    IBEncryptionUserKey* userKey = [transportDataProvider encryptionKeyTo:to myIdentity:meTimed];
    [is setKey: [encryptionScheme decryptConversationKey:[[[IBEncryptionConversationKey alloc] initWithRaw:nil andEncrypted:me.k] autorelease] withUserKey:userKey]];

    [is setEncryptedKey: me.k];
    [is setEncryptionPeriod: meTimed.temporalFrame];
    [is setSignaturePeriod: sid.temporalFrame];
    [is setSignature: me.s];
    
    NSData* hash = [self computeSignatureWithKey:is.encryptedKey andDeviceId:device.deviceName];
    
    if (![signatureScheme verifySignature:is.signature forHash:hash withIdentity:sid]) {
        @throw [NSException exceptionWithName:kMusubiExceptionBadSignature reason:@"Message failed to have a valid signature for my recipient key" userInfo:nil];
    }
    
    [transportDataProvider insertIncomingSecret:is otherIdentity:sid myIdentity:meTimed];
    return is;
}

- (void) checkSignatureForHash: (NSData*) hash withApp: (NSData*) app blind: (BOOL) blind forRecipients: (NSArray*) rs againstExpected: (NSData*) expected  {
    NSMutableData* sigData = [NSMutableData dataWithData: hash];
    [sigData appendData:app];
    [sigData appendBytes:&blind length: sizeof(blind)];
    if (!blind) {
        for (Recipient* r in rs) {
            [sigData appendData: r.i];
        }
    }
    
    NSData* signature = [sigData sha256Digest];
    
    if (![signature isEqualToData:expected]) {
        @throw [NSException exceptionWithName:kMusubiExceptionBadSignature reason:[NSString stringWithFormat: @"Signature mismatch for data, was %@ should be %@", [hash encodeBase64], [expected encodeBase64]] userInfo:nil];
    }
}

- (IncomingMessage *)decodeMessage:(MEncodedMessage *)encoded {
    IncomingMessage* im = [[[IncomingMessage alloc] init] autorelease];
    Message* m = [BSONEncoder decodeMessage: encoded.encoded];
    
    // Find my recipient data from the list of recipients in the message
    NSMutableArray* mine = [NSMutableArray array];
    for (Recipient* r in m.r) {
        IBEncryptionIdentity* ident = [[[IBEncryptionIdentity alloc] initWithKey:r.i] autorelease];
        if ([transportDataProvider isMe:ident]) {
            [mine addObject: r];
        }
    }
    
    if (mine.count == 0)
        @throw [NSException exceptionWithName:kMusubiExceptionRecipientMismatch reason:@"Couldn't find a recipient that matches me" userInfo:nil];
    
    // This will add all of the relevant identities and devices to the tables
    
    NSMutableArray* rcpts = [NSMutableArray array];
    for (Recipient* r in m.r) {
        [rcpts addObject: [self addIdentityWithKey:r.i]];
    }
    
    [im setFromIdentity: [self addIdentityWithKey:m.s.i]];
    if ([transportDataProvider isBlackListed:[im fromIdentity]]) {
        @throw [NSException exceptionWithName:kMusubiExceptionSenderBlacklisted reason:[NSString stringWithFormat: @"Received message from blacklisted identity: %@", im.fromIdentity] userInfo:nil];
    }
    
    [im setFromDevice: [self addDevice:im.fromIdentity withId:m.s.d]];
    [self checkDuplicateFromDevice:im.fromDevice withRawHash:[encoded.encoded sha256Digest]];
    
    
    [im setApp: m.a];
    [im setBlind: m.l];
        
    NSMutableArray* personas = [NSMutableArray array];
    for (Recipient* me in mine) {
        [personas addObject: [self addIdentityWithKey: me.i]];
    }
    [im setPersonas: personas];
    
    if (im.blind) {
        [im setRecipients:personas];
    } else {
        NSMutableArray* recipients = [NSMutableArray array];
        for (Recipient* r in m.r) {
            IBEncryptionIdentity* hid = [[IBEncryptionIdentity alloc] initWithKey:r.i];
            
            // Don't accept messages from clients that erroneously include
            // a local user in the group
            if (hid.authority == kIdentityTypeLocal) {
                @throw [NSException exceptionWithName:kMusubiExceptionInvalidAccountType reason:@"Can't be local here" userInfo:nil];
            }
            
            [recipients addObject: [transportDataProvider addUnclaimedIdentity: hid]];
        }
        [im setRecipients: recipients];
    }
        
    for(int i = 0; i < im.personas.count; ++i) {
        Recipient* me = [mine objectAtIndex:i];
        MIdentity* persona = [im.personas objectAtIndex:i];
        
        //checks the secret if it is actually added
        MIncomingSecret* inSecret = [self addIncomingSecretFrom:im.fromIdentity atDevice:im.fromDevice to:persona sender:m.s recipient:me];
        
        NSData* rcptSecret = [me.d decryptWithAES128CBCZeroPaddedWithKey:inSecret.key andIV:m.i];
        Secret* secret = [BSONEncoder decodeSecret: rcptSecret];
        
        [im setSequenceNumber: secret.q];
        
        //This makes it so that we only compute
        //the data and the hash once per message
        if (im.data == nil) {
            [im setData: [m.d decryptWithAES128CBCPKCS7WithKey:secret.k andIV:m.i]];
        }
        if (im.hash == nil) {
            [im setHash: [im.data sha256Digest]];
        }
        
        [self checkSignatureForHash:im.hash withApp:im.app blind:im.blind forRecipients:m.r againstExpected:secret.h];
        //updateMissingMessages(im.fromDevice_, secret.q);
    }
        
    [encoded setFromDevice: im.fromDevice];
    [encoded setFromIdentity: im.fromIdentity];
    [encoded setMessageHash: im.hash];
    [encoded setSequenceNumber: im.sequenceNumber];
    [transportDataProvider updateEncodedMetadata:encoded];
    
    return im;
}


@end
