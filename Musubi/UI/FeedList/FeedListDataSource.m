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
//  FeedListDataSource.m
//  musubi
//
//  Created by Willem Bult on 5/30/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "FeedListDataSource.h"
#import "MFeed.h"
#import "FeedManager.h"
#import "FeedListModel.h"
#import "FeedListItem.h"
#import "FeedListItemCell.h"
#import "Musubi.h"
#import "NSDate+LocalTime.h"
#import "ObjManager.h"

@implementation DateRange
@synthesize start, end;
- (DateRange*)initWithStart:(NSDate*)after andEnd:(NSDate*)before
{
    self = [super init];
    if(!self)
        return nil;
    start = after;
    end = before;
    return self;
}
@end


@implementation FeedListDataSource
@synthesize dateRanges, lastDraw, lastItems, lastSections;
- (id) init {
    self = [super init];
    if (self) {
        self.model = [[FeedListModel alloc] init];
        _feedManager = [[FeedManager alloc] initWithStore:[Musubi sharedInstance].mainStore];
        _objManager = [[ObjManager alloc] initWithStore:[Musubi sharedInstance].mainStore];
    }
    return self;
}


- (void)tableViewDidLoadModel:(UITableView *)tableView {
    NSDate *today = [NSDate date];
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSUInteger unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit;
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components = [gregorian components:unitFlags fromDate:today];
    components.hour = 0;
    components.minute = 0;
    components.second = 0;
    NSMutableArray* lastDateRanges = dateRanges;
    if(self.lastDraw) {
        NSDateComponents *components2 = [[NSDateComponents alloc] init];
        components2 = [gregorian components:unitFlags fromDate:self.lastDraw];
        components2.hour = 0;
        components2.minute = 0;
        components2.second = 0;
        if(![[gregorian dateFromComponents:components] isEqualToDate:[gregorian dateFromComponents:components2]]) {
            self.lastItems = nil;
            self.lastSections = nil;
        }
    }
    self.lastDraw = [NSDate date];

    NSMutableArray* sections = [NSMutableArray array];
    NSMutableArray* section_items = [NSMutableArray arrayWithCapacity:self.sections.count];
    NSMutableArray* ends = [NSMutableArray arrayWithCapacity:self.sections.count];
    
    NSDate *todayMidnight = [gregorian dateFromComponents:components];
    NSDate *other;

    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"EEEE";
    
    [sections addObject:@"Today"];
    [ends addObject:todayMidnight];
    if(!self.lastItems || !self.lastSections) {
        components = [[NSDateComponents alloc] init];
        components.day = -1;
        other = [gregorian dateByAddingComponents:components toDate:todayMidnight options:0];
        [sections addObject:@"Yesterday"];
        [ends addObject:other];
        components.day = -2;
        other = [gregorian dateByAddingComponents:components toDate:todayMidnight options:0];
        [sections addObject:[df stringFromDate:other]];
        [ends addObject:other];
        components.day = -3;
        other = [gregorian dateByAddingComponents:components toDate:todayMidnight options:0];
        [sections addObject:[df stringFromDate:other]];
        [ends addObject:other];
        components.day = -4;
        other = [gregorian dateByAddingComponents:components toDate:todayMidnight options:0];
        [sections addObject:[df stringFromDate:other]];
        [ends addObject:other];
        components.day = -5;
        other = [gregorian dateByAddingComponents:components toDate:todayMidnight options:0];
        [sections addObject:[df stringFromDate:other]];
        [ends addObject:other];
        components.day = -6;
        other = [gregorian dateByAddingComponents:components toDate:todayMidnight options:0];
        [sections addObject:@"A Week Ago"];
        [ends addObject:other];
        components.day = -7;
        other = [gregorian dateByAddingComponents:components toDate:todayMidnight options:0];
        [sections addObject:@"Two Weeks Ago"];
        [ends addObject:other];
        components.day = -14;
        other = [gregorian dateByAddingComponents:components toDate:todayMidnight options:0];
        [sections addObject:@"A Month Ago"];
        [ends addObject:other];
        components = [[NSDateComponents alloc] init];
        components.day = -30;
        other = [gregorian dateByAddingComponents:components toDate:todayMidnight options:0];
        [sections addObject:@"All Time"];
        [ends addObject:other];
    }
    NSDate* start = nil;
    for(NSDate* end in ends) {
        [section_items addObject:[self filterFeeds:((FeedListModel*)self.model).results withActivityAfter:start until:end]];
        [dateRanges addObject:[[DateRange alloc] initWithStart:start andEnd:end]];
        start = end;
    }
    [section_items addObject:[self filterFeeds:((FeedListModel*)self.model).results withActivityAfter:start until:nil]];

    for(int i = sections.count - 1; i >= 0; --i) {
        if(![[section_items objectAtIndex:i] count]) {
            [sections removeObjectAtIndex:i];
            [dateRanges removeObjectAtIndex:i];
            [section_items removeObjectAtIndex:i];
        }
    }
    
    if(self.lastItems && self.lastSections) {
        if(!sections.count) {
            //no items in today
        } else {
            if(!lastDateRanges.count || [(DateRange*)[lastDateRanges objectAtIndex:0] start]) {
                // there was no today section before
                [self.lastItems insertObject:[section_items objectAtIndex:0] atIndex:0];
            } else {
                // update the today section
                [self.lastItems replaceObjectAtIndex:0 withObject:[section_items objectAtIndex:0]];
            }
        }
        
    } else {
        self.lastItems = section_items;
        self.lastSections = sections;
        self.sections = sections;
        self.items = section_items;
    }
}
- (NSMutableArray*) filterFeeds:(NSMutableArray*)newItems withActivityAfter:(NSDate*)start until:(NSDate*)end
{
    NSMutableArray* hits = [NSMutableArray arrayWithCapacity:newItems.count];
    for(MFeed* feed in newItems) {
        if(![_objManager feed:feed withActivityAfter:start until:end])
            continue;
        FeedListItem* item = [[FeedListItem alloc] initWithFeed:feed after:start before:end];
        if (item) {
            [hits addObject: item];
        }
    }
    return hits;
}
- (Class)tableView:(UITableView *)tableView cellClassForObject:(id)object {
    return [FeedListItemCell class];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) { 
        FeedListItem* item = [self.items objectAtIndex:indexPath.row];
        [_feedManager deleteFeedAndMembersAndObjs:item.feed];

        [tableView beginUpdates];
        [self.items removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObjects:indexPath,nil] withRowAnimation:UITableViewRowAnimationFade];
        [tableView endUpdates];
    } 
}


@end
