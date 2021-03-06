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
//  ProfileObj.m
//  musubi
//
//  Created by T.J. Purtell on 5/25/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ProfileObj.h"
#import "IdentityManager.h"
#import "NSData+Crypto.h"
#import "PersistentModelStore.h"
#import "ObjHelper.h"
#import "AppManager.h"
#import "FeedManager.h"
#import "Authorities.h"
#import "Musubi.h"
#import "MFeed.h"

#define kProfileObjReply @"reply"
#define kProfileObjVersion @"version"
#define kProfileObjName @"name"
#define kProfileObjPrincipal @"principal"
#define kProfileObjProfile @"profile"

@implementation ProfileObj

- (id) initWithUser: (MIdentity*)user replyRequested:(BOOL)replyRequested includePrincipal:(BOOL)includePrincipal
{
    self = [super init];
    if (!self)
    return nil;

    NSMutableDictionary* data = [NSMutableDictionary dictionaryWithCapacity:4];
    [data setValue:[NSNumber numberWithBool:replyRequested] forKey:kProfileObjReply];
    [data setValue:[NSNumber numberWithLongLong:(long long)([[NSDate date] timeIntervalSince1970] * 1000)] forKey:kProfileObjVersion];
    [data setValue:user.musubiName forKey:kProfileObjName];
    if(includePrincipal) {
        [data setValue:user.principal forKey:kProfileObjPrincipal];
    }
    
    if (user.profile) {
        NSDictionary* dict = [IdentityManager deserializeProfile:user.profile];
        
        if (dict != nil && [dict isKindOfClass:[NSDictionary class]]) {
            [data setValue:dict forKey:kProfileObjProfile];
        }
    }

    self.data = data;
    self.type = kObjTypeProfile;
    self.raw = user.musubiThumbnail;
    return self;
}
- (id) initRequest
{
    NSMutableDictionary* profile = [NSMutableDictionary dictionaryWithCapacity:4];
    [profile setValue:[NSNumber numberWithBool:YES] forKey:kProfileObjReply];
    self.data = profile;
    self.type = kObjTypeProfile;
    return self;
}
+ (void)handleFromSender:(MIdentity*)sender profileJson:(NSString*)json profileRaw:(NSData*)raw withStore:(PersistentModelStore*)store
{
    if(!json) {
        NSLog(@"received profile without content");
        return;
    }

    NSError* error = nil;
    NSDictionary* profile = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
    if(!profile) {
        NSLog(@"failed to parse json in profile obj from %@ : %@", sender, error);
        return;
    }
    IdentityManager* idm = [[IdentityManager alloc] initWithStore:store];
    
    BOOL changed = NO;

    NSObject* versionNumber = [profile valueForKey:kProfileObjVersion];
    if(versionNumber && [versionNumber isKindOfClass:[NSNumber class]]) {
        long long version = ((NSNumber*)versionNumber).longLongValue;
        if (sender.receivedProfileVersion < version) {
            sender.receivedProfileVersion = version;
            if(sender.owned) {
                for(MIdentity* me in [idm ownedIdentities]) {
                    me.receivedProfileVersion = sender.receivedProfileVersion;
                }
            }
            if (raw) {
                if(![sender.musubiThumbnail isEqualToData:raw])
                    changed = YES;

                sender.musubiThumbnail = raw;
                if(sender.owned) {
                    for(MIdentity* me in [idm ownedIdentities]) {
                        if(![me.musubiThumbnail isEqualToData:raw])
                            changed = YES;
                        me.musubiThumbnail = sender.musubiThumbnail;
                    }
                }
            }
            NSObject* nameString = [profile valueForKey:kProfileObjName];
            if(nameString && [nameString isKindOfClass:[NSString class]]) {
                if(![sender.musubiName isEqualToString:(NSString*)nameString])
                    changed = YES;
                sender.musubiName = (NSString*)nameString;
                if(sender.owned) {
                    for(MIdentity* me in [idm ownedIdentities]) {
                        if(![me.musubiName isEqualToString:(NSString*)nameString])
                            changed = YES;
                        me.musubiName = sender.musubiName;
                    }
                }
            }
            NSObject* principalString = [profile valueForKey:kProfileObjPrincipal];
            if(principalString && [principalString isKindOfClass:[NSString class]]) {
                NSString* principal = (NSString*)principalString;
                if(![sender.principalHash isEqualToData:[[principal dataUsingEncoding:NSUTF8StringEncoding] sha256Digest]]) {
                    sender.principal = principal;
                    changed = YES;
                }
            }
            
            NSDictionary* profileDict = [profile valueForKey:kProfileObjProfile];
            if (profileDict && [profileDict isKindOfClass:[NSDictionary class]]) {
                NSData* data = [IdentityManager serializeProfile:profileDict];
                if (![sender.profile isEqualToData:data]) {
                    sender.profile = data;
                    changed = YES;
                }
            }
        }
        [store save];
    }
    NSObject* replyFlag = [profile valueForKey:kProfileObjReply];
    if(replyFlag && [replyFlag isKindOfClass:[NSNumber class]] && ((NSNumber*)replyFlag).boolValue) {
        [ProfileObj sendProfilesTo:[NSArray arrayWithObject:sender] replyRequested:NO withStore:store];
    }
    
    if(changed) {
        // Update every FeedView for feeds the sender participates in
        FeedManager* feedMgr = [[FeedManager alloc] initWithStore:store];
        for (MFeed* feed in [feedMgr acceptedFeedsFromIdentity:sender]) {
            [[Musubi sharedInstance].notificationCenter postNotificationName:kMusubiNotificationUpdatedFeed object:feed.objectID];        
        }
    }
}

