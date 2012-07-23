//
//  Musubi.h
//  musubi
//
//  Created by Willem Bult on 10/27/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IdentityProvider.h"

static NSString* kMusubiAppId = @"edu.stanford.mobisocial.dungbeetle";

#define kMusubiNotificationOwnedIdentityAvailable @"OwnedIdentityAvailable"
#define kMusubiNotificationAuthTokenRefresh @"AuthTokenRefresh"
#define kMusubiNotificationAuthAccountValid @"AuthAccountValid"
#define kMusubiNotificationAuthAccountFailed @"AuthAccountFailed"
#define kMusubiNotificationFacebookFriendRefresh @"FacebookFriendRefresh"
#define kMusubiNotificationGoogleFriendRefresh @"GoogleFriendRefresh"
#define kMusubiNotificationAddressBookRefresh @"AddressBookRefresh"
#define kMusubiNotificationMyProfileUpdate @"MyProfileUpdated"
#define kMusubiNotificationObjSent @"ObjSent"
#define kMusubiNotificationEncodedMessageSent @"EncodedMessageSent"
#define kMusubiNotificationEncodedMessageReceived @"EncodedMessageReceived"
#define kMusubiNotificationPreparedEncoded @"EncodedMessagePrepared"
#define kMusubiNotificationPlainObjReady @"PlainObjReady"
#define kMusubiNotificationAppObjReady @"AppObjRead"
#define kMusubiNotificationMessageEncodeStarted @"MessageEncodeStarted"
#define kMusubiNotificationMessageDecodeStarted @"MessageDecodeStarted"
#define kMusubiNotificationMessageDecodeFinished @"MessageDecodeFinished"
#define kMusubiNotificationUpdatedFeed @"UpdatedFeed"
#define kMusubiNotificationIdentityImported @"IdentityImported"
#define kMusubiNotificationIdentityImportFinished @"IdentityImportFinished"

#define kMusubiExceptionDuplicateMessage @"DuplicateMessage"
#define kMusubiExceptionRecipientMismatch @"RecipientMismatch"
#define kMusubiExceptionSenderBlacklisted @"SenderBlacklisted"
#define kMusubiExceptionMessageCorrupted @"MessageCorrupted"
#define kMusubiExceptionBadSignature @"BadSignature"
#define kMusubiExceptionNeedEncryptionUserKey @"NeedEncryptionUserKey"
#define kMusubiExceptionNeedSignatureUserKey @"NeedSignatureUserKey"
#define kMusubiExceptionInvalidAccountType @"InvalidAccountType"
#define kMusubiExceptionNotFound @"NotFound"
#define kMusubiExceptionInvalidRequest @"InvalidRequest"
#define kMusubiExceptionFeedWithoutOwnedIdentity @"NoOwnedIdentityInFeed"
#define kMusubiExceptionAppNotAllowedInFeed @"AppNotAllowedInFeed"
#define kMusubiExceptionMessageTooLarge @"MessageTooLarge"
#define kMusubiExceptionBadObjFormat @"BadObjFormat"
#define kMusubiExceptionUnexpected @"Unexpected"

#define kMusubiThreadPriorityBackground 0.0

@class PersistentModelStore, PersistentModelStoreFactory, IdentityKeyManager, MessageEncodeService, MessageDecodeService, AMQPTransport, ObjProcessorService, FacebookIdentityUpdater, GoogleIdentityUpdater, AddressBookIdentityManager, CorralHTTPServer, FacebookLoginOperation;


@interface Musubi : NSObject {
    id<IdentityProvider> identityProvider;
}

// store to use on the main thread
@property (nonatomic, strong) PersistentModelStore* mainStore;
@property (nonatomic, strong) PersistentModelStoreFactory* storeFactory;

@property (nonatomic, strong) NSNotificationCenter* notificationCenter;

@property (nonatomic, strong) AMQPTransport* transport;
@property (nonatomic, strong) IdentityKeyManager* keyManager;
@property (nonatomic, strong) MessageEncodeService* encodeService;
@property (nonatomic, strong) MessageDecodeService* decodeService;
@property (nonatomic, strong) ObjProcessorService* objPipelineService;
//this is updated in the main thread for notifications, but it also 
//read from a background thread
@property (atomic, strong) NSString* apnDeviceToken;

@property (nonatomic, strong) FacebookIdentityUpdater* facebookIdentityUpdater;
@property (nonatomic, strong) GoogleIdentityUpdater* googleIdentityUpdater;
@property (nonatomic, strong) AddressBookIdentityManager* addressBookIdentityUpdater;

@property (nonatomic, strong) CorralHTTPServer* corralHTTPServer;

// Facebook SingleSignOn always calls back the appDelegate, so we need a reference to the login
@property (nonatomic, weak) FacebookLoginOperation* facebookLoginOperation;

+ (Musubi*) sharedInstance;

// creates a new store on the current thread
- (PersistentModelStore*) newStore;

- (void) onAppLaunch;
- (void)onRemoteNotification:(NSDictionary *)userInfo;
- (void)onAppDidBecomeActive;
- (void)onAppWillResignActive;
- (BOOL) handleURL: (NSURL*) url fromSourceApplication: (NSString*) sourceApplication;
@end