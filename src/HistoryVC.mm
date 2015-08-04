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
#import "HistoryVC.h"

#import <categorizedhistorymodel.h>
#import <QSortFilterProxyModel>
#import <callmodel.h>
#import <call.h>
#import <person.h>
#import <contactmethod.h>
#import <localhistorycollection.h>

#import "QNSTreeController.h"
#import "PersonLinkerVC.h"

#define COLUMNID_DAY			@"DayColumn"	// the single column name in our outline view
#define COLUMNID_CONTACTMETHOD	@"ContactMethodColumn"	// the single column name in our outline view
#define COLUMNID_DATE			@"DateColumn"	// the single column name in our outline view

@interface HistoryVC() <NSPopoverDelegate, KeyboardShortcutDelegate, ContactLinkedDelegate>

@property QNSTreeController *treeController;
@property (assign) IBOutlet RingOutlineView *historyView;
@property QSortFilterProxyModel *historyProxyModel;
@property (strong) NSPopover* addToContactPopover;

@end

@implementation HistoryVC
@synthesize treeController;
@synthesize historyView;
@synthesize historyProxyModel;

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        NSLog(@"INIT HVC");
    }
    return self;
}

- (void)awakeFromNib
{
    historyProxyModel = new QSortFilterProxyModel(CategorizedHistoryModel::instance());
    historyProxyModel->setSourceModel(CategorizedHistoryModel::instance());
    historyProxyModel->setSortRole(static_cast<int>(Call::Role::Date));
    historyProxyModel->sort(0,Qt::DescendingOrder);
    treeController = [[QNSTreeController alloc] initWithQModel:historyProxyModel];

    [treeController setAvoidsEmptySelection:NO];
    [treeController setChildrenKeyPath:@"children"];

    [historyView bind:@"content" toObject:treeController withKeyPath:@"arrangedObjects" options:nil];
    [historyView bind:@"sortDescriptors" toObject:treeController withKeyPath:@"sortDescriptors" options:nil];
    [historyView bind:@"selectionIndexPaths" toObject:treeController withKeyPath:@"selectionIndexPaths" options:nil];
    [historyView setTarget:self];
    [historyView setDoubleAction:@selector(placeHistoryCall:)];
    [historyView setContextMenuDelegate:self];
    [historyView setShortcutsDelegate:self];

    CategorizedHistoryModel::instance()->addCollection<LocalHistoryCollection>(LoadOptions::FORCE_ENABLED);
}

- (void) dealloc
{
    delete historyProxyModel;
}

- (void)placeHistoryCall:(id)sender
{
    if([[treeController selectedNodes] count] > 0) {
        QModelIndex qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
        if (!qIdx.parent().isValid()) {
            return;
        }
        QVariant var = historyProxyModel->data(qIdx, (int)Call::Role::ContactMethod);
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
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    if(!qIdx.isValid())
        return;

    if ([[tableColumn identifier] isEqualToString:COLUMNID_DAY])
    {
        cell.title = historyProxyModel->data(qIdx, Qt::DisplayRole).toString().toNSString();
    } else if ([[tableColumn identifier] isEqualToString:COLUMNID_CONTACTMETHOD])
    {
        cell.title = historyProxyModel->data(qIdx, (int)Call::Role::Number).toString().toNSString();
    } else if ([[tableColumn identifier] isEqualToString:COLUMNID_DATE])
    {
        cell.title = historyProxyModel->data(qIdx, (int)Call::Role::FormattedDate).toString().toNSString();
    }
}

// -------------------------------------------------------------------------------
//	outlineViewSelectionDidChange:notification
// -------------------------------------------------------------------------------
- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    // ask the tree controller for the current selection
    //NSLog(@"outlineViewSelectionDidChange!!");
}

#pragma mark - ContextMenuDelegate

- (NSMenu*) contextualMenuForIndex:(NSIndexPath*) path
{
    if([[treeController selectedNodes] count] > 0) {
        QModelIndex qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
        const auto& var = qIdx.data(static_cast<int>(Call::Role::Object));
        if (qIdx.parent().isValid() && var.isValid()) {
            if (auto call = var.value<Call *>()) {
                auto contactmethod = call->peerContactMethod();
                if (!contactmethod->contact() || contactmethod->contact()->isPlaceHolder()) {
                    NSMenu *theMenu = [[NSMenu alloc]
                                       initWithTitle:@""];
                    [theMenu insertItemWithTitle:@"Add to contact"
                                          action:@selector(addToContact)
                                   keyEquivalent:@"a"
                                         atIndex:0];
                    return theMenu;
                }
            }
        }
    }
    return nil;
}

- (void) addToContact
{
    ContactMethod* contactmethod = nullptr;
    if([[treeController selectedNodes] count] > 0) {
        QModelIndex qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
        const auto& var = qIdx.data(static_cast<int>(Call::Role::Object));
        if (qIdx.parent().isValid() && var.isValid()) {
            if (auto call = var.value<Call *>()) {
                contactmethod = call->peerContactMethod();
            }
        }
    }

    if (self.addToContactPopover != nullptr) {
        [self.addToContactPopover performClose:self];
        self.addToContactPopover = NULL;
    } else if (contactmethod) {
        auto* editorVC = [[PersonLinkerVC alloc] initWithNibName:@"PersonLinker" bundle:nil];
        [editorVC setMethodToLink:contactmethod];
        [editorVC setContactLinkedDelegate:self];
        self.addToContactPopover = [[NSPopover alloc] init];
        [self.addToContactPopover setContentSize:editorVC.view.frame.size];
        [self.addToContactPopover setContentViewController:editorVC];
        [self.addToContactPopover setAnimates:YES];
        [self.addToContactPopover setBehavior:NSPopoverBehaviorTransient];
        [self.addToContactPopover setDelegate:self];

        [self.addToContactPopover showRelativeToRect:[historyView frameOfOutlineCellAtRow:[historyView selectedRow]] ofView:historyView preferredEdge:NSMaxXEdge];
    }
}

#pragma mark - NSPopOverDelegate

- (void)popoverDidClose:(NSNotification *)notification
{
    if (self.addToContactPopover != nullptr) {
        [self.addToContactPopover performClose:self];
        self.addToContactPopover = NULL;
    }
}

#pragma mark - ContactLinkedDelegate

- (void)contactLinked
{
    if (self.addToContactPopover != nullptr) {
        [self.addToContactPopover performClose:self];
        self.addToContactPopover = NULL;
    }
}

#pragma mark - KeyboardShortcutDelegate

- (void) onAddShortcut
{
    if([[treeController selectedNodes] count] > 0) {
        QModelIndex qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
        const auto& var = qIdx.data(static_cast<int>(Call::Role::Object));
        if (qIdx.parent().isValid() && var.isValid()) {
            if (auto call = var.value<Call *>()) {
                auto contactmethod = call->peerContactMethod();
                if (!contactmethod->contact() || contactmethod->contact()->isPlaceHolder()) {
                    [self addToContact];
                }
            }
        }
    }
}

@end
