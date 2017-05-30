/*
 *  Copyright (C) 2015-2017 Savoir-faire Linux Inc.
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

//Qt
#import <QItemSelectionModel>

//LRC
#import <account.h>
#import <availableAccountModel.h>
#import <contactmethod.h>
#import <bannedContactmodel.h>

#import "AccBannedContactsVC.h"
#import "QNSTreeController.h"

@interface AccBannedContactsVC ()

@property QNSTreeController* bannedContactsTreeController;
@property (unsafe_unretained) IBOutlet NSOutlineView* banedContactsView;

@end

@implementation AccBannedContactsVC

@synthesize bannedContactsTreeController;
@synthesize banedContactsView;

NSInteger const TAG_NAME        =   100;
NSInteger const TAG_RINGID      =   200;

- (void)awakeFromNib
{
    QObject::connect(AccountModel::instance().selectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {
                         if(!current.isValid())
                             return;
                         [self loadAccount];
                     });
}

- (void)loadAccount
{
    auto account = AccountModel::instance().selectedAccount();
    self.bannedContactsTreeController = [[QNSTreeController alloc] initWithQModel:(QAbstractItemModel*)account->bannedContactModel()];
    [self.bannedContactsTreeController setAvoidsEmptySelection:NO];
    [self.bannedContactsTreeController setChildrenKeyPath:@"children"];

    [self.banedContactsView bind:@"content" toObject:self.bannedContactsTreeController withKeyPath:@"arrangedObjects" options:nil];
    [self.banedContactsView bind:@"sortDescriptors" toObject:self.bannedContactsTreeController withKeyPath:@"sortDescriptors" options:nil];
    [self.banedContactsView bind:@"selectionIndexPaths" toObject:self.bannedContactsTreeController withKeyPath:@"selectionIndexPaths" options:nil];
    NSLog(@"numberofRowsBanned, %d", account->bannedContactModel()->rowCount());
    self.bannedListIsEmpty = account->bannedContactModel()->rowCount() == 0;
}

- (IBAction)unbanContact:(NSView*)sender
{
    NSInteger row = [self.banedContactsView rowForView:sender];
    if(row < 0) {
        return;
    }
    auto account = AccountModel::instance().selectedAccount();
    id item  = [self.banedContactsView itemAtRow:row];
    QModelIndex qIdx = [self.bannedContactsTreeController toQIdx:((NSTreeNode*)item)];
    if(!qIdx.isValid()) {
        return;
    }
    auto cm = qIdx.data(static_cast<int>(ContactMethod::Role::Object)).value<ContactMethod*>();
    if( account && cm) {
        account->bannedContactModel()->remove(cm);
    }
}

#pragma mark - NSOutlineViewDelegate methods

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
    return YES;
}

- (void)outlineView:(NSOutlineView *)outlineView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
    auto account = AccountModel::instance().selectedAccount();
    self.bannedListIsEmpty = account->bannedContactModel()->rowCount() == 0;
}

- (void)outlineView:(NSOutlineView *)outlineView didRemoveRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
    auto account = AccountModel::instance().selectedAccount();
    self.bannedListIsEmpty = account->bannedContactModel()->rowCount() == 0;
}

- (NSTableRowView *)outlineView:(NSOutlineView *)outlineView rowViewForItem:(id)item
{
    return [outlineView makeViewWithIdentifier:@"HoverRowView" owner:nil];
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    NSTableView* result = [outlineView makeViewWithIdentifier:@"BannedContactsCellView" owner:self];

    QModelIndex qIdx = [self.bannedContactsTreeController toQIdx:((NSTreeNode*)item)];
    if(!qIdx.isValid())
        return result;

    NSTextField* nameLabel = [result viewWithTag:TAG_NAME];
    NSTextField* deviceIDLabel = [result viewWithTag:TAG_RINGID];

    auto account = AccountModel::instance().selectedAccount();

    NSString* stringID = account->bannedContactModel()->data(qIdx,Qt::DisplayRole).toString().toNSString();

    [nameLabel setStringValue:stringID];
    [deviceIDLabel setStringValue:stringID];

    return result;
}

@end
