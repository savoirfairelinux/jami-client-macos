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
#import "ConversationsViewController.h"

#import <callmodel.h>
#import <QtCore/qitemselectionmodel.h>

#import "CurrentCallVC.h"

#define COLUMNID_CONVERSATIONS @"ConversationsColumn"	// the single column name in our outline view

@interface ConversationsViewController ()

@property CurrentCallVC* currentVC;
@property (assign) IBOutlet NSView *currentCallView;
@property (assign) IBOutlet NSTextField *callBar;

@end

@implementation ConversationsViewController
@synthesize conversationsView;
@synthesize treeController;
@synthesize currentVC;
@synthesize currentCallView;
@synthesize callBar;

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        NSLog(@"INIT Conversations VC");
    }

    [self connectSlots];
    return self;
}

- (void) connectSlots
{
    CallModel* callModel_ = CallModel::instance();
    QObject::connect(callModel_, &CallModel::callStateChanged, [](Call*, Call::State) {
        NSLog(@"callStateChanged");
    });

    QObject::connect(callModel_, &CallModel::incomingCall, [self] (Call* c) {
        [currentVC displayCall:c];
    });
}

- (void)awakeFromNib
{
    NSLog(@"awakeFromNib");

    treeController = [[QNSTreeController alloc] initWithQModel:CallModel::instance()];

    [treeController setAvoidsEmptySelection:NO];
    [treeController setChildrenKeyPath:@"children"];

    [self.conversationsView bind:@"content" toObject:treeController withKeyPath:@"arrangedObjects" options:nil];
    [self.conversationsView bind:@"sortDescriptors" toObject:treeController withKeyPath:@"sortDescriptors" options:nil];
    [self.conversationsView bind:@"selectionIndexPaths" toObject:treeController withKeyPath:@"selectionIndexPaths" options:nil];

    NSInteger idx = [conversationsView columnWithIdentifier:COLUMNID_CONVERSATIONS];
    [[[[self.conversationsView tableColumns] objectAtIndex:idx] headerCell] setStringValue:@"Conversations"];


    // NOW THE CURRENT CALL VIEW
    currentVC = [[CurrentCallVC alloc] initWithNibName:@"CurrentCall" bundle:nil];
    [currentCallView addSubview:[self.currentVC view]];
    [self.currentVC initFrame];
}

- (IBAction)placeCall:(id)sender {

    Call* c = CallModel::instance()->dialingCall();
    c->setDialNumber(QString::fromNSString([callBar stringValue]));
    c << Call::Action::ACCEPT;
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
    if ([[tableColumn identifier] isEqualToString:COLUMNID_CONVERSATIONS])
    {

        NSIndexPath* idx = ((NSTreeNode*)item).indexPath;
        NSUInteger myArray[[idx length]];
        [idx getIndexes:myArray];

        NSLog(@"dataCellForTableColumn, indexPath: %lu", (unsigned long)myArray[0]);

        QModelIndex qIdx = CallModel::instance()->index(myArray[0], 0);

        QVariant test = CallModel::instance()->data(qIdx, Qt::DisplayRole);
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
    NSLog(@"outlineViewSelectionDidChange!!");
    if([[treeController selectedNodes] count] > 0) {
        QModelIndex qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
        //Update details view
        Call* toDisplay = CallModel::instance()->getCall(qIdx);

        CallModel::instance()->selectionModel()->setCurrentIndex(qIdx, QItemSelectionModel::ClearAndSelect);
        [currentVC displayCall:toDisplay];
    } else {
        [currentVC hideWithAnimation:YES];
        CallModel::instance()->selectionModel()->clearCurrentIndex();
    }
}


@end
