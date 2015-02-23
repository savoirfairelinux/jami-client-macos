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
@synthesize generalTabItem;
@synthesize audioTabItem;
@synthesize videoTabItem;
@synthesize advancedTabItem;
@synthesize securityTabItem;
@synthesize accountsListView;
@synthesize accountDetailsView;
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
    NSLog(@"INIT Accounts VC");
    treeController = [[QNSTreeController alloc] initWithQModel:AccountModel::instance()];
    [treeController setAvoidsEmptySelection:NO];
    [treeController setAlwaysUsesMultipleValuesMarker:YES];
    [treeController setChildrenKeyPath:@"children"];

    [accountsListView bind:@"content" toObject:treeController withKeyPath:@"arrangedObjects" options:nil];
    [accountsListView bind:@"sortDescriptors" toObject:treeController withKeyPath:@"sortDescriptors" options:nil];
    [accountsListView bind:@"selectionIndexPaths" toObject:treeController withKeyPath:@"selectionIndexPaths" options:nil];

    self.generalVC = [[AccGeneralVC alloc] initWithNibName:@"AccGeneral" bundle:nil];
    [[self.generalVC view] setFrame:[self.generalTabItem.view frame]];
    [[self.generalVC view] setBounds:[self.generalTabItem.view bounds]];
    [self.generalTabItem setView:self.generalVC.view];

    self.audioVC = [[AccAudioVC alloc] initWithNibName:@"AccAudio" bundle:nil];
    [[self.audioVC view] setFrame:[self.audioTabItem.view frame]];
    [[self.audioVC view] setBounds:[self.audioTabItem.view bounds]];
    [self.audioTabItem setView:self.audioVC.view];

    self.videoVC = [[AccVideoVC alloc] initWithNibName:@"AccVideo" bundle:nil];
    [[self.videoVC view] setFrame:[self.videoTabItem.view frame]];
    [[self.videoVC view] setBounds:[self.videoTabItem.view bounds]];
    [self.videoTabItem setView:self.videoVC.view];

    self.advancedVC = [[AccAdvancedVC alloc] initWithNibName:@"AccAdvanced" bundle:nil];
    [[self.advancedVC view] setFrame:[self.advancedTabItem.view frame]];
    [[self.advancedVC view] setBounds:[self.advancedTabItem.view bounds]];
    [self.advancedTabItem setView:self.advancedVC.view];

    self.securityVC = [[AccSecurityVC alloc] initWithNibName:@"AccSecurity" bundle:nil];
    [[self.securityVC view] setFrame:[self.securityTabItem.view frame]];
    [[self.securityVC view] setBounds:[self.securityTabItem.view bounds]];
    [self.securityTabItem setView:self.securityVC.view];
}

- (IBAction)segControlClicked:(NSSegmentedControl *)sender {
    int clickedSegment = [sender selectedSegment];
    int clickedSegmentTag = [[sender cell] tagForSegment:clickedSegment];
    NSLog(@"clickedSegmentTag %d", clickedSegmentTag);
    switch (clickedSegmentTag) {
        case 0:
            // Add account
            AccountModel::instance()->add("New Account");
            break;
        case 1:
        {
            // Remove account;
            QModelIndex qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
            AccountModel::instance()->remove(qIdx);
            AccountModel::instance()->save();
            break;
        }
        default:
            break;
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
    if ([[tableColumn identifier] isEqualToString:COLUMNID_ACCOUNTS])
    {
        NSIndexPath* idx = ((NSTreeNode*)item).indexPath;
        NSUInteger myArray[[idx length]];
        [idx getIndexes:myArray];
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
        QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
        if(qIdx.isValid()) {
            cell.title = AccountModel::instance()->data(qIdx, Qt::DisplayRole).toString().toNSString();
            [cell setState:AccountModel::instance()->data(qIdx, Qt::CheckStateRole).value<BOOL>()?NSOnState:NSOffState];
        }
    }
}

// -------------------------------------------------------------------------------
//	outlineViewSelectionDidChange:notification
// -------------------------------------------------------------------------------
- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    // ask the tree controller for the current selection
    if([[treeController selectedNodes] count] > 0) {
        QModelIndex qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
        NSLog(@"Selected account is %@", AccountModel::instance()->data(qIdx, Qt::DisplayRole).toString().toNSString());

        //Update details view
        Account* acc = AccountModel::instance()->getAccountByModelIndex(qIdx);
        [self.generalVC loadAccount:acc];
        [self.audioVC loadAccount:acc];
        [self.videoVC loadAccount:acc];
        [self.advancedVC loadAccount:acc];
        [self.securityVC loadAccount:acc];

        [self.accountDetailsView setHidden:NO];
    } else {
        [self.accountDetailsView setHidden:YES];
    }
}

#pragma mark - NSTabViewDelegate methods

- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)tabView
{
    NSLog(@"tabViewDidChangeNumberOfTabViewItems!!");
}

- (BOOL)tabView:(NSTabView *)tabView
shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    NSLog(@"shouldSelectTabViewItem!!");

    return YES;
}

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    NSLog(@"willSelectTabViewItem!!");
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    NSLog(@"didSelectTabViewItem!!");
}


@end
