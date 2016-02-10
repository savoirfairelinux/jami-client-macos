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
#import "AccMediaVC.h"

///Qt
#import <QSortFilterProxyModel>
#import <qitemselectionmodel.h>

///LRC
#import <audio/codecmodel.h>
#import <accountmodel.h>
#import <ringtonemodel.h>
#import <ringtone.h>

@interface AccMediaVC ()

@property QNSTreeController* audioTreeController;
@property QNSTreeController* videoTreeController;
@property (unsafe_unretained) IBOutlet NSPopUpButton* ringtonePopUpButton;
@property (unsafe_unretained) IBOutlet NSButton* enableRingtone;
@property (unsafe_unretained) IBOutlet NSButton* playRingtone;
@property (unsafe_unretained) IBOutlet NSButton *toggleVideoButton;
@property (unsafe_unretained) IBOutlet NSOutlineView* audioCodecView;
@property (unsafe_unretained) IBOutlet NSOutlineView* videoCodecView;
@property (unsafe_unretained) IBOutlet NSView* videoPanelContainer;

@end

@implementation AccMediaVC
@synthesize audioTreeController, videoTreeController;
@synthesize audioCodecView, videoCodecView;
@synthesize videoPanelContainer;
@synthesize ringtonePopUpButton, enableRingtone, playRingtone, toggleVideoButton;

NSInteger const TAG_CHECK       =   100;
NSInteger const TAG_NAME        =   200;
NSInteger const TAG_DETAILS     =   300;

NSString*  const ID_AUDIO       =   @"audioview";
NSString*  const ID_VIDEO       =   @"videoview";

- (void) loadView
{
    [super loadView];
    NSLog(@"INIT Media VC");
    QObject::connect(AccountModel::instance().selectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {
                         if(!current.isValid())
                             return;
                         [self loadAccount];
                     });

    QObject::connect(&RingtoneModel::instance(),
                     &QAbstractItemModel::dataChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {
                         if(!current.isValid())
                             return;

                         NSString* label;
                         if (!RingtoneModel::instance().isPlaying()) {
                             label = NSLocalizedString(@"Play", @"Button label");
                         } else {
                             label = NSLocalizedString(@"Pause", @"Button label");
                         }
                         [playRingtone setTitle:label];
                     });
}

- (void)loadAccount
{
    // AUDIO
    [self loadAudioPrefs];

    // VIDEO
    [self loadVideoPrefs];

}

#pragma Audio Preferences method

- (void) loadAudioPrefs
{
    auto account = AccountModel::instance().selectedAccount();
    audioTreeController = [[QNSTreeController alloc] initWithQModel:account->codecModel()->audioCodecs()];
    [audioTreeController setAvoidsEmptySelection:NO];
    [audioTreeController setChildrenKeyPath:@"children"];
    [audioCodecView bind:@"content" toObject:audioTreeController withKeyPath:@"arrangedObjects" options:nil];
    [audioCodecView bind:@"sortDescriptors" toObject:audioTreeController withKeyPath:@"sortDescriptors" options:nil];
    [audioCodecView bind:@"selectionIndexPaths" toObject:audioTreeController withKeyPath:@"selectionIndexPaths" options:nil];
    [audioCodecView setIdentifier:ID_AUDIO];

    QModelIndex qIdx = RingtoneModel::instance().selectionModel(account)->currentIndex();
    [ringtonePopUpButton removeAllItems];
    [ringtonePopUpButton addItemWithTitle:RingtoneModel::instance().data(qIdx, Qt::DisplayRole).toString().toNSString()];

    [enableRingtone setState:account->isRingtoneEnabled()];
    [ringtonePopUpButton setEnabled:account->isRingtoneEnabled()];
}

- (IBAction)startStopRingtone:(id)sender {
    auto qIdx = RingtoneModel::instance().selectionModel(AccountModel::instance().selectedAccount())->currentIndex();
    RingtoneModel::instance().play(qIdx);
}

