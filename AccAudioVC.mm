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

#define COLUMNID_STATE   @"AudioStateColumn"
#define COLUMNID_CODECS   @"AudioCodecsColumn"
#define COLUMNID_FREQ     @"AudioFrequencyColumn"
#define COLUMNID_BITRATE  @"AudioBitrateColumn"

#import "AccAudioVC.h"

#include <QSortFilterProxyModel>

#include <audio/codecmodel.h>
#include <accountmodel.h>

@interface AccAudioVC ()

@property Account* privateAccount;

@end

@implementation AccAudioVC
@synthesize treeController;
@synthesize codecsView;
@synthesize privateAccount;

- (void)awakeFromNib
{
    NSLog(@"INIT Audio VC");
}

- (void)loadAccount:(Account *)account
{
    privateAccount = account;
    treeController = [[QNSTreeController alloc] initWithQModel:privateAccount->codecModel()->audioCodecs()];

    [treeController setAvoidsEmptySelection:NO];
    [treeController setChildrenKeyPath:@"children"];

    [self.codecsView bind:@"content" toObject:treeController withKeyPath:@"arrangedObjects" options:nil];
    [self.codecsView bind:@"sortDescriptors" toObject:treeController withKeyPath:@"sortDescriptors" options:nil];
    [self.codecsView bind:@"selectionIndexPaths" toObject:treeController withKeyPath:@"selectionIndexPaths" options:nil];
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
    if([[tableColumn identifier] isEqualToString:COLUMNID_STATE]) {
        [cell setState:privateAccount->codecModel()->audioCodecs()->data(qIdx, Qt::CheckStateRole).value<BOOL>()?NSOnState:NSOffState];
    } else if ([[tableColumn identifier] isEqualToString:COLUMNID_CODECS])
    {
        cell.title = privateAccount->codecModel()->audioCodecs()->data(qIdx, CodecModel::Role::NAME).toString().toNSString();
    } else if ([[tableColumn identifier] isEqualToString:COLUMNID_FREQ])
    {
        cell.title = privateAccount->codecModel()->audioCodecs()->data(qIdx, CodecModel::Role::SAMPLERATE).toString().toNSString();
    } else if ([[tableColumn identifier] isEqualToString:COLUMNID_BITRATE])
    {
        cell.title = privateAccount->codecModel()->audioCodecs()->data(qIdx, CodecModel::Role::BITRATE).toString().toNSString();
    }
}

- (IBAction)toggleCodec:(NSOutlineView*)sender {
    NSInteger row = [sender clickedRow];
    NSTableColumn *col = [sender tableColumnWithIdentifier:COLUMNID_STATE];
    NSButtonCell *cell = [col dataCellForRow:row];
    privateAccount->codecModel()->audioCodecs()->setData(
                                                         privateAccount->codecModel()->audioCodecs()->index(row, 0, QModelIndex()), cell.state == NSOnState ? Qt::Unchecked : Qt::Checked, Qt::CheckStateRole);
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
