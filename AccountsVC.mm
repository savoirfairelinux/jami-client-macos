/************************************************************************************
 *   Copyright (C) 2014-2015 by Savoir-Faire Linux                                  *
 *   Author : Alexandre Lision <alexandre.lision@savoirfairelinux.com>              *
 *                                                                                  *
 *   This library is free software; you can redistribute it and/or                  *
 *   modify it under the terms of the GNU Lesser General Public                     *
 *   License as published by the Free Software Foundation; either                   *
 *   version 2.1 of the License, or (at your option) any later version.             *
 *                                                                                  *
 *   This library is distributed in the hope that it will be useful,                *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of                 *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU              *
 *   Lesser General Public License for more details.                                *
 *                                                                                  *
 *   You should have received a copy of the GNU Lesser General Public               *
 *   License along with this library; if not, write to the Free Software            *
 *   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA *
 ***********************************************************************************/

#define COLUMNID_ACCOUNTS @"AccountsColumn"	// the single column name in our outline view

#import "AccountsVC.h"

#include <accountmodel.h>
#include <account.h>

@interface AccountsVC ()

@end

@implementation AccountsVC
@synthesize accountsListView;
@synthesize accountDetailsVC;
@synthesize accountsControls;
@synthesize treeController;

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        NSLog(@"INIT Accounts VC");
    }
    return self;
}

- (void)awakeFromNib
{
    NSLog(@"awakeFromNib");

    treeController = [[QNSTreeController alloc] initWithQModel:AccountModel::instance()];

    [treeController setAvoidsEmptySelection:NO];
    [treeController setChildrenKeyPath:@"children"];

    [accountsListView bind:@"content" toObject:treeController withKeyPath:@"arrangedObjects" options:nil];
    [accountsListView bind:@"sortDescriptors" toObject:treeController withKeyPath:@"sortDescriptors" options:nil];
    [accountsListView bind:@"selectionIndexPaths" toObject:treeController withKeyPath:@"selectionIndexPaths" options:nil];
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
    if ([[tableColumn identifier] isEqualToString:COLUMNID_ACCOUNTS])
    {
        NSIndexPath* idx = ((NSTreeNode*)item).indexPath;
        NSUInteger myArray[[idx length]];
        [idx getIndexes:myArray];

        NSLog(@"dataCellForTableColumn, indexPath: %lu", (unsigned long)myArray[0]);
    }

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
    if ([[tableColumn identifier] isEqualToString:COLUMNID_ACCOUNTS])
    {
        NSIndexPath* idx = ((NSTreeNode*)item).indexPath;
        NSUInteger myArray[[idx length]];
        [idx getIndexes:myArray];
        NSLog(@"array:%@", idx);

        QModelIndex qIdx;
        if(idx.length == 2)
            qIdx = AccountModel::instance()->index(myArray[1], 0, AccountModel::instance()->index(myArray[0], 0));
        else
            qIdx = AccountModel::instance()->index(myArray[0], 0);


        if(qIdx.isValid()) {
            cell.title = AccountModel::instance()->data(qIdx, Qt::DisplayRole).toString().toNSString();
            [cell setState:AccountModel::instance()->data(qIdx, (int)Account::Role::Enabled).value<BOOL>()?NSOnState:NSOffState];
        }
    }
}

// -------------------------------------------------------------------------------
//	outlineViewSelectionDidChange:notification
// -------------------------------------------------------------------------------
- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    // ask the tree controller for the current selection
    NSLog(@"outlineViewSelectionDidChange!!");
}

- (IBAction)segControlClicked:(NSSegmentedControl *)sender {
    int clickedSegment = [sender selectedSegment];
    int clickedSegmentTag = [[sender cell] tagForSegment:clickedSegment];
    NSLog(@"clickedSegmentTag %d", clickedSegmentTag);
    switch (clickedSegmentTag) {
        case 0:
            // Add account
            //AccountModel::instance()->add("Coucou");
            break;
        case 1:
            // Remove account
            break;
        default:
            break;
    }
}
@end
