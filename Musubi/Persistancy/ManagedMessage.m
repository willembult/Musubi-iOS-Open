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
//  Message.m
//  musubi
//
//  Created by Willem Bult on 10/25/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ManagedMessage.h"
#import "ManagedFeed.h"
#import "SignedMessage.h"
#import "Obj.h"

@implementation ManagedMessage

@dynamic contents;
@dynamic sender;
@dynamic timestamp;
@dynamic app;
@dynamic feed;
@dynamic type;
@dynamic parent;
@dynamic id;
/*
- (SignedMessage*) message {
    
    NSPropertyListFormat format;
    NSString *errorStr = nil;
    
    NSDictionary* dict = [NSPropertyListSerialization propertyListFromData:[self contents] mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&errorStr];
    
    Obj* obj = [[[Obj alloc] initWithType:[self type]] autorelease];
    [obj setData: dict];
    
    SignedMessage* msg = [[[SignedMessage alloc] init] autorelease];
    [msg setAppId: [self app]];
    [msg setFeedName: [[self feed] session]];
    [msg setTimestamp: [self timestamp]];
    [msg setSender: [[self sender] user]];
    [msg setHash: [self id]];
    [msg setObj:obj];
    [msg setParentHash:[self parent]];
    
    return msg;
}*/

/*
- (NSArray*) childMessages {
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Message" inManagedObjectContext:[self managedObjectContext]];
    
    NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
    [request setEntity:entity];
    [request setPredicate:[NSPredicate predicateWithFormat:@"parent = %@", [self id]]];
    
    NSError *error = nil;
    return [[self managedObjectContext] executeFetchRequest:request error:&error];
}*/



@end
