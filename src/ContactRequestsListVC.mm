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

#import "ContactRequestsListVC.h"
#import "QNSTreeController.h"
#import "PendingContactRequestModel.h"
#import "Account.h"
#import "ContactRequest.h"
#import <AvailableAccountModel.h>
//Qt
#import <QItemSelectionModel>

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

//NSInteger const TAG_PHOTO       =   100;
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
    [self performAction:ACCEPT forequestAtRow:row];
}

- (IBAction)refuseContactRequest:(NSView*)sender
{
    NSInteger row = [self.contactRequestView rowForView:sender];
    [self performAction:REFUSE forequestAtRow:row];
}

- (IBAction)blockContactRequest:(NSView*)sender
{
    NSInteger row = [self.contactRequestView rowForView:sender];
    [self performAction:BLOCK forequestAtRow:row];
}

-(void) performAction:(ContactAction)action forequestAtRow:(NSInteger)row {
    id item  = [self.contactRequestView itemAtRow:row];
    QModelIndex qIdx = [self.requestsTreeController toQIdx:((NSTreeNode*)item)];
    Account* chosenAccount = AccountModel::instance().userChosenAccount();
    const auto& var = qIdx.data(static_cast<int>(Ring::Role::Object));
    if (!var.isValid()) {
        return;
    }
    ContactRequest *p = qvariant_cast<ContactRequest*>(var);
    switch (action) {
        case ACCEPT:
            p->accept();
            break;
        case REFUSE:
            p->discard();
            break;
        case BLOCK:
            p->block();
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
    if(!qIdx.isValid())
        return result;
    Account* chosenAccount = [self chosenAccount];
    NSTextField* nameLabel = [result viewWithTag:TAG_NAME];
    NSTextField* ringIDLabel = [result viewWithTag:TAG_RINGID];

    auto trustRequest = chosenAccount->pendingContactRequestModel()->data(qIdx,Qt::DisplayRole);

    NSString* string = chosenAccount->pendingContactRequestModel()->data(qIdx,Qt::DisplayRole).toString().toNSString();

    [nameLabel setStringValue:string];
    [ringIDLabel setStringValue:string];
    return result;
}

-(Account* ) chosenAccount
{
    QModelIndex index = AvailableAccountModel::instance().selectionModel()->currentIndex();
    Account* account = index.data(static_cast<int>(Account::Role::Object)).value<Account*>();
    return account;
}

@end
