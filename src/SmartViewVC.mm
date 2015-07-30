/*
 *  Copyright (C) 2015 Savoir-faire Linux Inc.
 *  Author: Alexandre Lision <alexandre.lision@savoirfairelinux.com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 *
 *  Additional permission under GNU GPL version 3 section 7:
 *
 *  If you modify this program, or any covered work, by linking or
 *  combining it with the OpenSSL project's OpenSSL library (or a
 *  modified version of that library), containing parts covered by the
 *  terms of the OpenSSL or SSLeay licenses, Savoir-Faire Linux Inc.
 *  grants you additional permission to convey the resulting work.
 *  Corresponding Source for a non-source form of such a combination
 *  shall include the source code for the parts of OpenSSL used as well
 *  as that of the covered work.
 */

#import "SmartViewVC.h"

//LRC
#import <recentmodel.h>
#import <callmodel.h>
#import <call.h>
#import <contactmethod.h>

#import "QNSTreeController.h"

#define COLUMNID_MAIN @"MainColumn"	// the single column name in our outline view


@interface SmartViewVC () <NSOutlineViewDelegate>

@property (unsafe_unretained) IBOutlet NSOutlineView *smartView;
@property (unsafe_unretained) IBOutlet NSSearchField *searchField;
@property QNSTreeController *treeController;

@end

@implementation SmartViewVC
@synthesize smartView;
@synthesize treeController;

- (void)awakeFromNib
{
    NSLog(@"INIT SmartView VC");

    treeController = [[QNSTreeController alloc] initWithQModel:RecentModel::instance()];

    [treeController setAvoidsEmptySelection:NO];
    [treeController setChildrenKeyPath:@"children"];

    [smartView bind:@"content" toObject:treeController withKeyPath:@"arrangedObjects" options:nil];
    [smartView bind:@"sortDescriptors" toObject:treeController withKeyPath:@"sortDescriptors" options:nil];
    [smartView bind:@"selectionIndexPaths" toObject:treeController withKeyPath:@"selectionIndexPaths" options:nil];
    [smartView setTarget:self];
    [smartView setDoubleAction:@selector(placeCall:)];
    NSInteger idx = [smartView columnWithIdentifier:COLUMNID_MAIN];
    [[[[self.smartView tableColumns] objectAtIndex:idx] headerCell] setStringValue:@"Conversations"];
}

- (void)placeCall:(id)sender
{
    if([[treeController selectedNodes] count] > 0) {
        QModelIndex qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
        QVariant var = RecentModel::instance()->data(qIdx, (int)Call::Role::ContactMethod);
        ContactMethod* m = qvariant_cast<ContactMethod*>(var);
        if(m){
            Call* c = CallModel::instance()->dialingCall();
            c->setDialNumber(m);
            c << Call::Action::ACCEPT;
        }
    }
}

#pragma mark - NSOutlineViewDelegate methods

// -------------------------------------------------------------------------------
//	shouldSelectItem:item
// -------------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item;
{
    return YES;
}

// -------------------------------------------------------------------------------
//	dataCellForTableColumn:tableColumn:item
// -------------------------------------------------------------------------------
- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    NSCell *returnCell = [tableColumn dataCell];
    if(item == nil)
        return returnCell;
    return returnCell;
}

// -------------------------------------------------------------------------------
//	textShouldEndEditing:fieldEditor
// -------------------------------------------------------------------------------
- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
    if ([[fieldEditor string] length] == 0)
    {
        // don't allow empty node names
        return NO;
    }
    else
    {
        return YES;
    }
}

// -------------------------------------------------------------------------------
//	shouldEditTableColumn:tableColumn:item
//
//	Decide to allow the edit of the given outline view "item".
// -------------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    return NO;
}

// -------------------------------------------------------------------------------
//	outlineView:willDisplayCell:forTableColumn:item
// -------------------------------------------------------------------------------
- (void)outlineView:(NSOutlineView *)olv willDisplayCell:(NSCell*)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    if ([[tableColumn identifier] isEqualToString:COLUMNID_MAIN])
    {
        QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
        if(qIdx.isValid())
            cell.title = RecentModel::instance()->data(qIdx, Qt::DisplayRole).toString().toNSString();
    }
}

// -------------------------------------------------------------------------------
//	outlineViewSelectionDidChange:notification
// -------------------------------------------------------------------------------
- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    // ask the tree controller for the current selection
}


@end
