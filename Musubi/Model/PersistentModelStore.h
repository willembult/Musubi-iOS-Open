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
//  PersistentModelStore.h
//  Musubi
//
//  Created by Willem Bult on 2/29/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "MIdentity.h"
#import "MDevice.h"
#import "MEncodedMessage.h"
#import "MIncomingSecret.h"
#import "MOutgoingSecret.h"

@interface PersistentModelStore : NSObject {
    NSManagedObjectContext* context;
}

@property (nonatomic,retain) NSManagedObjectContext* context;

- (id) initWithCoordinator: (NSPersistentStoreCoordinator*) coordinator;

- (NSArray*) query: (NSPredicate*) predicate onEntity: (NSString*) entityName;
- (NSManagedObject*) queryFirst: (NSPredicate*) predicate onEntity: (NSString*) entityName;
- (NSManagedObject *)createEntity: (NSString*) entityName;

- (NSArray*) unsentOutboundMessages;

- (MIdentity*) createIdentity;
- (MDevice*) createDevice;
- (MEncodedMessage*) createEncodedMessage;
- (MIncomingSecret*) createIncomingSecret;
- (MOutgoingSecret*) createOutgoingSecret;



+ (NSURL*) pathForStoreWithName: (NSString*) name;
+ (NSPersistentStoreCoordinator*) coordinatorWithName: (NSString*) name;

@end
