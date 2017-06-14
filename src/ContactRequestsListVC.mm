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
#import <QSize>
#import <QtMacExtras/qmacfunctions.h>
#import <QPixmap>

//LRC
#import <account.h>
#import <availableAccountModel.h>
#import <contactRequest.h>
#import <pendingContactRequestModel.h>
#import <globalinstances.h>
#import <contactmethod.h>

#import "ContactRequestsListVC.h"
#import "QNSTreeController.h"
#import <interfaces/pixmapmanipulatori.h>

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
NSInteger const TAG_PHOTO       =   300;



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
    contactRequestView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
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
    NSTableCellView* result = [outlineView makeViewWithIdentifier:@"ContactRequestView" owner:self];

    QModelIndex qIdx = [self.requestsTreeController toQIdx:((NSTreeNode*)item)];
    if(!qIdx.isValid()) {
        return result;
    }

    NSTextField* nameLabel = [result viewWithTag:TAG_NAME];
    NSTextField* ringIDLabel = [result viewWithTag:TAG_RINGID];
    NSImageView* photoView = [result viewWithTag:TAG_PHOTO];

    ContactRequest* contactRequest = qvariant_cast<ContactRequest*>(qIdx.data((int)Ring::Role::Object));
    Person* person = contactRequest->peer();
    if(!person) {
        Account* chosenAccount = [self chosenAccount];
        NSString* ringID = chosenAccount->pendingContactRequestModel()->data(qIdx,Qt::DisplayRole).toString().toNSString();
        [nameLabel setStringValue:ringID];
        return result;
    }

    QVariant photo = GlobalInstances::pixmapManipulator().contactPhoto(person, {100,100});
    [photoView setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(photo))];

    NSString* idString  = person->phoneNumbers()[0]->getBestId().toNSString();
    if(person->formattedName() != nil && person->formattedName().length()>0) {
        NSString* name = person->formattedName().toNSString();
        [nameLabel setStringValue:name];
        if(![person->formattedName().toNSString() isEqualToString:idString]){
            NSString* formattedID = [NSString stringWithFormat:@"%@%@%@",@"(",idString, @")"];
            [ringIDLabel setStringValue:formattedID];
        }
        return result;
    }
    [nameLabel setStringValue:idString];

    return result;
}

-(Account* ) chosenAccount
{
    QModelIndex index = AvailableAccountModel::instance().selectionModel()->currentIndex();
    return index.data(static_cast<int>(Account::Role::Object)).value<Account*>();
}

@end
