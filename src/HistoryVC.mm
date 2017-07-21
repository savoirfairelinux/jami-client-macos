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
#import "HistoryVC.h"

//Qt
#import <QSortFilterProxyModel>
#import <QtMacExtras/qmacfunctions.h>
#import <QPixmap>

//LRC
#import <categorizedhistorymodel.h>
#import <callmodel.h>
#import <call.h>
#import <person.h>
#import <contactmethod.h>
#import <globalinstances.h>
#import <personmodel.h>
#import <peerprofilecollection.h>

#import "QNSTreeController.h"
#import "PersonLinkerVC.h"
#import "views/HoverTableRowView.h"
#import "delegates/ImageManipulationDelegate.h"

@interface HistoryVC() <NSPopoverDelegate, KeyboardShortcutDelegate, ContactLinkedDelegate> {

    QNSTreeController *treeController;
    IBOutlet RingOutlineView *historyView;
    QSortFilterProxyModel *historyProxyModel;
    NSPopover* addToContactPopover;
}

@end

@implementation HistoryVC

// Tags for Views
NSInteger const DIRECTION_TAG = 100;
NSInteger const DISPLAYNAME_TAG = 200;
NSInteger const DETAILS_TAG = 300;
NSInteger const PHOTO_TAG = 400;

- (void)awakeFromNib
{
    NSLog(@"INIT HVC");
    historyProxyModel = new QSortFilterProxyModel(&CategorizedHistoryModel::instance());
    historyProxyModel->setSourceModel(&CategorizedHistoryModel::instance());
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

    QObject::connect(&CallModel::instance(),
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
            auto c = CallModel::instance().dialingCall();
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
        NSImageView* directionView = [result viewWithTag:DIRECTION_TAG];

        if (qvariant_cast<Call::Direction>(qIdx.data((int)Call::Role::Direction)) == Call::Direction::INCOMING) {
           if (qvariant_cast<Boolean>(qIdx.data((int) Call::Role::Missed))) {
               [directionView setImage:[self image:[NSImage imageNamed:@"ic_call_missed"] withTintedWithColor:[NSColor redColor]]];
            } else {
                [directionView setImage:[self image:[NSImage imageNamed:@"ic_call_received"]
                            withTintedWithColor:[NSColor colorWithCalibratedRed:116/255.0 green:179/255.0 blue:93/255.0 alpha:1.0]]];
            }
        } else {
            if (qvariant_cast<Boolean>(qIdx.data((int) Call::Role::Missed))) {
                [directionView setImage:[self image:[NSImage imageNamed:@"ic_call_missed"] withTintedWithColor:[NSColor redColor]]];
            } else {
                [directionView setImage:[self image:[NSImage imageNamed:@"ic_call_made"]
                            withTintedWithColor:[NSColor colorWithCalibratedRed:116/255.0 green:179/255.0 blue:93/255.0 alpha:1.0]]];
            }
        }

        auto call = qvariant_cast<Call*>(qIdx.data((int)Call::Role::Object));

        NSImageView* photoView = [result viewWithTag:PHOTO_TAG];
        [photoView setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(qIdx.data(Qt::DecorationRole)))];

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

- (NSMenu*) contextualMenuForIndex:(NSTreeNode*) item
{

    QModelIndex qIdx = [treeController toQIdx:item];
    if (!qIdx.isValid()) {
        return nil;
    }

    const auto& var = qIdx.data(static_cast<int>(Call::Role::Object));
    if (qIdx.parent().isValid() && var.isValid()) {
        if (auto call = var.value<Call *>()) {
            auto contactmethod = call->peerContactMethod();
            if (!contactmethod->contact() || contactmethod->contact()->isPlaceHolder()) {
                NSMenu *theMenu = [[NSMenu alloc]
                                   initWithTitle:@""];
                NSMenuItem* addContactItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Add to contacts", @"Contextual menu action")
                                                                        action:@selector(addContactForRow:)
                                                                 keyEquivalent:@""];

                [addContactItem setRepresentedObject:item];
                [theMenu addItem:addContactItem];
                return theMenu;
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

    // TODO: Uncomment to reuse contact name editing popover
//    if (addToContactPopover != nullptr) {
//        [addToContactPopover performClose:self];
//        addToContactPopover = NULL;
//    } else if (contactmethod) {
//        auto* editorVC = [[PersonLinkerVC alloc] initWithNibName:@"PersonLinker" bundle:nil];
//        [editorVC setMethodToLink:contactmethod];
//        [editorVC setContactLinkedDelegate:self];
//        addToContactPopover = [[NSPopover alloc] init];
//        [addToContactPopover setContentSize:editorVC.view.frame.size];
//        [addToContactPopover setContentViewController:editorVC];
//        [addToContactPopover setAnimates:YES];
//        [addToContactPopover setBehavior:NSPopoverBehaviorTransient];
//        [addToContactPopover setDelegate:self];
//
//        [addToContactPopover showRelativeToRect:[historyView frameOfOutlineCellAtRow:[historyView selectedRow]] ofView:historyView preferredEdge:NSMaxXEdge];
//    }

    auto* newPerson = new Person();
    newPerson->setFormattedName(contactmethod->bestName());

    Person::ContactMethods numbers;
    numbers << contactmethod;
    newPerson->setContactMethods(numbers);
    contactmethod->setPerson(newPerson);

    auto personCollections = PersonModel::instance().collections();
    CollectionInterface *peerProfileCollection = nil;
    foreach(auto collection, personCollections) {
        if(dynamic_cast<PeerProfileCollection*>(collection))
            peerProfileCollection = collection;
    }
    if(peerProfileCollection) {
        PersonModel::instance().addNewPerson(newPerson, peerProfileCollection);
    }
}

- (void) addContactForRow:(id) sender
{
    NSInteger row = [historyView rowForItem:[sender representedObject]];
    if(row < 0) {
        return;
    }
    [historyView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [self addToContact];
}

#pragma mark - NSPopOverDelegate

- (void)popoverDidClose:(NSNotification *)notification
{
    if (addToContactPopover != nullptr) {
        [addToContactPopover performClose:self];
        addToContactPopover = NULL;
    }
}

#pragma mark - ContactLinkedDelegate

- (void)contactLinked
{
    if (addToContactPopover != nullptr) {
        [addToContactPopover performClose:self];
        addToContactPopover = NULL;
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
