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
//  AppDelegate.m
//  musubi
//
//  Created by Willem Bult on 10/5/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"
#import "Musubi.h"
#import "NSData+HexString.h"
#import <DropboxSDK/DropboxSDK.h>

#import "FacebookIdentityUpdater.h"
#import "GoogleIdentityUpdater.h"
#import "FacebookAuth.h"
#import "GoogleAuth.h"

#import "MusubiShareKitConfigurator.h"
#import "SHKConfiguration.h"
#import "SHKFacebook.h"
#import "SHK.h"
#import "MusubiAnalytics.h"
#import "ObjRegistry.h"

#import "Three20/Three20.h"
#import "MusubiStyleSheet.h"
#import "SettingsViewController.h"

#import "IdentityManager.h"
#import "FeedListViewController.h"
#import "PictureObj.h"
#import "NSData+Base64.h"
#import "DejalActivityView.h"

static const NSInteger kGANDispatchPeriodSec = 60;

@implementation AppDelegate

@synthesize window = _window, navController;
@synthesize facebookIdentityUpdater, googleIdentityUpdater, facebookLoginOperation;

NSDictionary *objJson;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [ObjRegistry registerObjs];
    [[Musubi sharedInstance] onAppLaunch];
    
    [TTStyleSheet setGlobalStyleSheet:[[MusubiStyleSheet alloc] init]];

    //    [self setFacebook: [[[Facebook alloc] initWithAppId:kFacebookAppId andDelegate:self] autorelease]];
    //[TestFlight takeOff:@"xxx"];

    [self prepareAnalytics];

    NSDate* showUIDate = [NSDate dateWithTimeIntervalSinceNow:1];
        
    DBSession* dbSession = [[DBSession alloc] initWithAppKey:@"" appSecret:@"" root:kDBRootAppFolder];
    [DBSession setSharedSession:dbSession];
    
    
    MusubiShareKitConfigurator *configurator = [[MusubiShareKitConfigurator alloc] init];
    [SHKConfiguration sharedInstanceWithConfigurator:configurator];
    [SHK flushOfflineQueue];

    
    self.facebookIdentityUpdater = [[FacebookIdentityUpdater alloc] initWithStoreFactory: [Musubi sharedInstance].storeFactory];
    [[NSRunLoop mainRunLoop] addTimer:[NSTimer timerWithTimeInterval:kFacebookIdentityUpdaterFrequency target:self.facebookIdentityUpdater selector:@selector(refreshFriendsIfNeeded) userInfo:nil repeats:YES] forMode:NSDefaultRunLoopMode];
    
    self.googleIdentityUpdater = [[GoogleIdentityUpdater alloc] initWithStoreFactory: [Musubi sharedInstance].storeFactory];
    [[NSRunLoop mainRunLoop] addTimer:[NSTimer timerWithTimeInterval:kGoogleIdentityUpdaterFrequency target:self.googleIdentityUpdater selector:@selector(refreshFriendsIfNeeded) userInfo:nil repeats:YES] forMode:NSDefaultRunLoopMode];
    
    [self registerAuthProviders];
    
    return YES;
}

- (void) registerAuthProviders {
    if (![Musubi sharedInstance].identityProvider) {
        [self performSelector:@selector(registerAuthProviders) withObject:self afterDelay:.5];
        return;
    }
    /*
    [[Musubi sharedInstance].identityProvider registerProvider:[[EmailAphidAuthProvider alloc] init]];
    [[Musubi sharedInstance].identityProvider registerProvider:[[FacebookAphidAuthProvider alloc] init]];
    [[Musubi sharedInstance].identityProvider registerProvider:[[GoogleAphidAuthProvider alloc] init]];*/
}

- (void) prepareAnalytics {
    [[GANTracker sharedTracker] startTrackerWithAccountID:@""
                                           dispatchPeriod:kGANDispatchPeriodSec
                                                 delegate:nil];
    
    NSError *error;
    if (![[GANTracker sharedTracker] setCustomVariableAtIndex:1
                                                         name:@"iPhone1"
                                                        value:@"iv1"
                                                    withError:&error]) {
        // Handle error here
    }

    if (![[GANTracker sharedTracker] trackPageview:kAnalyticsPageAppEntryPoint
                                         withError:&error]) {
        // Handle error here
    }
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    [[Musubi sharedInstance] onRemoteNotification: userInfo];
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {     
    NSLog(@"Error in registration. Error: %@", err);
}    

- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {          
    [Musubi sharedInstance].apnDeviceToken = [deviceToken hexString];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [[Musubi sharedInstance] onAppDidBecomeActive];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    [[Musubi sharedInstance] onAppWillResignActive];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}

-(void)restart
{
    NSLog(@"Restarting UI");
    UIStoryboard *storyboard;
    if ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)) {
        storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard_iPhone" bundle:nil];
    }
    else {
        storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard_iPad" bundle:nil];
    }
    UIViewController* vc = [storyboard instantiateInitialViewController];
    [self.window setRootViewController:vc];
}

