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

@interface PendingContactRequestVC ()

@property QNSTreeController* requestsTreeController;
@property (unsafe_unretained) IBOutlet NSOutlineView* contactRequestView;
@end

@implementation PendingContactRequestVC

@synthesize requestsTreeController;
@synthesize account;
@synthesize contactRequestView;

//NSInteger const TAG_PHOTO       =   100;
NSInteger const TAG_NAME        =   100;
NSInteger const TAG_RINGID      =   200;

- (void)awakeFromNib
{
    requestsTreeController = [[QNSTreeController alloc] initWithQModel:account->pendingContactRequestModel()];
    [requestsTreeController setAvoidsEmptySelection:NO];
    [requestsTreeController setAlwaysUsesMultipleValuesMarker:YES];
    [requestsTreeController setChildrenKeyPath:@"children"];

    [contactRequestView bind:@"content" toObject:requestsTreeController withKeyPath:@"arrangedObjects" options:nil];
    [contactRequestView bind:@"sortDescriptors" toObject:requestsTreeController withKeyPath:@"sortDescriptors" options:nil];
    [contactRequestView bind:@"selectionIndexPaths" toObject:requestsTreeController withKeyPath:@"selectionIndexPaths" options:nil];
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
    NSTableView* result = [outlineView makeViewWithIdentifier:@"ContactRequestView" owner:self];

    QModelIndex qIdx = [self.requestsTreeController toQIdx:((NSTreeNode*)item)];
    if(!qIdx.isValid())
        return result;

    NSTextField* nameLabel = [result viewWithTag:TAG_NAME];
    NSTextField* ringIDLabel = [result viewWithTag:TAG_RINGID];

    auto trustRequest = account->pendingContactRequestModel()->data(qIdx,Qt::DisplayRole);

    NSString* string = account->pendingContactRequestModel()->data(qIdx,Qt::DisplayRole).toString().toNSString();

    [nameLabel setStringValue:string];
    [ringIDLabel setStringValue:string];
    
    return result;
}


@end
