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
#import "views/HoverTableRowView.h"

// Tags for views
#define IMAGE_TAG 100
#define DISPLAYNAME_TAG 200
#define DETAILS_TAG 300

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

    QObject::connect(CallModel::instance(),
                     &CategorizedHistoryModel::dataChanged,
                     [=](const QModelIndex &topLeft, const QModelIndex &bottomRight) {
                         [historyView reloadDataForRowIndexes:
                          [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(topLeft.row(), bottomRight.row() + 1)]
                                                      columnIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, historyView.tableColumns.count)]];
                     });
}

- (void) dealloc
{
    delete historyProxyModel;
}

- (void)placeHistoryCall:(id)sender
{
    if([[treeController selectedNodes] count] > 0) {
        auto item = [treeController selectedNodes][0];
        QModelIndex qIdx = [treeController toQIdx:item];
        if (!qIdx.parent().isValid()) {
            if ([historyView isItemExpanded:item]) {
                [[historyView animator] collapseItem:item];
            } else
                [[historyView animator] expandItem:item];
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
;
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
//	outlineViewSelectionDidChange:notification
// -------------------------------------------------------------------------------
- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    // ask the tree controller for the current selection
    //NSLog(@"outlineViewSelectionDidChange!!");
}

- (NSImage*) image:(NSImage*) img withTintedWithColor:(NSColor *)tint
{
    if (tint) {
        [img lockFocus];
        [tint set];
        NSRect imageRect = {NSZeroPoint, [img size]};
        NSRectFillUsingOperation(imageRect, NSCompositeSourceAtop);
        [img unlockFocus];
    }
    return img;
}

/* View Based OutlineView: See the delegate method -tableView:viewForTableColumn:row: in NSTableView.
 */
- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];

    NSTableCellView* result;
    if(!qIdx.parent().isValid()) {
        result = [outlineView makeViewWithIdentifier:@"CategoryCell" owner:outlineView];

    } else {
        result = [outlineView makeViewWithIdentifier:@"HistoryCell" owner:outlineView];
        NSImageView* photoView = [result viewWithTag:IMAGE_TAG];

        if (qvariant_cast<Call::Direction>(qIdx.data((int)Call::Role::Direction)) == Call::Direction::INCOMING) {
           if (qvariant_cast<Boolean>(qIdx.data((int) Call::Role::Missed))) {
               [photoView setImage:[self image:[NSImage imageNamed:@"ic_call_missed"] withTintedWithColor:[NSColor redColor]]];
            } else {
                [photoView setImage:[self image:[NSImage imageNamed:@"ic_call_received"]
                            withTintedWithColor:[NSColor colorWithCalibratedRed:116/255.0 green:179/255.0 blue:93/255.0 alpha:1.0]]];
            }
        } else {
            if (qvariant_cast<Boolean>(qIdx.data((int) Call::Role::Missed))) {
                [photoView setImage:[self image:[NSImage imageNamed:@"ic_call_missed"] withTintedWithColor:[NSColor redColor]]];
            } else {
                [photoView setImage:[self image:[NSImage imageNamed:@"ic_call_made"]
                            withTintedWithColor:[NSColor colorWithCalibratedRed:116/255.0 green:179/255.0 blue:93/255.0 alpha:1.0]]];
            }
        }

        NSTextField* details = [result viewWithTag:DETAILS_TAG];
        [details setStringValue:qIdx.data((int)Call::Role::FormattedDate).toString().toNSString()];
    }

    NSTextField* displayName = [result viewWithTag:DISPLAYNAME_TAG];
    [displayName setStringValue:qIdx.data(Qt::DisplayRole).toString().toNSString()];

    return result;
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    if(!qIdx.parent().isValid()) {
        return 35.0;
    } else {
        return 48.0;
    }
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
                    [theMenu insertItemWithTitle:NSLocalizedString(@"Add to contacts", @"Contextual menu action")
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