- (IBAction)toggleRingtoneEnabled:(id)sender {
    AccountModel::instance().selectedAccount()->setRingtoneEnabled([sender state]);
    [ringtonePopUpButton setEnabled:[sender state]];
}

- (IBAction)chooseRingtone:(id)sender {
    int index = [sender indexOfSelectedItem];
    QModelIndex qIdx = RingtoneModel::instance().index(index, 0);
    RingtoneModel::instance().selectionModel(AccountModel::instance().selectedAccount())->setCurrentIndex(qIdx, QItemSelectionModel::ClearAndSelect);
}

- (IBAction)moveAudioCodecUp:(id)sender {
    if([[audioTreeController selectedNodes] count] > 0) {
        QModelIndex qIdx = [audioTreeController toQIdx:[audioTreeController selectedNodes][0]];
        if(!qIdx.isValid())
            return;

        QMimeData* mime = AccountModel::instance().selectedAccount()->codecModel()->audioCodecs()->mimeData(QModelIndexList() << qIdx);
        AccountModel::instance().selectedAccount()->codecModel()->audioCodecs()->dropMimeData(mime, Qt::MoveAction, qIdx.row() - 1, 0, QModelIndex());
    }
}

- (IBAction)moveAudioCodecDown:(id)sender {
    if([[audioTreeController selectedNodes] count] > 0) {
        QModelIndex qIdx = [audioTreeController toQIdx:[audioTreeController selectedNodes][0]];
        if(!qIdx.isValid())
            return;

        QMimeData* mime = AccountModel::instance().selectedAccount()->codecModel()->audioCodecs()->mimeData(QModelIndexList() << qIdx);
        AccountModel::instance().selectedAccount()->codecModel()->audioCodecs()->dropMimeData(mime, Qt::MoveAction, qIdx.row() + 1, 0, QModelIndex());
    }
}

- (IBAction)toggleAudioCodec:(NSButton*)sender {
    NSInteger row = [audioCodecView rowForView:sender];
    QModelIndex qIdx = AccountModel::instance().selectedAccount()->codecModel()->audioCodecs()->index(row, 0, QModelIndex());
    AccountModel::instance().selectedAccount()->codecModel()->audioCodecs()->setData(qIdx, sender.state == NSOnState ? Qt::Checked : Qt::Unchecked, Qt::CheckStateRole);
}

#pragma Video Preferences method

-(void) loadVideoPrefs
{
    auto account = AccountModel::instance().selectedAccount();
    videoTreeController = [[QNSTreeController alloc] initWithQModel:account->codecModel()->videoCodecs()];
    [videoTreeController setAvoidsEmptySelection:NO];
    [videoTreeController setChildrenKeyPath:@"children"];

    [videoCodecView setIdentifier:ID_VIDEO];
    [videoCodecView bind:@"content" toObject:videoTreeController withKeyPath:@"arrangedObjects" options:nil];
    [videoCodecView bind:@"sortDescriptors" toObject:videoTreeController withKeyPath:@"sortDescriptors" options:nil];
    [videoCodecView bind:@"selectionIndexPaths" toObject:videoTreeController withKeyPath:@"selectionIndexPaths" options:nil];
    [videoPanelContainer setHidden:!account->isVideoEnabled()];
    [toggleVideoButton setState:account->isVideoEnabled()?NSOnState:NSOffState];

}

- (IBAction)toggleVideoEnabled:(id)sender {
    AccountModel::instance().selectedAccount()->setVideoEnabled([sender state] == NSOnState);
    [videoPanelContainer setHidden:!AccountModel::instance().selectedAccount()->isVideoEnabled()];
}

- (IBAction)toggleVideoCodec:(NSButton*)sender {
    NSInteger row = [videoCodecView rowForView:sender];
    QModelIndex qIdx = AccountModel::instance().selectedAccount()->codecModel()->videoCodecs()->index(row, 0, QModelIndex());
    AccountModel::instance().selectedAccount()->codecModel()->videoCodecs()->setData(qIdx, sender.state == NSOnState ? Qt::Checked : Qt::Unchecked, Qt::CheckStateRole);
}

