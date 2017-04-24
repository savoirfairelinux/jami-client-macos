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
#import <contactRequest.h>
#import <availableAccountModel.h>

#import "ContactRequestsListVC.h"
#import "QNSTreeController.h"
#import <pendingContactRequestModel.h>

@interface ContactRequestsListVC ()

@property QNSTreeController* requestsTreeController;
@property (unsafe_unretained) IBOutlet NSOutlineView* contactRequestView;
@property (unsafe_unretained) IBOutlet NSTextField* noRequestsLabel;
@end

@implementation ContactRequestsListVC

@synthesize requestsTreeController;
@synthesize contactRequestView;
@synthesize noRequestsLabel;

typedef NS_ENUM(NSInteger, ContactAction) {
    ACCEPT = 0,
    REFUSE,
    BLOCK,
};

NSInteger const TAG_NAME        =   100;
NSInteger const TAG_RINGID      =   200;

- (void)awakeFromNib
{
    Account* chosenAccount = [self chosenAccount];
    requestsTreeController = [[QNSTreeController alloc] initWithQModel:chosenAccount->pendingContactRequestModel()];
    [requestsTreeController setAvoidsEmptySelection:NO];
    [requestsTreeController setAlwaysUsesMultipleValuesMarker:YES];
    [requestsTreeController setChildrenKeyPath:@"children"];

    [contactRequestView bind:@"content" toObject:requestsTreeController withKeyPath:@"arrangedObjects" options:nil];
    [contactRequestView bind:@"sortDescriptors" toObject:requestsTreeController withKeyPath:@"sortDescriptors" options:nil];
    [contactRequestView bind:@"selectionIndexPaths" toObject:requestsTreeController withKeyPath:@"selectionIndexPaths" options:nil];
    [noRequestsLabel setHidden:[contactRequestView numberOfRows]>0];

}

- (IBAction)acceptContactRequest:(NSView*)sender
{
    NSInteger row = [self.contactRequestView rowForView:sender];
    [self performAction:ACCEPT forRequestAtRow:row];
}

- (IBAction)refuseContactRequest:(NSView*)sender
{
    NSInteger row = [self.contactRequestView rowForView:sender];
    [self performAction:REFUSE forRequestAtRow:row];
}

- (IBAction)blockContactRequest:(NSView*)sender
{
    NSInteger row = [self.contactRequestView rowForView:sender];
    [self performAction:BLOCK forRequestAtRow:row];
}

-(void) performAction:(ContactAction)action forRequestAtRow:(NSInteger)row {
    id item  = [self.contactRequestView itemAtRow:row];
    QModelIndex qIdx = [self.requestsTreeController toQIdx:((NSTreeNode*)item)];
    Account* chosenAccount = AccountModel::instance().userChosenAccount();
    const auto& var = qIdx.data(static_cast<int>(Ring::Role::Object));
    if (!var.isValid()) {
        return;
    }
    auto contactRequest = qvariant_cast<ContactRequest*>(var);
    switch (action) {
        case ACCEPT:
            contactRequest->accept();
            break;
        case REFUSE:
            contactRequest->discard();
            break;
        case BLOCK:
            contactRequest->block();
            break;
        default:
            break;
    }
    [noRequestsLabel setHidden:[contactRequestView numberOfRows]>0];
}

#pragma mark - NSOutlineViewDelegate methods

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
    return NO;
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    NSTableView* result = [outlineView makeViewWithIdentifier:@"ContactRequestView" owner:self];

    QModelIndex qIdx = [self.requestsTreeController toQIdx:((NSTreeNode*)item)];
    if(!qIdx.isValid()) {
        return result;
    }
    Account* chosenAccount = [self chosenAccount];
    NSTextField* nameLabel = [result viewWithTag:TAG_NAME];
    NSTextField* ringIDLabel = [result viewWithTag:TAG_RINGID];

    NSString* ringID = chosenAccount->pendingContactRequestModel()->data(qIdx,Qt::DisplayRole).toString().toNSString();

    [nameLabel setStringValue:ringID];
    [ringIDLabel setStringValue:ringID];
    return result;
}

-(Account* ) chosenAccount
{
    QModelIndex index = AvailableAccountModel::instance().selectionModel()->currentIndex();
    return index.data(static_cast<int>(Account::Role::Object)).value<Account*>();
}

@end
