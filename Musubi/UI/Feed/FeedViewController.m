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
//  FeedViewController.m
//  musubi
//
//  Created by Willem Bult on 5/23/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "FeedViewController.h"
#import "ProfileViewController.h"
#import "FriendPickerTableViewController.h"
#import "FeedDataSource.h"
#import "FeedModel.h"
#import "FeedItem.h"
#import "Musubi.h"
#import "PersistentModelStore.h"
#import "APNPushManager.h"

#import "FeedManager.h"
#import "MFeed.h"
#import "MIdentity.h"
#import "ObjHelper.h"
#import "LikeObj.h"
#import "PictureObj.h"
#import "StatusObj.h"
#import "FeedNameObj.h"
#import "IntroductionObj.h"

#import "AppManager.h"
#import "MApp.h"


@implementation FeedViewController

@synthesize newerThan = _newerThan;
@synthesize startingAt = _startingAt;
@synthesize feed = _feed;
@synthesize delegate = _delegate;

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        // TTTableViewController doesn't implement initWithCoder: so do the required init here
        _lastInterfaceOrientation = self.interfaceOrientation;
        _tableViewStyle = UITableViewStylePlain;
        _clearsSelectionOnViewWillAppear = YES;
        _flags.isViewInvalid = YES;
    }
    return self;
}

- (void)loadView {
    [super loadView];
    FeedManager* feedManager = [[FeedManager alloc] initWithStore:[Musubi sharedInstance].mainStore];
    self.title = [feedManager identityStringForFeed: _feed];
    
    CGRect bounds = CGRectMake(self.view.bounds.origin.x, self.view.bounds.origin.y, self.view.bounds.size.width, self.view.bounds.size.height - 50);
    self.tableView.frame = bounds;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.variableHeightRows = YES;
    
    updateField.delegate = self;

    UIButton* button = [UIButton buttonWithType:UIButtonTypeInfoLight];
    button.frame = CGRectMake(0, 0, 120, 32);
    [button setTitle:self.title forState:UIControlStateNormal];
    button.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [button addTarget:self action:@selector(changeName) forControlEvents:UIControlEventTouchDown];
    self.navigationItem.titleView = button;
}
- (void)changeName
{
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Conversation Name" message:@"Set a name for this feed so everyone can find it better" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert show];
    
}
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex != 1)
        return;
    NSString* name = [alertView textFieldAtIndex:0].text;
    name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if(!name || !name.length)
        return;
            
    FeedNameObj* name_change = [[FeedNameObj alloc] initWithName:name];
    
    AppManager* am = [[AppManager alloc] initWithStore:[Musubi sharedInstance].mainStore];
    MApp* app = [am ensureSuperApp];
    
    [ObjHelper sendObj:name_change toFeed:_feed fromApp:app usingStore:[Musubi sharedInstance].mainStore];
    [(UIButton*)self.navigationItem.titleView setTitle:name forState:UIControlStateNormal];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Cardinal
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:164.0/256.0 green:0 blue:29.0/256.0 alpha:1];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidHide:) name:UIKeyboardDidHideNotification object:nil];
    [[Musubi sharedInstance].notificationCenter addObserver:self selector:@selector(feedUpdated:) name:kMusubiNotificationUpdatedFeed object:nil];

    if(!_startingAt) {
        [self scrollToBottomAnimated:NO];
    }
    [self resetUnreadCount];    
}

- (void)viewWillDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidShowNotification object:nil];
    [[Musubi sharedInstance].notificationCenter removeObserver:self name:kMusubiNotificationUpdatedFeed object:nil];
}

- (void)createModel {
    self.dataSource = [[FeedDataSource alloc] initWithFeed:_feed  messagesNewerThan:_newerThan startingAt:_startingAt];
}

- (id<UITableViewDelegate>)createDelegate {
    return [[FeedViewTableDelegate alloc] initWithController:self];
}

- (BOOL)shouldLoadMore {
    return [(FeedModel*)self.model hasMore];
}

- (void) scrollToBottomAnimated: (BOOL) animated {
    FeedDataSource* source = (FeedDataSource*)self.dataSource;
    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:(source.items.count - 1) inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:animated];
}

- (void) feedUpdated: (NSNotification*) notification {    
    if (![NSThread currentThread].isMainThread) {
        [self performSelectorOnMainThread:@selector(feedUpdated:) withObject:notification waitUntilDone:NO];
        return;
    }
    
    if ([((NSManagedObjectID*)notification.object) isEqual:_feed.objectID]) {
        [self refreshFeed];
    }
}


