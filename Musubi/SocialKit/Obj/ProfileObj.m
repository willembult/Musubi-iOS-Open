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

#define kProfileObjReply @"reply"
#define kProfileObjVersion @"version"
#define kProfileObjName @"name"
#define kProfileObjPrincipal @"principal"

@implementation ProfileObj

- (id) initWithUser: (MIdentity*)user replyRequested:(BOOL)replyRequested includePrincipal:(BOOL)includePrincipal
{
    self = [super init];
    if (!self)
    return nil;

    NSMutableDictionary* profile = [NSMutableDictionary dictionaryWithCapacity:4];
    [profile setValue:[NSNumber numberWithBool:replyRequested] forKey:kProfileObjReply];
    [profile setValue:[NSNumber numberWithLongLong:(long long)([[NSDate date] timeIntervalSince1970] * 1000)] forKey:kProfileObjVersion];
    [profile setValue:user.musubiName forKey:kProfileObjName];
    if(includePrincipal) {
        [profile setValue:user.principal forKey:kProfileObjPrincipal];
    }

    self.data = profile;
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
    NSDictionary* profile = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUnicodeStringEncoding] options:0 error:&error];
    if(!profile) {
        NSLog(@"failed to parse json in profile obj from %@ : %@", sender, error);
        return;
    }
    IdentityManager* idm = [[IdentityManager alloc] initWithStore:store];

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
                sender.musubiThumbnail = raw;
                if(sender.owned) {
                    for(MIdentity* me in [idm ownedIdentities]) {
                        me.musubiThumbnail = sender.musubiThumbnail;
                    }
                }
            }
            NSObject* nameString = [profile valueForKey:kProfileObjName];
            if(nameString && [nameString isKindOfClass:[NSString class]]) {
                sender.musubiName = (NSString*)nameString;
                if(sender.owned) {
                    for(MIdentity* me in [idm ownedIdentities]) {
                        me.musubiName = sender.musubiName;
                    }
                }
            }
            NSObject* principalString = [profile valueForKey:kProfileObjPrincipal];
            if(principalString && [principalString isKindOfClass:[NSString class]]) {
                NSString* principal = (NSString*)principalString;
                sender.musubiName = (NSString*)nameString;
                if([sender.principalHash isEqualToData:[[principal dataUsingEncoding:NSUnicodeStringEncoding] sha256Digest]]) {
                    sender.principal = principal;
                }
            }
        }
        [store save];
    }
    NSObject* replyFlag = [profile valueForKey:kProfileObjReply];
    if(replyFlag && [replyFlag isKindOfClass:[NSNumber class]]) {
        AppManager* am = [[AppManager alloc] initWithStore:store];
        MApp* app = [am ensureAppWithAppId:@"mobisocial.musubi"];
        
        FeedManager* fm = [[FeedManager alloc] initWithStore: store];
        for(MIdentity* me in [idm ownedIdentities]) {
            MFeed* f = [fm createOneTimeUseFeedWithParticipants:[NSArray arrayWithObjects:me, sender, nil]];
            [ObjHelper sendObj:[[ProfileObj alloc] initWithUser:me replyRequested:NO includePrincipal:NO] toFeed:f fromApp:app usingStore:store];
        }
    }
}
@end