+(void)sendProfilesTo:(NSArray*)people replyRequested:(BOOL)replyRequested withStore:(PersistentModelStore*)store
{
    IdentityManager* idm = [[IdentityManager alloc] initWithStore:store];
    AppManager* am = [[AppManager alloc] initWithStore:store];
    MApp* app = [am ensureAppWithAppId:@"mobisocial.musubi"];

    FeedManager* fm = [[FeedManager alloc] initWithStore: store];
    long long profileVersion = 1;
    for(MIdentity* me in [idm ownedIdentities]) {
        if(me.type == kIdentityTypeLocal)
            continue;
        profileVersion = MAX(me.receivedProfileVersion, profileVersion);
        MFeed* f = [fm createOneTimeUseFeedWithParticipants:[[NSArray arrayWithObject:me] arrayByAddingObjectsFromArray:people]];
        [ObjHelper sendObj:[[ProfileObj alloc] initWithUser:me replyRequested:replyRequested includePrincipal:NO] toFeed:f asIdentity:me fromApp:app usingStore:store];
    }
    for(MIdentity* you in people) {
        you.sentProfileVersion = profileVersion;
    }
    [store save];
}
+(void)sendAllProfilesWithStore:(PersistentModelStore*)store
{
    IdentityManager* idm = [[IdentityManager alloc] initWithStore:store];
    AppManager* am = [[AppManager alloc] initWithStore:store];
    MApp* app = [am ensureAppWithAppId:@"mobisocial.musubi"];
    
    FeedManager* fm = [[FeedManager alloc] initWithStore: store];
    MFeed* f = [fm global];
    long long profileVersion = 1;
    NSArray* all = [idm claimedIdentities];
    for(MIdentity* me in [idm ownedIdentities]) {
        if(me.type == kIdentityTypeLocal)
            continue;
        profileVersion = MAX(me.receivedProfileVersion, profileVersion);
        [ObjHelper sendObj:[[ProfileObj alloc] initWithUser:me replyRequested:NO includePrincipal:NO] toFeed:f asIdentity:me fromApp:app usingStore:store];
    }
    for(MIdentity* you in all) {
        you.sentProfileVersion = profileVersion;
    }
    [store save];
}
@end