- (void) refreshFeed {
    FeedModel* model = (FeedModel*)self.model;
    CGPoint old = self.tableView.contentOffset;
    BOOL last = [self isLastRowVisible];
    [model loadNew];
    if(last)
        [self scrollToBottomAnimated:NO];
    else
        self.tableView.contentOffset = old;
    [self resetUnreadCount];
}
- (BOOL)isLastRowVisible
{
    FeedDataSource* source = (FeedDataSource*)self.dataSource;
    return (source.items.count - 1 == [self lastVisibleRow]);
}

- (int)lastVisibleRow
{
    int row = -1;
    NSArray* visible = self.tableView.indexPathsForVisibleRows;
    for(NSIndexPath* i in visible) {
        if(i.row > row)
            row = i.row;
    }
    NSLog(@"index %d", row);
    return row;
}


- (void) resetUnreadCount {
    if (_feed.numUnread > 0) {
        [_feed setNumUnread:0];
        [[Musubi sharedInstance].mainStore save];
        [APNPushManager resetLocalUnreadInBackgroundTask:NO];
        
        // Refresh the feed list view
        [[Musubi sharedInstance].notificationCenter postNotificationName:kMusubiNotificationUpdatedFeed object:nil];
    }
}

/// ACTIONS

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    /*
    NSString *output = [webView stringByEvaluatingJavaScriptFromString:@"document.body.scrollHeight"];
    NSNumber* height = [NSNumber numberWithInt:[output intValue]];
    [cellHeights setObject:height forKey:[NSNumber numberWithInteger:[webView tag]]];
    
    CGRect frame = [webView frame];
    [webView setFrame:CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, [height floatValue])];
    
    [self.tableView beginUpdates];
    [self.tableView setNeedsLayout];
    [self.tableView endUpdates];*/
}

