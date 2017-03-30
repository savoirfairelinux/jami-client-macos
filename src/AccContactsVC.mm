/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
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

#import "AccContactsVC.h"

//Qt
#import <qitemselectionmodel.h>

//LRC
#import <accountmodel.h>
#import <pendingcontactrequestmodel.h>

// Ring
#import "QNSTreeController.h"
#import "views/RingOutlineView.h"

@interface AccContactsVC () <NSOutlineViewDelegate>

@property QNSTreeController* contactsTreeController;
@property (unsafe_unretained) IBOutlet RingOutlineView *contactListView;

@end

@implementation AccContactsVC

NSInteger const TAG_NAME        =   100;
NSInteger const TAG_RINGID      =   200;

- (void)awakeFromNib
{
    NSLog(@"INIT Contacts VC");

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
    self.contactsTreeController = [[QNSTreeController alloc] initWithQModel:(QAbstractItemModel*)account->pendingContactRequestModel()];
    [self.contactsTreeController setAvoidsEmptySelection:NO];
    [self.contactsTreeController setChildrenKeyPath:@"children"];

    [self.contactListView bind:@"content" toObject:self.contactsTreeController withKeyPath:@"arrangedObjects" options:nil];
    [self.contactListView bind:@"sortDescriptors" toObject:self.contactsTreeController withKeyPath:@"sortDescriptors" options:nil];
    [self.contactListView bind:@"selectionIndexPaths" toObject:self.contactsTreeController withKeyPath:@"selectionIndexPaths" options:nil];
}

#pragma mark - NSOutlineViewDelegate methods

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
    return YES;
}

- (NSTableRowView *)outlineView:(NSOutlineView *)outlineView rowViewForItem:(id)item
{
    return [outlineView makeViewWithIdentifier:@"HoverRowView" owner:nil];
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    NSTableView* result = [outlineView makeViewWithIdentifier:@"ContactView" owner:self];

    QModelIndex qIdx = [self.contactsTreeController toQIdx:((NSTreeNode*)item)];
    if(!qIdx.isValid())
        return result;

    NSTextField* nameLabel = [result viewWithTag:TAG_NAME];
    NSTextField* ringLabel = [result viewWithTag:TAG_RINGID];
    auto account = AccountModel::instance().selectedAccount();
    NSString* contactRingID = account->pendingContactRequestModel()->data(qIdx,Qt::DisplayRole).toString().toNSString();
    [ringLabel setStringValue:contactRingID];
    [nameLabel setStringValue:contactRingID];

    return result;
}

@end
