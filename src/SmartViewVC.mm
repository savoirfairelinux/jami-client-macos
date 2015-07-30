/*
 *  Copyright (C) 2015 Savoir-faire Linux Inc.
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

#import "SmartViewVC.h"

//Qt
#import <QtMacExtras/qmacfunctions.h>
#import <QPixmap>

//LRC
#import <recentmodel.h>
#import <callmodel.h>
#import <call.h>
#import <person.h>
#import <contactmethod.h>

#import "QNSTreeController.h"
#import "delegates/ImageManipulationDelegate.h"

#define COLUMNID_MAIN @"MainColumn"	// the single column name in our outline view

// Tags for views
#define IMAGE_TAG 100
#define DISPLAYNAME_TAG 200
#define DETAILS_TAG 300

@interface SmartViewVC () <NSOutlineViewDelegate>

@property (unsafe_unretained) IBOutlet NSOutlineView *smartView;
@property (unsafe_unretained) IBOutlet NSSearchField *searchField;
@property QNSTreeController *treeController;

@end

@implementation SmartViewVC
@synthesize smartView;
@synthesize treeController;

- (void)awakeFromNib
{
    NSLog(@"INIT SmartView VC");

    treeController = [[QNSTreeController alloc] initWithQModel:RecentModel::instance()];

    [treeController setAvoidsEmptySelection:NO];
    [treeController setChildrenKeyPath:@"children"];

    [smartView bind:@"content" toObject:treeController withKeyPath:@"arrangedObjects" options:nil];
    [smartView bind:@"sortDescriptors" toObject:treeController withKeyPath:@"sortDescriptors" options:nil];
    [smartView bind:@"selectionIndexPaths" toObject:treeController withKeyPath:@"selectionIndexPaths" options:nil];
    [smartView setTarget:self];
    [smartView setDoubleAction:@selector(placeCall:)];
}

- (void)placeCall:(id)sender
{
    if([[treeController selectedNodes] count] > 0) {
        QModelIndex qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
        QVariant var = RecentModel::instance()->data(qIdx, (int)Call::Role::ContactMethod);
        ContactMethod* m = qvariant_cast<ContactMethod*>(var);
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
    return YES;
}

// -------------------------------------------------------------------------------
//	dataCellForTableColumn:tableColumn:item
// -------------------------------------------------------------------------------
- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    NSCell *returnCell = [tableColumn dataCell];
    if(item == nil)
        return returnCell;
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
    if ([[tableColumn identifier] isEqualToString:COLUMNID_MAIN])
    {
        QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
        if(qIdx.isValid())
            cell.title = RecentModel::instance()->data(qIdx, Qt::DisplayRole).toString().toNSString();
    }
}

// -------------------------------------------------------------------------------
//	outlineViewSelectionDidChange:notification
// -------------------------------------------------------------------------------
- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    // ask the tree controller for the current selection
}

/* View Based OutlineView: See the delegate method -tableView:viewForTableColumn:row: in NSTableView.
 */
- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    NSTableCellView *result = [outlineView makeViewWithIdentifier:@"MainCell" owner:self];

    NSTextField* displayName = [result viewWithTag:DISPLAYNAME_TAG];
    [displayName setStringValue:qIdx.data(Qt::DisplayRole).toString().toNSString()];
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
    //QVariant photo = ImageManipulationDelegate::instance()->contactPhoto(p, QSize(35,35));
    //[pCell setPersonImage:QtMac::toNSImage(qvariant_cast<QPixmap>(photo))];
    return result;
}

/* View Based OutlineView: See the delegate method -tableView:rowViewForRow: in NSTableView.

- (NSTableRowView *)outlineView:(NSOutlineView *)outlineView rowViewForItem:(id)item
{

}
 */

/* View Based OutlineView: This delegate method can be used to know when a new 'rowView' has been added to the table. At this point, you can choose to add in extra views, or modify any properties on 'rowView'.
 */
- (void)outlineView:(NSOutlineView *)outlineView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{

}

/* View Based OutlineView: This delegate method can be used to know when 'rowView' has been removed from the table. The removed 'rowView' may be reused by the table so any additionally inserted views should be removed at this point. A 'row' parameter is included. 'row' will be '-1' for rows that are being deleted from the table and no longer have a valid row, otherwise it will be the valid row that is being removed due to it being moved off screen.
 */
- (void)outlineView:(NSOutlineView *)outlineView didRemoveRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{

}


@end