- (void) keyboardDidShow:(NSNotification*)notification {
    CGRect keyboardFrame = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    UIWindow *window = [[[UIApplication sharedApplication] windows]objectAtIndex:0];
    UIView *mainSubviewOfWindow = window.rootViewController.view;
    CGRect keyboardFrameConverted = [mainSubviewOfWindow convertRect:keyboardFrame fromView:window];

    [postView setFrame:CGRectMake(0, postView.frame.origin.y - keyboardFrameConverted.size.height, postView.frame.size.width, postView.frame.size.height)];
    [self.tableView setFrame: CGRectMake(0, 0, self.tableView.frame.size.width, self.tableView.frame.size.height - keyboardFrameConverted.size.height)];
    
    [self scrollToBottomAnimated:NO];
}
- (void) keyboardDidHide:(NSNotification*)notification {
    [postView setFrame:CGRectMake(0, self.view.frame.size.height - postView.frame.size.height, postView.frame.size.width, postView.frame.size.height)];
    [self.tableView setFrame: CGRectMake(0, 0, self.tableView.frame.size.width, postView.frame.origin.y)];
}
- (void) hideKeyboard {
    
    [updateField resignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    //[self hideKeyboard];
    
    if ([textField text].length > 0) {
        StatusObj* status = [[StatusObj alloc] initWithText: [textField text]];
        
        AppManager* am = [[AppManager alloc] initWithStore:[Musubi sharedInstance].mainStore];
        MApp* app = [am ensureSuperApp];
        
        [ObjHelper sendObj:status toFeed:_feed fromApp:app usingStore:[Musubi sharedInstance].mainStore];
        
        [textField setText:@""];
        [self refreshFeed];
    }

    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    [self hideKeyboard];
}

- (IBAction)commandButtonPushed: (id) sender {
    UIActionSheet* commandPicker = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Take Picture", @"Picture From Album", nil];
    
    [commandPicker showInView:mainView];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex{

    switch (buttonIndex) {
        case 0: // take picture
        {
            UIImagePickerController* picker = [[UIImagePickerController alloc] init];
            [picker setSourceType:UIImagePickerControllerSourceTypeCamera];
            [picker setDelegate:self];
            
            [self presentModalViewController:picker animated:YES];
            break;
        }
        case 1: // existing picture
        {   
            UIImagePickerController* picker = [[UIImagePickerController alloc] init];
            [picker setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
            [picker setDelegate:self];            
            
            [self presentModalViewController:picker animated:YES];
            break;
        }
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo {
    
    PictureObj* pic = [[PictureObj alloc] initWithImage: image];
    
    AppManager* am = [[AppManager alloc] initWithStore:[Musubi sharedInstance].mainStore];
    MApp* app = [am ensureSuperApp];
    
    [ObjHelper sendObj:pic toFeed:_feed fromApp:app usingStore:[Musubi sharedInstance].mainStore];
    
    [[self modalViewController] dismissModalViewControllerAnimated:YES];
    [self refreshFeed];  
}


- (void)friendsSelected:(NSArray *)selection {
    PersistentModelStore* store = [Musubi sharedInstance].mainStore;

    if (selection.count == 0) {
        return;
    }

    FeedManager* fm = [[FeedManager alloc] initWithStore:store];
    AppManager* am = [[AppManager alloc] initWithStore:store];
    MApp* app = [am ensureSuperApp];
    
    //add members to feed
    [fm attachMembers:selection toFeed:_feed];
    //send an introduction
    Obj* invitationObj = [[IntroductionObj alloc] initWithIdentities:selection];
    [ObjHelper sendObj: invitationObj toFeed:_feed fromApp:app usingStore: store];
    
    [self.navigationController popViewControllerAnimated:NO]; // back to the feed
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"AddPeopleSegue"]) {
        FriendPickerTableViewController *vc = segue.destinationViewController;
        FeedManager* fm = [[FeedManager alloc] initWithStore:[Musubi sharedInstance].mainStore];
        vc.pinnedIdentities = [NSSet setWithArray:[fm identitiesInFeed:_feed]];
        vc.delegate = self;
    }
    else if ([[segue identifier] isEqualToString:@"ShowProfile"]) {
        ProfileViewController *vc = [segue destinationViewController];
        [vc setIdentity: (MIdentity*) sender];
        [vc setDelegate:self];
        //[vc.view addSubview:incomingLabel];
        //[self updatePending:nil];
    }
}

- (void)selectedFeed:(MFeed *)feed {
    [self setFeed:feed];
    [self invalidateModel];
    [self createModel];
    [self reload];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)newConversation:(MIdentity*) ident {
    [self.navigationController popViewControllerAnimated:NO];
    NSArray* selection = [NSArray arrayWithObject:ident];
    [_delegate friendsSelected:selection];
}

- (void)viewDidUnload {
    [super viewDidUnload];
}
@end



@implementation FeedViewTableDelegate

- (void)likedAtIndexPath:(NSIndexPath *)indexPath {
    FeedItem* item = [self.controller.dataSource tableView:self.controller.tableView objectForRowAtIndexPath:indexPath];
    
    if (!item.iLiked) {
        LikeObj* like = [[LikeObj alloc] initWithObjHash: item.obj.universalHash];
                
        AppManager* am = [[AppManager alloc] initWithStore:[Musubi sharedInstance].mainStore];
        MApp* app = [am ensureSuperApp];
        
        FeedViewController* controller = (FeedViewController*) self.controller;
        
        MObj* mObj = [ObjHelper sendObj:like toFeed:controller.feed fromApp:app usingStore:[Musubi sharedInstance].mainStore];
        [like processObjWithRecord: mObj];
        
        [(FeedModel*)self.controller.model loadObj:item.obj.objectID];
    }
}

- (void)profilePictureButtonPressedAtIndexPath:(NSIndexPath *)indexPath {
    FeedViewController* controller = (FeedViewController*) self.controller;
    
    FeedItem* item = [self.controller.dataSource tableView:self.controller.tableView objectForRowAtIndexPath:indexPath];
    [controller performSegueWithIdentifier:@"ShowProfile" sender:item.obj.identity];
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [(FeedViewController*)self.controller hideKeyboard];
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
    if (indexPath.row == 0 && [cell isKindOfClass:[TTTableMoreButtonCell class]]) {
        TTTableMoreButton* moreLink = [(TTTableMoreButtonCell *)cell object];
        moreLink.isLoading = YES;
        [(TTTableMoreButtonCell *)cell setAnimating:YES];
    };
    
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}


/*- (void)didSelectObject:(id)object atIndexPath:(NSIndexPath *)indexPath {
    MFeed* feed = [((FeedListDataSource*)self.dataSource) feedForIndex:indexPath.row];
    [self performSegueWithIdentifier:@"ShowFeedCustom" sender:feed];
}*/

@end