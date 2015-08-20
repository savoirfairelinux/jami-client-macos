/*
 *  Copyright (C) 2004-2015 Savoir-Faire Linux Inc.
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
 *
 *  Additional permission under GNU GPL version 3 section 7:
 *
 *  If you modify this program, or any covered work, by linking or
 *  combining it with the OpenSSL project's OpenSSL library (or a
 *  modified version of that library), containing parts covered by the
 *  terms of the OpenSSL or SSLeay licenses, Savoir-Faire Linux Inc.
 *  grants you additional permission to convey the resulting work.
 *  Corresponding Source for a non-source form of such a combination
 *  shall include the source code for the parts of OpenSSL used as well
 *  as that of the covered work.
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

#import "backends/AddressBookBackend.h"
#import "QNSTreeController.h"
#import "delegates/ImageManipulationDelegate.h"

// Tags for views
#define IMAGE_TAG 100
#define DISPLAYNAME_TAG 200
#define DETAILS_TAG 300
#define CALL_BUTTON_TAG 400

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

-(void) awakeFromNib
{
    new ImageManipulationDelegate();
    NSLog(@"INIT PersonsVC");
    contactProxyModel = new ReachablePersonModel(CategorizedContactModel::instance());
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

    CategorizedContactModel::instance()->setUnreachableHidden(YES);
}

- (void) dealloc
{
    delete contactProxyModel;
}

- (IBAction)callContact:(id)sender
{
    if([[treeController selectedNodes] count] > 0) {
        QModelIndex qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
        ContactMethod* m = nil;
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
            Call* c = CallModel::instance()->dialingCall();
            c->setPeerContactMethod(m);
            c->setDialNumber(m);
            c << Call::Action::ACCEPT;
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

    if(!qIdx.parent().isValid()) {
        return NO;
    } else {
        return YES;
    }
}

// -------------------------------------------------------------------------------
//	textShouldEndEditing:fieldEditor
// -------------------------------------------------------------------------------
- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
    if ([[fieldEditor string] length] == 0)
    {
        // don't allow empty node names
        return NO;
    }
    else
    {
        return YES;
    }
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
        result = [outlineView makeViewWithIdentifier:@"CategoryCell" owner:outlineView];
        [result setWantsLayer:YES];
        [result setLayer:[CALayer layer]];
        [result.layer setBackgroundColor:[NSColor selectedControlColor].CGColor];
    } else if(((NSTreeNode*)item).indexPath.length == 2) {
        result = [outlineView makeViewWithIdentifier:@"MainCell" owner:outlineView];
        NSImageView* photoView = [result viewWithTag:IMAGE_TAG];
        Person* p = qvariant_cast<Person*>(qIdx.data((int)Person::Role::Object));
        if (p) {
            QVariant photo = ImageManipulationDelegate::instance()->contactPhoto(p, QSize(35,35));
            [photoView setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(photo))];
        } else {
            ImageManipulationDelegate* delegate = (ImageManipulationDelegate*) ImageManipulationDelegate::instance();
            QVariant photo = delegate->defaultUserPixmap(QSize(35,35));
            [photoView setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(photo))];
        }
        NSTextField* details = [result viewWithTag:DETAILS_TAG];
        [details setStringValue:@""];
    } else {
        result = [outlineView makeViewWithIdentifier:@"ContactMethodCell" owner:outlineView];
    }

    NSTextField* displayName = [result viewWithTag:DISPLAYNAME_TAG];
    [displayName setStringValue:qIdx.data(Qt::DisplayRole).toString().toNSString()];

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
