/*
 *  Copyright (C) 2015-2016 Savoir-faire Linux Inc.
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
 */
#define COLUMNID_STATE   @"AudioStateColumn"
#define COLUMNID_CODECS   @"AudioCodecsColumn"
#define COLUMNID_FREQ     @"AudioFrequencyColumn"
#define COLUMNID_BITRATE  @"AudioBitrateColumn"

#import "AccAudioVC.h"

///Qt
#import <QSortFilterProxyModel>
#import <qitemselectionmodel.h>

///LRC
#import <audio/codecmodel.h>
#import <accountmodel.h>
#import <ringtonemodel.h>

@interface AccAudioVC ()

@property QNSTreeController* treeController;
@property (assign) IBOutlet NSOutlineView* codecsView;
@property (unsafe_unretained) IBOutlet NSPopUpButton *ringtonePopUpButton;
@property (unsafe_unretained) IBOutlet NSButton* enableRingtone;

@end

@implementation AccAudioVC
@synthesize treeController;
@synthesize codecsView;
@synthesize ringtonePopUpButton, enableRingtone;

- (void)awakeFromNib
{
    NSLog(@"INIT Audio VC");
    QObject::connect(AccountModel::instance().selectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {
                         if(!current.isValid())
                             return;
                         [self loadAccount];
                     });
}

- (Account*) currentAccount
{
    auto accIdx = AccountModel::instance().selectionModel()->currentIndex();
    return AccountModel::instance().getAccountByModelIndex(accIdx);
}

- (void)loadAccount
{
    auto account = [self currentAccount];
    treeController = [[QNSTreeController alloc] initWithQModel:account->codecModel()->audioCodecs()];

    [treeController setAvoidsEmptySelection:NO];
    [treeController setChildrenKeyPath:@"children"];

    [codecsView bind:@"content" toObject:treeController withKeyPath:@"arrangedObjects" options:nil];
    [codecsView bind:@"sortDescriptors" toObject:treeController withKeyPath:@"sortDescriptors" options:nil];
    [codecsView bind:@"selectionIndexPaths" toObject:treeController withKeyPath:@"selectionIndexPaths" options:nil];

    QModelIndex qIdx = RingtoneModel::instance().selectionModel(account)->currentIndex();
    [ringtonePopUpButton addItemWithTitle:RingtoneModel::instance().data(qIdx, Qt::DisplayRole).toString().toNSString()];

    [enableRingtone setState:account->isRingtoneEnabled()];
    [ringtonePopUpButton setEnabled:account->isRingtoneEnabled()];
}

- (IBAction)toggleRingtoneEnabled:(id)sender {
    [self currentAccount]->setRingtoneEnabled([sender state]);
    [ringtonePopUpButton setEnabled:[sender state]];
}

- (IBAction)chooseRingtone:(id)sender {
    int index = [sender indexOfSelectedItem];
    QModelIndex qIdx = RingtoneModel::instance().index(index, 0);
    RingtoneModel::instance().selectionModel([self currentAccount])->setCurrentIndex(qIdx, QItemSelectionModel::ClearAndSelect);
}

- (IBAction)moveUp:(id)sender {
    if([[treeController selectedNodes] count] > 0) {
        QModelIndex qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
        if(!qIdx.isValid())
            return;

        QMimeData* mime = [self currentAccount]->codecModel()->audioCodecs()->mimeData(QModelIndexList() << qIdx);
        [self currentAccount]->codecModel()->audioCodecs()->dropMimeData(mime, Qt::MoveAction, qIdx.row() - 1, 0, QModelIndex());
    }
}

- (IBAction)moveDown:(id)sender {
    if([[treeController selectedNodes] count] > 0) {
        QModelIndex qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
        if(!qIdx.isValid())
            return;

        QMimeData* mime = [self currentAccount]->codecModel()->audioCodecs()->mimeData(QModelIndexList() << qIdx);
        [self currentAccount]->codecModel()->audioCodecs()->dropMimeData(mime, Qt::MoveAction, qIdx.row() + 1, 0, QModelIndex());
    }
}

- (IBAction)toggleCodec:(NSOutlineView*)sender {
    NSInteger row = [sender clickedRow];
    NSTableColumn *col = [sender tableColumnWithIdentifier:COLUMNID_STATE];
    NSButtonCell *cell = [col dataCellForRow:row];
    QModelIndex qIdx = [self currentAccount]->codecModel()->audioCodecs()->index(row, 0, QModelIndex());
    [self currentAccount]->codecModel()->audioCodecs()->setData(qIdx, cell.state == NSOnState ? Qt::Unchecked : Qt::Checked, Qt::CheckStateRole);
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
        [cell setState:[self currentAccount]->codecModel()->audioCodecs()->data(qIdx, Qt::CheckStateRole).value<BOOL>()?NSOnState:NSOffState];
    } else if ([[tableColumn identifier] isEqualToString:COLUMNID_CODECS])
    {
        cell.title = [self currentAccount]->codecModel()->audioCodecs()->data(qIdx, CodecModel::Role::NAME).toString().toNSString();
    } else if ([[tableColumn identifier] isEqualToString:COLUMNID_FREQ])
    {
        cell.title = [self currentAccount]->codecModel()->audioCodecs()->data(qIdx, CodecModel::Role::SAMPLERATE).toString().toNSString();
    } else if ([[tableColumn identifier] isEqualToString:COLUMNID_BITRATE])
    {
        cell.title = [self currentAccount]->codecModel()->audioCodecs()->data(qIdx, CodecModel::Role::BITRATE).toString().toNSString();
    }
}

// -------------------------------------------------------------------------------
//	outlineViewSelectionDidChange:notification
// -------------------------------------------------------------------------------
- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{

}

#pragma mark - NSMenuDelegate methods

- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(NSInteger)index shouldCancel:(BOOL)shouldCancel
{
    QModelIndex qIdx;
    qIdx = RingtoneModel::instance().index(index, 0);
    [item setTitle:RingtoneModel::instance().data(qIdx, Qt::DisplayRole).toString().toNSString()];

    if (qIdx == RingtoneModel::instance().selectionModel([self currentAccount])->currentIndex()) {
        [ringtonePopUpButton selectItem:item];
    }
    return YES;
}

- (NSInteger)numberOfItemsInMenu:(NSMenu *)menu
{
    return RingtoneModel::instance().rowCount();
}

@end
