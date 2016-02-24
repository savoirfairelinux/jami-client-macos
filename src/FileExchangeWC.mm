/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
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

#import "FileExchangeWC.h"

//Qt
#import <QItemSelectionModel>
#import <qstring.h>
#import <QPixmap>
#import <QtMacExtras/qmacfunctions.h>

//LRC
#import <filetransfermodel.h>

//Ring
#import "QNSTreeController.h"
#import "views/TransferCellView.h"


@interface FileExchangeWC () <NSOutlineViewDelegate> {

    QNSTreeController* treeController;
    __unsafe_unretained IBOutlet NSOutlineView* transfersList;

}
@end

@implementation FileExchangeWC

- (void)windowDidLoad {
    [super windowDidLoad];
    
    NSLog(@"INIT FileExchangeWC");

    treeController = [[QNSTreeController alloc] initWithQModel:&FileTransferModel::instance()];
    [treeController setAvoidsEmptySelection:NO];
    [treeController setChildrenKeyPath:@"children"];

    [transfersList bind:@"content" toObject:treeController withKeyPath:@"arrangedObjects" options:nil];
    [transfersList bind:@"sortDescriptors" toObject:treeController withKeyPath:@"sortDescriptors" options:nil];
    [transfersList bind:@"selectionIndexPaths" toObject:treeController withKeyPath:@"selectionIndexPaths" options:nil];
    [transfersList setAction:@selector(selectRow:)];
    [self.window setBackgroundColor:[NSColor whiteColor]];

    QObject::connect(FileTransferModel::instance().selectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {
                         if(!current.isValid()) {
                             [transfersList deselectAll:nil];
                             return;
                         }

                        [treeController setSelectionQModelIndex:current];
                        [transfersList scrollRowToVisible:current.row()];
                     });

    QObject::connect(&FileTransferModel::instance(),
                     &QAbstractItemModel::dataChanged,
                     [self](const QModelIndex &topLeft, const QModelIndex &bottomRight) {
                         for(int row = topLeft.row() ; row <= bottomRight.row() ; ++row)
                         {
                             [transfersList reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row]
                                                  columnIndexes:[NSIndexSet indexSetWithIndex:0]];
                         }
                     });
}

- (IBAction)cancelClickedAtRow:(id)sender {
    NSInteger row = [transfersList rowForView:sender];
    auto qIdx = FileTransferModel::instance().index(row);
    FileTransferModel::instance().cancelTransferByModelIndex(qIdx);
}

- (IBAction)acceptClickedAtRow:(id)sender {
    NSInteger row = [transfersList rowForView:sender];
    auto qIdx = FileTransferModel::instance().index(row);
    FileTransferModel::instance().acceptTransferByModelIndex(qIdx);
}

-(void) selectRow:(id)sender
{
    if ([treeController selectedNodes].count == 0) {
        FileTransferModel::instance().selectionModel()->clearCurrentIndex();
        return;
    }
    auto qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
    FileTransferModel::instance().selectionModel()->setCurrentIndex(qIdx, QItemSelectionModel::ClearAndSelect);
}


#pragma mark - NSOutlineViewDelegate methods

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item;
{
    return YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    return NO;
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    TransferCellView* result = [outlineView makeViewWithIdentifier:@"TransferView" owner:outlineView];

    [result.fileName setStringValue:qIdx.data((int)Ring::Role::DisplayRole).toString().toNSString()];

    int pro = qIdx.data((int)FileTransferModel::Role::Progress).toInt();

    [result.status setStringValue:[NSString stringWithFormat:@"%d %% - %@",pro , qIdx.data((int)Ring::Role::FormattedState).toString().toNSString()]];

    BOOL showConfirmation = qIdx.data((int)FileTransferModel::Role::isWaitingAcceptance).toBool();
    [result.progressContainer setHidden:!showConfirmation];
    [result.approvalContainer setHidden:showConfirmation];

    [result.progressBar setDoubleValue:pro];
    return result;
}

- (void)outlineView:(NSOutlineView *)outlineView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
    [outlineView scrollRowToVisible:0];
}

- (NSTableRowView *)outlineView:(NSOutlineView *)outlineView rowViewForItem:(id)item
{
    return [outlineView makeViewWithIdentifier:@"HoverRowView" owner:nil];
}

@end
