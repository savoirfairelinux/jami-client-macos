/*
 *  Copyright (C) 2004-2015 Savoir-Faire Linux Inc.
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
#define COLUMNID_STATE   @"VideoStateColumn"
#define COLUMNID_CODECS   @"VideoCodecsColumn"
#define COLUMNID_FREQ     @"VideoFrequencyColumn"
#define COLUMNID_BITRATE  @"VideoBitrateColumn"

#import "AccVideoVC.h"

#include <QtCore/QSortFilterProxyModel>

#include <audio/codecmodel.h>
#include <accountmodel.h>

#import "QNSTreeController.h"

@interface AccVideoVC ()

@property Account* privateAccount;
@property QNSTreeController *treeController;
@property (assign) IBOutlet NSOutlineView *codecsView;
@property (assign) IBOutlet NSView *videoPanelContainer;
@property (assign) IBOutlet NSButton *toggleVideoButton;

@end

@implementation AccVideoVC
@synthesize treeController;
@synthesize codecsView;
@synthesize privateAccount;
@synthesize videoPanelContainer;
@synthesize toggleVideoButton;

- (void)awakeFromNib
{
    NSLog(@"INIT Video VC");
}

- (void)loadAccount:(Account *)account
{
    privateAccount = account;

    treeController = [[QNSTreeController alloc] initWithQModel:privateAccount->codecModel()->videoCodecs()];
    [treeController setAvoidsEmptySelection:NO];
    [treeController setChildrenKeyPath:@"children"];

    [codecsView bind:@"content" toObject:treeController withKeyPath:@"arrangedObjects" options:nil];
    [codecsView bind:@"sortDescriptors" toObject:treeController withKeyPath:@"sortDescriptors" options:nil];
    [codecsView bind:@"selectionIndexPaths" toObject:treeController withKeyPath:@"selectionIndexPaths" options:nil];
    [videoPanelContainer setHidden:!privateAccount->isVideoEnabled()];
    [toggleVideoButton setState:privateAccount->isVideoEnabled()?NSOnState:NSOffState];
}

- (IBAction)toggleVideoEnabled:(id)sender {
    privateAccount->setVideoEnabled([sender state] == NSOnState);
    [videoPanelContainer setHidden:!privateAccount->isVideoEnabled()];
}

- (IBAction)toggleCodec:(NSOutlineView*)sender {
    NSInteger row = [sender clickedRow];
    NSTableColumn *col = [sender tableColumnWithIdentifier:COLUMNID_STATE];
    NSButtonCell *cell = [col dataCellForRow:row];
    privateAccount->codecModel()->videoCodecs()->setData(privateAccount->codecModel()->videoCodecs()->index(row, 0, QModelIndex()),
        cell.state == NSOnState ? Qt::Unchecked : Qt::Checked, Qt::CheckStateRole);
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
        [cell setState:privateAccount->codecModel()->videoCodecs()->data(qIdx, Qt::CheckStateRole).value<BOOL>()?NSOnState:NSOffState];
    } else if ([[tableColumn identifier] isEqualToString:COLUMNID_CODECS])
    {
        cell.title = privateAccount->codecModel()->videoCodecs()->data(qIdx, CodecModel::Role::NAME).toString().toNSString();
        [cell setState:privateAccount->codecModel()->videoCodecs()->data(qIdx, Qt::CheckStateRole).value<BOOL>()?NSOnState:NSOffState];
    } else if ([[tableColumn identifier] isEqualToString:COLUMNID_FREQ])
    {
        cell.title = privateAccount->codecModel()->videoCodecs()->data(qIdx, CodecModel::Role::SAMPLERATE).toString().toNSString();
    } else if ([[tableColumn identifier] isEqualToString:COLUMNID_BITRATE])
    {
        cell.title = privateAccount->codecModel()->videoCodecs()->data(qIdx, CodecModel::Role::BITRATE).toString().toNSString();
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
