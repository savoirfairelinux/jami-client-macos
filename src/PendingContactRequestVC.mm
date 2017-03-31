//
//  PendingTrustRequestVC.m
//  Ring
//
//  Created by Kateryna Kostiuk on 2017-03-30.
//
//

#import "PendingContactRequestVC.h"
#import "QNSTreeController.h"
#import "PendingContactRequestModel.h"
#import "Account.h"
#import "AccountModel.h"
#import "ContactRequest.h"
#import "views/HoverTableRowView.h"

@interface PendingContactRequestVC ()

@property QNSTreeController* requestsTreeController;
@property (unsafe_unretained) IBOutlet NSOutlineView* contactRequestView;
@property (unsafe_unretained) IBOutlet NSTextField* noRequestsLabel;
@end

@implementation PendingContactRequestVC

@synthesize requestsTreeController;
@synthesize contactRequestView;
@synthesize noRequestsLabel;

//NSInteger const TAG_PHOTO       =   100;
NSInteger const TAG_NAME        =   100;
NSInteger const TAG_RINGID      =   200;

- (void)awakeFromNib
{
    Account* chosenAccount = AccountModel::instance().userChosenAccount();
    requestsTreeController = [[QNSTreeController alloc] initWithQModel:chosenAccount->pendingContactRequestModel()];
    [requestsTreeController setAvoidsEmptySelection:NO];
    [requestsTreeController setAlwaysUsesMultipleValuesMarker:YES];
    [requestsTreeController setChildrenKeyPath:@"children"];

    [contactRequestView bind:@"content" toObject:requestsTreeController withKeyPath:@"arrangedObjects" options:nil];
    [contactRequestView bind:@"sortDescriptors" toObject:requestsTreeController withKeyPath:@"sortDescriptors" options:nil];
    [contactRequestView bind:@"selectionIndexPaths" toObject:requestsTreeController withKeyPath:@"selectionIndexPaths" options:nil];
    [noRequestsLabel setHidden:chosenAccount->pendingContactRequestModel()->rowCount()>0];
}

- (IBAction)acceptContactRequest:(NSView*)sender
{
    NSInteger row = [self.contactRequestView rowForView:sender];
    id item  = [self.contactRequestView itemAtRow:row];
    QModelIndex qIdx = [self.requestsTreeController toQIdx:((NSTreeNode*)item)];
    Account* chosenAccount = AccountModel::instance().userChosenAccount();
    const auto& var = qIdx.data(static_cast<int>(Ring::Role::Object));
    if (var.isValid()) {
        ContactRequest *p = qvariant_cast<ContactRequest*>(var);
        p->accept();
    }

}

- (IBAction)refuseContactRequest:(NSView*)sender
{

    NSInteger row = [self.contactRequestView rowForView:sender];
    id item  = [self.contactRequestView itemAtRow:row];
    QModelIndex qIdx = [self.requestsTreeController toQIdx:((NSTreeNode*)item)];
    Account* chosenAccount = AccountModel::instance().userChosenAccount();
    const auto& var = qIdx.data(static_cast<int>(Ring::Role::Object));
    if (var.isValid()) {
        ContactRequest *p = qvariant_cast<ContactRequest*>(var);
        p->discard();
    }

}

- (IBAction)blockContactRequest:(NSView*)sender
{

}

#pragma mark - NSOutlineViewDelegate methods

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
    return YES;
}

- (NSTableRowView *)outlineView:(NSOutlineView *)outlineView rowViewForItem:(id)item
{
   HoverTableRowView *row  = [outlineView makeViewWithIdentifier:@"HoverRowView" owner:nil];
    return row;
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    NSTableView* result = [outlineView makeViewWithIdentifier:@"ContactRequestView" owner:self];

    QModelIndex qIdx = [self.requestsTreeController toQIdx:((NSTreeNode*)item)];
    if(!qIdx.isValid())
        return result;
    Account* chosenAccount = AccountModel::instance().userChosenAccount();
    NSTextField* nameLabel = [result viewWithTag:TAG_NAME];
    NSTextField* ringIDLabel = [result viewWithTag:TAG_RINGID];

    auto trustRequest = chosenAccount->pendingContactRequestModel()->data(qIdx,Qt::DisplayRole);

    NSString* string = chosenAccount->pendingContactRequestModel()->data(qIdx,Qt::DisplayRole).toString().toNSString();

    [nameLabel setStringValue:string];
    [ringIDLabel setStringValue:string];
    
    return result;
}


@end
