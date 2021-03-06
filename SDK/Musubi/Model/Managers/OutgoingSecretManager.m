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
//  OutgoingSecretManager.m
//  Musubi
//
//  Created by Willem Bult on 3/15/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "OutgoingSecretManager.h"
#import "MOutgoingSecret.h"

@implementation OutgoingSecretManager

- (id)initWithStore:(PersistentModelStore *)s {
    self = [super initWithEntityName:@"OutgoingSecret" andStore:s];
    if (self != nil) {
    }
    return self;
}

- (MOutgoingSecret *)outgoingSecretFrom:(MIdentity *)from to:(MIdentity *)to myTemporalFrame:(uint64_t)tfMe theirTemporalFrame:(uint64_t)tfThem {
    NSArray* results = [self query:[NSPredicate predicateWithFormat:@"myIdentity = %@ AND otherIdentity = %@ AND encryptionPeriod = %llu AND signaturePeriod = %llu", from, to, tfMe, tfThem]];
    if (results.count > 0) {
        return (MOutgoingSecret*)[results objectAtIndex:0];
    }
    return nil;
}
@end
