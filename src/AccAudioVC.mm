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

NSInteger const TAG_CHECK       =   100;
NSInteger const TAG_NAME        =   200;
NSInteger const TAG_FREQUENCY   =   300;

- (void) loadView
{
    [super loadView];
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

- (IBAction)toggleCodec:(NSButton*)sender {
    NSInteger row = [codecsView rowForView:sender];
    QModelIndex qIdx = [self currentAccount]->codecModel()->audioCodecs()->index(row, 0, QModelIndex());
    [self currentAccount]->codecModel()->audioCodecs()->setData(qIdx, sender.state == NSOnState ? Qt::Checked : Qt::Unchecked, Qt::CheckStateRole);
}

#pragma mark - NSOutlineViewDelegate methods

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item;
{
    return YES;
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    NSTableView* result = [outlineView makeViewWithIdentifier:@"CodecView" owner:self];

    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    if(!qIdx.isValid())
        return result;
    NSTextField* name = [result viewWithTag:TAG_NAME];
    NSTextField* frequency = [result viewWithTag:TAG_FREQUENCY];
    NSButton* check = [result viewWithTag:TAG_CHECK];

    [name setStringValue:[self currentAccount]->codecModel()->audioCodecs()->data(qIdx, CodecModel::Role::NAME).toString().toNSString()];
    [frequency setStringValue:[NSString stringWithFormat:@"%@ Hz", [self currentAccount]->codecModel()->audioCodecs()->data(qIdx, CodecModel::Role::SAMPLERATE).toString().toNSString()]];
    [check setState:[self currentAccount]->codecModel()->audioCodecs()->data(qIdx, Qt::CheckStateRole).value<BOOL>()?NSOnState:NSOffState];
    return result;
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
