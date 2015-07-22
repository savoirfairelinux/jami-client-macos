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

#import <personmodel.h>
#import <callmodel.h>
#import <categorizedcontactmodel.h>
#import <QSortFilterProxyModel>
#import <person.h>
#import <contactmethod.h>
#import <QtMacExtras/qmacfunctions.h>
#import <QPixmap>

#import "backends/AddressBookBackend.h"
#import "QNSTreeController.h"
#import "delegates/ImageManipulationDelegate.h"
#import "views/PersonCell.h"

#define COLUMNID_NAME @"NameColumn"

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


@interface PersonsVC ()

@property QNSTreeController *treeController;
@property (assign) IBOutlet NSOutlineView *personsView;
@property QSortFilterProxyModel *contactProxyModel;

@end

@implementation PersonsVC
@synthesize treeController;
@synthesize personsView;
@synthesize contactProxyModel;

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
                if (c->phoneNumbers().size() == 1) {
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
//	dataCellForTableColumn:tableColumn:item
// -------------------------------------------------------------------------------
- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    PersonCell *returnCell = [tableColumn dataCell];
    if(!qIdx.isValid())
        return returnCell;

    if(!qIdx.parent().isValid()) {
        [returnCell setDrawsBackground:YES];
        [returnCell setBackgroundColor:[NSColor selectedControlColor]];
    } else {
        [returnCell setDrawsBackground:NO];
    }

    return returnCell;
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

// -------------------------------------------------------------------------------
//	outlineView:willDisplayCell:forTableColumn:item
// -------------------------------------------------------------------------------
- (void)outlineView:(NSOutlineView *)olv willDisplayCell:(NSCell*)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    if(!qIdx.isValid())
        return;

    if ([[tableColumn identifier] isEqualToString:COLUMNID_NAME])
    {
        PersonCell *pCell = (PersonCell *)cell;
        [pCell setPersonImage:nil];
        if(!qIdx.parent().isValid()) {
            pCell.title = qIdx.data(Qt::DisplayRole).toString().toNSString();
        } else {
            pCell.title = qIdx.data(Qt::DisplayRole).toString().toNSString();
            if(((NSTreeNode*)item).indexPath.length == 2) {
                Person* p = qvariant_cast<Person*>(qIdx.data((int)Person::Role::Object));
                QVariant photo = ImageManipulationDelegate::instance()->contactPhoto(p, QSize(35,35));
                [pCell setPersonImage:QtMac::toNSImage(qvariant_cast<QPixmap>(photo))];
            }
        }
    }
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
    if(!qIdx.isValid())
        return 0.0f;

    if(!qIdx.parent().isValid()) {
        return 20.0;
    } else {
        return 45.0;
    }
}


@end
