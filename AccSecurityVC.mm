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

#define COLUMNID_REALM   @"RealmColumn"
#define COLUMNID_AUTH   @"AuthNameColumn"
#define COLUMNID_PWD     @"PasswordColumn"

#import "AccSecurityVC.h"

#include <credentialmodel.h>

@interface AccSecurityVC ()

@property Account* privateAccount;

@end

@implementation AccSecurityVC
@synthesize privateAccount;
@synthesize treeController;

- (void)awakeFromNib
{
    NSLog(@"INIT Security VC");
}

- (void)loadAccount:(Account *)account
{
    privateAccount = account;
    treeController = [[QNSTreeController alloc] initWithQModel:privateAccount->credentialsModel()];

    [treeController setAvoidsEmptySelection:NO];
    [treeController setChildrenKeyPath:@"children"];

    [self.credentialsView bind:@"content" toObject:treeController withKeyPath:@"arrangedObjects" options:nil];
    [self.credentialsView bind:@"sortDescriptors" toObject:treeController withKeyPath:@"sortDescriptors" options:nil];
    [self.credentialsView bind:@"selectionIndexPaths" toObject:treeController withKeyPath:@"selectionIndexPaths" options:nil];
}

- (IBAction)segControlClicked:(NSSegmentedControl *)sender {
    int clickedSegment = [sender selectedSegment];
    int clickedSegmentTag = [[sender cell] tagForSegment:clickedSegment];
    NSLog(@"clickedSegmentTag %d", clickedSegmentTag);
    switch (clickedSegmentTag) {
        case 0:
            // Add account
            privateAccount->credentialsModel()->addCredentials();
            break;
        case 1:
        {
            // Remove credentials;
            QModelIndex qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
            privateAccount->credentialsModel()->removeCredentials(qIdx);
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
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    if(!qIdx.isValid())
        return;
    if([[tableColumn identifier] isEqualToString:COLUMNID_REALM]) {
        cell.title = privateAccount->credentialsModel()->data(qIdx, CredentialModel::Role::REALM).toString().toNSString();
    } else if ([[tableColumn identifier] isEqualToString:COLUMNID_AUTH])
    {
        cell.title = privateAccount->credentialsModel()->data(qIdx, CredentialModel::Role::NAME).toString().toNSString();
    } else if ([[tableColumn identifier] isEqualToString:COLUMNID_PWD])
    {
        cell.title = privateAccount->credentialsModel()->data(qIdx, CredentialModel::Role::PASSWORD).toString().toNSString();
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

@end
