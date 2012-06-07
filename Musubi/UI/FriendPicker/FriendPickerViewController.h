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
//  FriendPickerController.h
//  musubi
//
//  Created by Willem Bult on 6/4/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "Three20/Three20.h"

@protocol FriendPickerViewControllerDelegate

@end


@interface FriendPickerTableViewDelegate : TTTableViewVarHeightDelegate
@end

@interface FriendPickerViewController : TTTableViewController<TTPickerTextFieldDelegate,TTTableViewDataSource> {
    id<FriendPickerViewControllerDelegate> _delegate;
    TTPickerTextField* _pickerTextField;
    
    UILabel* _importingLabel;
    NSMutableDictionary* _remainingImports;
}

@property (nonatomic,retain) id<FriendPickerViewControllerDelegate> delegate;
@property (nonatomic,readonly) TTPickerTextField* pickerTextField;
@property (nonatomic,retain) NSMutableArray* pinnedIdentities;

@end