- (IBAction)moveVideoCodecUp:(id)sender {

    if([[videoTreeController selectedNodes] count] > 0) {
        QModelIndex qIdx = [videoTreeController toQIdx:[videoTreeController selectedNodes][0]];
        if(!qIdx.isValid())
            return;

        QMimeData* mime = AccountModel::instance().selectedAccount()->codecModel()->mimeData(QModelIndexList() << qIdx);
        AccountModel::instance().selectedAccount()->codecModel()->dropMimeData(mime, Qt::MoveAction, qIdx.row() - 1, 0, QModelIndex());
    }
}

- (IBAction)moveVideoCodecDown:(id)sender {
    if([[videoTreeController selectedNodes] count] > 0) {
        QModelIndex qIdx = [videoTreeController toQIdx:[videoTreeController selectedNodes][0]];
        if(!qIdx.isValid())
            return;

        QMimeData* mime = AccountModel::instance().selectedAccount()->codecModel()->mimeData(QModelIndexList() << qIdx);
        AccountModel::instance().selectedAccount()->codecModel()->dropMimeData(mime, Qt::MoveAction, qIdx.row() + 1, 0, QModelIndex());
    }
}


#pragma mark - NSOutlineViewDelegate methods

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item;
{
    return YES;
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    NSTableView* result = [outlineView makeViewWithIdentifier:@"CodecView" owner:self];

    QModelIndex qIdx;
    if ([outlineView.identifier isEqualToString:ID_AUDIO])
        qIdx = [audioTreeController toQIdx:((NSTreeNode*)item)];
    else
        qIdx = [videoTreeController toQIdx:((NSTreeNode*)item)];

    if(!qIdx.isValid())
        return result;
    NSTextField* name = [result viewWithTag:TAG_NAME];
    NSTextField* details = [result viewWithTag:TAG_DETAILS];
    NSButton* check = [result viewWithTag:TAG_CHECK];

    if ([outlineView.identifier isEqualToString:ID_AUDIO]) {
        [name setStringValue:AccountModel::instance().selectedAccount()->codecModel()->audioCodecs()->data(qIdx, CodecModel::Role::NAME).toString().toNSString()];
        [details setStringValue:[NSString stringWithFormat:@"%@ Hz", AccountModel::instance().selectedAccount()->codecModel()->audioCodecs()->data(qIdx, CodecModel::Role::SAMPLERATE).toString().toNSString()]];
        [check setState:AccountModel::instance().selectedAccount()->codecModel()->audioCodecs()->data(qIdx, Qt::CheckStateRole).value<BOOL>()?NSOnState:NSOffState];
    } else {
        [name setStringValue:AccountModel::instance().selectedAccount()->codecModel()->videoCodecs()->data(qIdx, CodecModel::Role::NAME).toString().toNSString()];
        [check setState:AccountModel::instance().selectedAccount()->codecModel()->videoCodecs()->data(qIdx, Qt::CheckStateRole).value<BOOL>()?NSOnState:NSOffState];
    }

    return result;
}

#pragma mark - NSMenuDelegate methods

- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(NSInteger)index shouldCancel:(BOOL)shouldCancel
{
    QModelIndex qIdx;
    qIdx = RingtoneModel::instance().index(index, 0);
    [item setTitle:RingtoneModel::instance().data(qIdx, Qt::DisplayRole).toString().toNSString()];

    if (qIdx == RingtoneModel::instance().selectionModel(AccountModel::instance().selectedAccount())->currentIndex()) {
        [ringtonePopUpButton selectItem:item];
    }
    return YES;
}

- (NSInteger)numberOfItemsInMenu:(NSMenu *)menu
{
    return RingtoneModel::instance().rowCount();
}

@end