// For iOS 4.2+ support
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    
    NSString* facebookPrefix = [NSString stringWithFormat:@"fb%@", SHKCONFIG(facebookAppId)];
    if ([url.scheme hasPrefix:facebookPrefix]) {
        BOOL shk, fb;
        shk = [SHKFacebook handleOpenURL:url];
        fb = [facebookLoginOperation handleOpenURL:url];
        
        return shk && fb;
    }
    
    if ([[DBSession sharedSession] handleOpenURL:url]) {
        [((SettingsViewController*) self.window.rootViewController.childViewControllers.lastObject).tableView reloadData];
        [((SettingsViewController*) self.window.rootViewController.childViewControllers.lastObject).tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:2]] withRowAnimation:UITableViewRowAnimationNone];
        [((SettingsViewController*) self.window.rootViewController.childViewControllers.lastObject).tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:2 inSection:2]] withRowAnimation:UITableViewRowAnimationNone];
        return YES;
    }

    if ([url.scheme hasPrefix:kMusubiUriScheme]) {
        if ([url.path hasPrefix:@"/intro/"]) {
            // n, t, p
            NSArray *components = [[url query] componentsSeparatedByString:@"&"];
            NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
            for (NSString *component in components) {
                [parameters setObject:[[component componentsSeparatedByString:@"="] objectAtIndex:0] forKey:[[component componentsSeparatedByString:@"="] objectAtIndex:1]];
            }
            NSString *idName = [parameters objectForKey:@"n"];
            NSString *idTypeString = [parameters objectForKey:@"t"];
            NSString *idValue = [parameters objectForKey:@"p"];

            if (idValue != nil && idTypeString != nil) {
                int idType = [idTypeString intValue];
                if (idName == nil) {
                    idName = idValue;
                }

                BOOL identityAdded = NO;
                BOOL profileDataChanged = NO;
                IdentityManager* im = [[IdentityManager alloc] initWithStore:[Musubi sharedInstance].mainStore];
                [im ensureIdentityWithType:idType andPrincipal:idValue andName:idName identityAdded:&identityAdded profileDataChanged:&profileDataChanged];
            }

            return YES;
        } else if ([url.host isEqualToString:@"share"]) {
            [self shareObjFromUrl:url];
            return YES;
        }
    }
    return [[Musubi sharedInstance] handleURL:url fromSourceApplication:sourceApplication];
}

- (void) shareObjFromUrl: (NSURL *) url {
    NSString *encodedString = [url.path substringFromIndex:1];
    NSString *jsonString = [encodedString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    objJson = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    
    UIAlertView* alert;
    if (objJson != nil) {
        alert = [[UIAlertView alloc] initWithTitle:@"Sharing data" message:@"Click 'Okay' and choose a conversation for sharing, or click cancel to discard the data." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Okay", nil];
    } else {
        alert = [[UIAlertView alloc] initWithTitle:@"Error sharing data" message:@"Error sharing data." delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles: nil];
        NSLog(@"Error sharing data %@", jsonString);
    }
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView
clickedButtonAtIndex:(NSInteger)buttonIndex{
    if (buttonIndex == 1) {
        NSString *type = [objJson objectForKey:@"type"];
        NSDictionary* json = [objJson objectForKey:@"json"];
        if ([type isEqualToString:@"picture"]) {
            NSString *imgUrlString = [json objectForKey:@"src"];
            NSString *imgTitle = [json objectForKey:kTextField];
            NSString *imgCallback = [json objectForKey:kFieldCallback];
            NSURL *imgUrl = [NSURL URLWithString:imgUrlString];
            if (imgUrl != nil) {
                dispatch_async(dispatch_get_current_queue(), ^{
                    UINavigationController* nav = (UINavigationController*)self.window.rootViewController;
                    [DejalBezelActivityView activityViewForView:nav.view withLabel:@"Preparing data..." width:200];

                    UIImage *image = [UIImage imageWithData: [NSData dataWithContentsOfURL:imgUrl]];
                    Obj* obj = [[PictureObj alloc] initWithImage:image andText:imgTitle andCallback:imgCallback];
                    [DejalBezelActivityView removeViewAnimated:YES];
                    
                    [nav popToRootViewControllerAnimated:YES];
                    FeedListViewController *feedList = (FeedListViewController*) nav.topViewController;
                    [feedList setClipboardObj: obj];
                });
            } else {
                UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Error sharing data" message:@"Image data not found." delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:nil];
                [alert show];
            }
        } else {
            UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Error sharing data" message:@"Unsupported data type." delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:nil];
            [alert show];
        }
    }
    objJson = nil;
}

@end

@implementation NonAnimatedSegue

//@synthesize appDelegate = _appDelegate;

-(void) perform{
    [[[self sourceViewController] navigationController] pushViewController:[self destinationViewController] animated:NO];
}
@end
