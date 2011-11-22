//
//  URLCommand.m
//  musubi
//
//  Created by Willem Bult on 11/18/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "URLCommand.h"

@implementation URLFeedCommand

@synthesize url, className, methodName, parameters, feed;

+ (id)createFromURL:(NSURL *)url withFeed:(Feed*) feed {
    NSArray* hostComponents = [[url host] componentsSeparatedByString:@"."];
    NSString* className = [NSString stringWithFormat:@"%@Command", [[hostComponents objectAtIndex:0] capitalizedString]];
    NSString* methodName = [NSString stringWithFormat:@"%@WithParams:", [hostComponents objectAtIndex:1]];
    
    NSLog(@"Creating %@:%@", className, methodName);
    
    URLFeedCommand* cmd = [[NSClassFromString(className) alloc] init];
    if (!cmd) {
        NSLog(@"ERROR: Command class '%@' not defined", className);
        return nil;
    }

    if (! [cmd isKindOfClass:[URLFeedCommand class]] ) {
        NSLog(@"ERROR: Command class '%@' is not a URLFeedCommand", className);
        return nil;
    }
    
    if (! [cmd respondsToSelector:NSSelectorFromString(methodName)] ) {
        // There's no method to call, so throw an error.
        NSLog(@"ERROR: Method '%@' not defined in command class '%@'", methodName, className);
        return nil;
    }
    
    
    NSMutableDictionary* params = [url queryComponents];
    [cmd setParameters:params];
    [cmd setMethodName:methodName];
    [cmd setFeed:feed];
    
    return cmd;
}

- (NSString*) execute {
    id res = [self performSelector:NSSelectorFromString([self methodName]) withObject:[self parameters]];
    return res;
}

@end

@implementation FeedCommand

- (id) messagesWithParams:(NSDictionary *)params {
    ManagedFeed* mgdFeed = [[Musubi sharedInstance] feedByName: [params objectForKey:@"feedName"]];
    
    NSMutableArray* msgs = [NSMutableArray array];
    for (ManagedMessage* msg in [mgdFeed allMessages]) {
        [msgs addObject:[[msg message] json]];
    }
    
    return msgs;
}

- (id) postWithParams:(NSDictionary *)params {
    SBJsonParser* parser = [[SBJsonParser alloc] init];
    NSDictionary* json = [parser objectWithString:[params objectForKey:@"obj"]];
    
    Obj* obj = [[Obj alloc] init];
    [obj setType:[json objectForKey:@"type"]];
    [obj setData:[json objectForKey:@"data"]];
    
    [[Musubi sharedInstance] sendObj:obj forApp:kMusubiAppId toGroup:feed];
    
    return nil;
}

@end