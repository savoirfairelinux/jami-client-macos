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
#import "ConversationsVC.h"

#import <callmodel.h>
#import <QtCore/qitemselectionmodel.h>

#define COLUMNID_CONVERSATIONS @"ConversationsColumn"	// the single column name in our outline view

@interface ConversationsVC ()

@property QNSTreeController *treeController;
@property (assign) IBOutlet NSOutlineView *conversationsView;

@end

@implementation ConversationsVC
@synthesize conversationsView;
@synthesize treeController;
- (void)awakeFromNib
{
    NSLog(@"INIT Conversations VC");

    treeController = [[QNSTreeController alloc] initWithQModel:CallModel::instance()];

    [treeController setAvoidsEmptySelection:NO];
    [treeController setChildrenKeyPath:@"children"];

    [self.conversationsView bind:@"content" toObject:treeController withKeyPath:@"arrangedObjects" options:nil];
    [self.conversationsView bind:@"sortDescriptors" toObject:treeController withKeyPath:@"sortDescriptors" options:nil];
    [self.conversationsView bind:@"selectionIndexPaths" toObject:treeController withKeyPath:@"selectionIndexPaths" options:nil];

    NSInteger idx = [conversationsView columnWithIdentifier:COLUMNID_CONVERSATIONS];
    [[[[self.conversationsView tableColumns] objectAtIndex:idx] headerCell] setStringValue:@"Conversations"];

    QObject::connect(CallModel::instance(),
                     &QAbstractItemModel::dataChanged,
                     [=](const QModelIndex &topLeft, const QModelIndex &bottomRight) {
                         [conversationsView reloadDataForRowIndexes:
                          [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(topLeft.row(), bottomRight.row() + 1)]
                        columnIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, conversationsView.tableColumns.count)]];
                     });
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
    if ([[tableColumn identifier] isEqualToString:COLUMNID_CONVERSATIONS])
    {
        QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
        if(qIdx.isValid())
            cell.title = CallModel::instance()->data(qIdx, Qt::DisplayRole).toString().toNSString();
    }
}

// -------------------------------------------------------------------------------
//	outlineViewSelectionDidChange:notification
// -------------------------------------------------------------------------------
- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    // ask the tree controller for the current selection
    if([[treeController selectedNodes] count] > 0) {
        QModelIndex qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
        //Update details view by changing selection
        CallModel::instance()->selectionModel()->setCurrentIndex(qIdx, QItemSelectionModel::ClearAndSelect);
    } else {
        CallModel::instance()->selectionModel()->clearCurrentIndex();
    }
}


@end
