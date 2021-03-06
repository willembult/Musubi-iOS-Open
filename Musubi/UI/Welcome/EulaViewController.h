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
//  EULAViewController.h
//  musubi
//
//  Created by Ben Dodson on 7/20/12.
//  Copyright (c) 2012 Stanford University. All rights reserved.
//

#import <UIKit/UIKit.h>

#define kMusubiSettingsEulaAccepted @"EulaVersionAccepted"
#define kEulaRequiredVersion -1

@interface EulaViewController : UIViewController

@property (nonatomic) IBOutlet UITextView* eulaText;
@property (nonatomic) IBOutlet UIBarButtonItem* acceptButton;
@property (nonatomic) IBOutlet UIBarButtonItem* declineButton;
@property (nonatomic) IBOutlet UIToolbar* bottomBar;

@end
