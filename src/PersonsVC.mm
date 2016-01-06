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

#import "PersonsVC.h"


//Qt
#import <QSortFilterProxyModel>
#import <QtMacExtras/qmacfunctions.h>
#import <QPixmap>

//LRC
#import <person.h>
#import <personmodel.h>
#import <callmodel.h>
#import <contactmethod.h>
#import <categorizedcontactmodel.h>
#import <globalinstances.h>

#import "backends/AddressBookBackend.h"
#import "QNSTreeController.h"
#import "delegates/ImageManipulationDelegate.h"
#import "views/HoverTableRowView.h"
#import "views/ContextualTableCellView.h"

class ReachablePersonModel : public QSortFilterProxyModel
{
public:
    ReachablePersonModel(QAbstractItemModel* parent) : QSortFilterProxyModel(parent)
    {
        setSourceModel(parent);
    }
    virtual bool filterAcceptsRow(int source_row, const QModelIndex& source_parent) const
    {
        return sourceModel()->index(source_row,0,source_parent).flags() & Qt::ItemIsEnabled;
    }
};


@interface PersonsVC () {

    QNSTreeController *treeController;
    __unsafe_unretained IBOutlet NSOutlineView *personsView;
    QSortFilterProxyModel *contactProxyModel;

}

@end

@implementation PersonsVC

// Tags for views
NSInteger const IMAGE_TAG       = 100;
NSInteger const DISPLAYNAME_TAG = 200;
NSInteger const DETAILS_TAG     = 300;
NSInteger const CALL_BUTTON_TAG = 400;

-(void) awakeFromNib
{
    NSLog(@"INIT PersonsVC");
    contactProxyModel = new ReachablePersonModel(&CategorizedContactModel::instance());
    contactProxyModel->setSortRole(static_cast<int>(Qt::DisplayRole));
    contactProxyModel->sort(0,Qt::AscendingOrder);
    treeController = [[QNSTreeController alloc] initWithQModel:contactProxyModel];

    [treeController setAvoidsEmptySelection:NO];
    [treeController setChildrenKeyPath:@"children"];

    [personsView bind:@"content" toObject:treeController withKeyPath:@"arrangedObjects" options:nil];
    [personsView bind:@"sortDescriptors" toObject:treeController withKeyPath:@"sortDescriptors" options:nil];
    [personsView bind:@"selectionIndexPaths" toObject:treeController withKeyPath:@"selectionIndexPaths" options:nil];
    [personsView setTarget:self];
    [personsView setDoubleAction:@selector(callContact:)];

    CategorizedContactModel::instance().setUnreachableHidden(YES);
}

- (void) dealloc
{
    delete contactProxyModel;
}

- (IBAction)callContact:(id)sender
{
    if([[treeController selectedNodes] count] > 0) {
        auto item = [treeController selectedNodes][0];
        QModelIndex qIdx = [treeController toQIdx:item];
        ContactMethod* m = nil;
        if (!qIdx.parent().isValid()) {
            if ([personsView isItemExpanded:item]) {
                [[personsView animator] collapseItem:item];
            } else
                [[personsView animator] expandItem:item];
            return;
        }
        if(((NSTreeNode*)[treeController selectedNodes][0]).indexPath.length == 2) {
            // Person
            QVariant var = qIdx.data((int)Person::Role::Object);
            if (var.isValid()) {
                Person *c = var.value<Person*>();
                if (c->phoneNumbers().size() > 0) {
                    m = c->phoneNumbers().first();
                }
            }
        } else if (((NSTreeNode*)[treeController selectedNodes][0]).indexPath.length == 3) {
            //ContactMethod
            QVariant var = qIdx.data(static_cast<int>(ContactMethod::Role::Object));
            if (var.isValid()) {
                m = var.value<ContactMethod *>();
            }
        }

        if(m){
            Call* c = CallModel::instance().dialingCall();
            c->setPeerContactMethod(m);
            c << Call::Action::ACCEPT;
            CallModel::instance().selectCall(c);
        }
    }
}

#pragma mark - NSOutlineViewDelegate methods

// -------------------------------------------------------------------------------
//	shouldSelectItem:item
// -------------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item;
{
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    if(!qIdx.isValid())
        return NO;

    return YES;
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

/* View Based OutlineView: See the delegate method -tableView:viewForTableColumn:row: in NSTableView.
 */
- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];

    NSTableCellView *result;

    if(!qIdx.parent().isValid()) {
        result = [outlineView makeViewWithIdentifier:@"LetterCell" owner:outlineView];
        [result setWantsLayer:YES];
        [result setLayer:[CALayer layer]];
    } else if(((NSTreeNode*)item).indexPath.length == 2) {
        result = [outlineView makeViewWithIdentifier:@"PersonCell" owner:outlineView];
        NSImageView* photoView = [result viewWithTag:IMAGE_TAG];
        Person* p = qvariant_cast<Person*>(qIdx.data((int)Person::Role::Object));

        QVariant photo = GlobalInstances::pixmapManipulator().contactPhoto(p, QSize(40,40));
        [photoView setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(photo))];
        [((ContextualTableCellView*) result) setContextualsControls:[NSMutableArray arrayWithObject:[result viewWithTag:CALL_BUTTON_TAG]]];

        NSTextField* details = [result viewWithTag:DETAILS_TAG];
        if (p && p->phoneNumbers().size() > 0)
            [details setStringValue:p->phoneNumbers().first()->uri().toNSString()];
    } else {
        result = [outlineView makeViewWithIdentifier:@"ContactMethodCell" owner:outlineView];
    }

    NSTextField* displayName = [result viewWithTag:DISPLAYNAME_TAG];
    [displayName setStringValue:qIdx.data(Qt::DisplayRole).toString().toNSString()];

    return result;
}

/* View Based OutlineView: See the delegate method -tableView:rowViewForRow: in NSTableView.
 */
- (NSTableRowView *)outlineView:(NSOutlineView *)outlineView rowViewForItem:(id)item
{
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    HoverTableRowView* result = [outlineView makeViewWithIdentifier:@"HoverRowView" owner:nil];
    if(!qIdx.parent().isValid()) {
        [result setHighlightable:NO];
    } else
        [result setHighlightable:YES];

    return result;
}

- (IBAction)callClickedAtRow:(id)sender {
    NSInteger row = [personsView rowForView:sender];
    [personsView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [self callContact:nil];
}

// -------------------------------------------------------------------------------
//	outlineViewSelectionDidChange:notification
// -------------------------------------------------------------------------------
- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{

}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    return (((NSTreeNode*)item).indexPath.length == 2) ? 60.0 : 20.0;
}

@end
