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
//  MIncomingSecret.h
//  musubi
//
//  Created by MokaFive User on 5/27/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class MDevice, MIdentity;

@interface MIncomingSecret : NSManagedObject

@property (nonatomic, retain) NSData * encryptedKey;
@property (nonatomic) int64_t encryptionPeriod;
@property (nonatomic, retain) NSData * key;
@property (nonatomic, retain) NSData * signature;
@property (nonatomic) int64_t signaturePeriod;
@property (nonatomic, retain) MDevice *device;
@property (nonatomic, retain) MIdentity *myIdentity;
@property (nonatomic, retain) MIdentity *otherIdentity;

@end