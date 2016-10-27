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

#import "SmartViewVC.h"

//Qt
#import <QtMacExtras/qmacfunctions.h>
#import <QPixmap>
#import <QIdentityProxyModel>
#import <QItemSelectionModel>

//LRC
#import <recentmodel.h>
#import <callmodel.h>
#import <call.h>
#import <itemdataroles.h>
#import <person.h>
#import <contactmethod.h>
#import <globalinstances.h>
#import <phonedirectorymodel.h>

#import "QNSTreeController.h"
#import "delegates/ImageManipulationDelegate.h"
#import "views/HoverTableRowView.h"
#import "PersonLinkerVC.h"
#import "views/IconButton.h"
#import "views/RingOutlineView.h"
#import "views/ContextualTableCellView.h"

@interface SmartViewVC () <NSOutlineViewDelegate, NSPopoverDelegate, ContextMenuDelegate, ContactLinkedDelegate, KeyboardShortcutDelegate> {

    QNSTreeController *treeController;
    NSPopover* addToContactPopover;

    //UI elements
    __unsafe_unretained IBOutlet RingOutlineView* smartView;
    __unsafe_unretained IBOutlet NSSearchField* searchField;
    __unsafe_unretained IBOutlet NSTabView* tabbar;
}

@end

@implementation SmartViewVC

// Tags for views
NSInteger const IMAGE_TAG           = 100;
NSInteger const DISPLAYNAME_TAG     = 200;
NSInteger const DETAILS_TAG         = 300;
NSInteger const CALL_BUTTON_TAG     = 400;
NSInteger const TXT_BUTTON_TAG      = 500;
NSInteger const CANCEL_BUTTON_TAG   = 600;

- (void)awakeFromNib
{
    NSLog(@"INIT SmartView VC");

    treeController = [[QNSTreeController alloc] initWithQModel:RecentModel::instance().peopleProxy()];
    [treeController setAvoidsEmptySelection:NO];
    [treeController setChildrenKeyPath:@"children"];

    [smartView bind:@"content" toObject:treeController withKeyPath:@"arrangedObjects" options:nil];
    [smartView bind:@"sortDescriptors" toObject:treeController withKeyPath:@"sortDescriptors" options:nil];
    [smartView bind:@"selectionIndexPaths" toObject:treeController withKeyPath:@"selectionIndexPaths" options:nil];
    [smartView setTarget:self];
    [smartView setAction:@selector(selectRow:)];
    [smartView setDoubleAction:@selector(placeCall:)];

    [smartView setContextMenuDelegate:self];
    [smartView setShortcutsDelegate:self];

    QObject::connect(RecentModel::instance().peopleProxy(),
                     &QAbstractItemModel::dataChanged,
                     [self](const QModelIndex &topLeft, const QModelIndex &bottomRight) {
                         for(int row = topLeft.row() ; row <= bottomRight.row() ; ++row)
                         {
                             [smartView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row]
                                                  columnIndexes:[NSIndexSet indexSetWithIndex:0]];
                         }
                     });

    QObject::connect(RecentModel::instance().selectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {
                         if(!current.isValid()) {
                             [smartView deselectAll:nil];
                             return;
                         }

                         auto proxyIdx = RecentModel::instance().peopleProxy()->mapFromSource(current);
                         if (proxyIdx.isValid()) {
                             [treeController setSelectionQModelIndex:proxyIdx];
                             [tabbar selectTabViewItemAtIndex:0];
                             [smartView scrollRowToVisible:proxyIdx.row()];
                         }
                     });

    QObject::connect(RecentModel::instance().peopleProxy(),
                     &QAbstractItemModel::rowsInserted,
                     [=](const QModelIndex &parent, int first, int last) {
                         Q_UNUSED(parent)
                         Q_UNUSED(first)
                         Q_UNUSED(last)
                         [smartView scrollRowToVisible:0];
                     });

    [self.view setWantsLayer:YES];
    [self.view setLayer:[CALayer layer]];
    [self.view.layer setBackgroundColor:[NSColor whiteColor].CGColor];

    [searchField setWantsLayer:YES];
    [searchField setLayer:[CALayer layer]];
    [searchField.layer setBackgroundColor:[NSColor colorWithCalibratedRed:0.949 green:0.949 blue:0.949 alpha:0.9].CGColor];
}

-(void) selectRow:(id)sender
{
    if ([treeController selectedNodes].count == 0) {
        RecentModel::instance().selectionModel()->clearCurrentIndex();
        return;
    }
    auto qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
    auto proxyIdx = RecentModel::instance().peopleProxy()->mapToSource(qIdx);
    RecentModel::instance().selectionModel()->setCurrentIndex(proxyIdx, QItemSelectionModel::ClearAndSelect);
}

- (void)placeCall:(id)sender
{
    QModelIndex qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
    ContactMethod* m = nil;

    // Double click on an ongoing call
    if (qIdx.parent().isValid()) {
        return;
    }

    if([[treeController selectedNodes] count] > 0) {
        QVariant var = qIdx.data((int)Call::Role::ContactMethod);
        m = qvariant_cast<ContactMethod*>(var);
        if (!m) {
            // test if it is a person
            QVariant var = qIdx.data((int)Person::Role::Object);
            if (var.isValid()) {
                Person *c = var.value<Person*>();
                if (c->phoneNumbers().size() > 0) {
                    m = c->phoneNumbers().first();
                }
            }
        }
    }

    // Before calling check if we properly extracted a contact method and that
    // there is NOT already an ongoing call for this index (e.g: no children for this node)
    if(m && !RecentModel::instance().peopleProxy()->index(0, 0, qIdx).isValid()){
        auto c = CallModel::instance().dialingCall();
        c->setPeerContactMethod(m);
        c << Call::Action::ACCEPT;
        CallModel::instance().selectCall(c);
    }
}

- (IBAction)showHistory:(NSButton*)sender
{
    [tabbar selectTabViewItemAtIndex:1];
}

- (IBAction)showContacts:(NSButton*)sender
{
    [tabbar selectTabViewItemAtIndex:2];
}

- (IBAction)showSmartlist:(NSButton*)sender
{
    [tabbar selectTabViewItemAtIndex:0];
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

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    if ([treeController selectedNodes].count <= 0) {
        RecentModel::instance().selectionModel()->clearCurrentIndex();
        return;
    }
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    QModelIndex proxyIdx = [treeController toQIdx:((NSTreeNode*)item)];
    QModelIndex qIdx = RecentModel::instance().peopleProxy()->mapToSource(proxyIdx);

    NSTableCellView* result;
    if (!qIdx.parent().isValid()) {
        result = [outlineView makeViewWithIdentifier:@"MainCell" owner:outlineView];
        NSTextField* details = [result viewWithTag:DETAILS_TAG];

        NSMutableArray* controls = [NSMutableArray arrayWithObject:[result viewWithTag:CALL_BUTTON_TAG]];
        [((ContextualTableCellView*) result) setContextualsControls:controls];

        if (auto call = RecentModel::instance().getActiveCall(qIdx)) {
            [details setStringValue:call->roleData((int)Ring::Role::FormattedState).toString().toNSString()];
            [((ContextualTableCellView*) result) setActiveState:YES];
        } else {
            [details setStringValue:qIdx.data((int)Ring::Role::FormattedLastUsed).toString().toNSString()];
            [((ContextualTableCellView*) result) setActiveState:NO];
        }

        NSTextField* unreadCount = [result viewWithTag:TXT_BUTTON_TAG];
        int unread = qIdx.data((int)Ring::Role::UnreadTextMessageCount).toInt();
        [unreadCount setHidden:(unread == 0)];
        [unreadCount.layer setCornerRadius:5.0f];
        [unreadCount setStringValue:qIdx.data((int)Ring::Role::UnreadTextMessageCount).toString().toNSString()];

    } else {
        result = [outlineView makeViewWithIdentifier:@"CallCell" owner:outlineView];
        NSMutableArray* controls = [NSMutableArray arrayWithObject:[result viewWithTag:CANCEL_BUTTON_TAG]];
        [((ContextualTableCellView*) result) setContextualsControls:controls];
        [((ContextualTableCellView*) result) setActiveState:NO];
        NSTextField* details = [result viewWithTag:DETAILS_TAG];

        [details setStringValue:qIdx.data((int)Call::Role::HumanStateName).toString().toNSString()];
    }

    NSTextField* displayName = [result viewWithTag:DISPLAYNAME_TAG];
    [displayName setStringValue:qIdx.data((int)Ring::Role::Name).toString().toNSString()];
    NSImageView* photoView = [result viewWithTag:IMAGE_TAG];

    [photoView setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(qIdx.data(Qt::DecorationRole)))];
    return result;
}

- (NSTableRowView *)outlineView:(NSOutlineView *)outlineView rowViewForItem:(id)item
{
    return [outlineView makeViewWithIdentifier:@"HoverRowView" owner:nil];
}

- (IBAction)callClickedAtRow:(id)sender {
    NSInteger row = [smartView rowForView:sender];
    [smartView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [self placeCall:nil];
}

- (IBAction)hangUpClickedAtRow:(id)sender {
    NSInteger row = [smartView rowForView:sender];
    id callNode = [smartView itemAtRow:row];
    auto callIdx = [treeController toQIdx:((NSTreeNode*)callNode)];

    if (callIdx.isValid()) {
        auto call = RecentModel::instance().getActiveCall(RecentModel::instance().peopleProxy()->mapToSource(callIdx));
        call << Call::Action::REFUSE;
    }
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    return (((NSTreeNode*)item).indexPath.length == 1) ? 60.0 : 50.0;
}

- (IBAction)placeCallFromSearchField:(id)sender
{
    if ([searchField stringValue].length == 0) {
        return;
    }
    auto cm = PhoneDirectoryModel::instance().getNumber(QString::fromNSString([searchField stringValue]));
    auto c = CallModel::instance().dialingCall();
    [searchField setStringValue:@""];
    RecentModel::instance().peopleProxy()->setFilterWildcard(QString::fromNSString([searchField stringValue]));
    c->setPeerContactMethod(cm);
    c << Call::Action::ACCEPT;
    CallModel::instance().selectCall(c);
}

- (void) startConversationFromSearchField
{
    auto cm = PhoneDirectoryModel::instance().getNumber(QString::fromNSString([searchField stringValue]));
    time_t currentTime;
    ::time(&currentTime);
    cm->setLastUsed(currentTime);
    [searchField setStringValue:@""];
    RecentModel::instance().peopleProxy()->setFilterWildcard(QString::fromNSString([searchField stringValue]));
    auto proxyIdx = RecentModel::instance().peopleProxy()->mapToSource(RecentModel::instance().peopleProxy()->index(0, 0));
    RecentModel::instance().selectionModel()->setCurrentIndex(proxyIdx, QItemSelectionModel::ClearAndSelect);
}

- (void) addToContact
{
    if ([treeController selectedNodes].count == 0)
        return;

    auto qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
    auto originIdx = RecentModel::instance().peopleProxy()->mapToSource(qIdx);
    auto contactmethod = RecentModel::instance().getContactMethods(originIdx);
    if (contactmethod.isEmpty())
        return;

    if (addToContactPopover != nullptr) {
        [addToContactPopover performClose:self];
        addToContactPopover = NULL;
    } else if (contactmethod.first()) {
        auto* editorVC = [[PersonLinkerVC alloc] initWithNibName:@"PersonLinker" bundle:nil];
        [editorVC setMethodToLink:contactmethod.first()];
        [editorVC setContactLinkedDelegate:self];
        addToContactPopover = [[NSPopover alloc] init];
        [addToContactPopover setContentSize:editorVC.view.frame.size];
        [addToContactPopover setContentViewController:editorVC];
        [addToContactPopover setAnimates:YES];
        [addToContactPopover setBehavior:NSPopoverBehaviorTransient];
        [addToContactPopover setDelegate:self];

        [addToContactPopover showRelativeToRect:[smartView frameOfCellAtColumn:0 row:[smartView selectedRow]]
                                         ofView:smartView preferredEdge:NSMaxXEdge];
    }
}

/**
 Copy a NSString in the general Pasteboard

 @param sender the NSObject containing the represented object to copy
 */
- (void) copyStringToPasteboard:(id) sender
{
    NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
    [pasteBoard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [pasteBoard setString:[sender representedObject] forType:NSStringPboardType];
}

- (void) callNumber:(id) sender
{
    Call* c = CallModel::instance().dialingCall();
    c->setDialNumber(QString::fromNSString([sender representedObject]));
    c << Call::Action::ACCEPT;
}

#pragma NSTextFieldDelegate

- (BOOL)control:(NSControl *)control textView:(NSTextView *)fieldEditor doCommandBySelector:(SEL)commandSelector
{
    if (commandSelector == @selector(insertNewline:)) {
        if([[searchField stringValue] isNotEqualTo:@""]) {
            [self startConversationFromSearchField];
            return YES;
        }
    }
    return NO;
}

- (void)controlTextDidChange:(NSNotification *) notification
{
    RecentModel::instance().peopleProxy()->setFilterWildcard(QString::fromNSString([searchField stringValue]));
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
    auto qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
    auto originIdx = RecentModel::instance().peopleProxy()->mapToSource(qIdx);
    auto contactmethods = RecentModel::instance().getContactMethods(originIdx);
    if (contactmethods.isEmpty())
        return;

    auto contactmethod = contactmethods.first();
    if (contactmethod && (!contactmethod->contact() || contactmethod->contact()->isPlaceHolder())) {
        [self addToContact];
    }
}

#pragma mark - ContextMenuDelegate

- (NSMenu*) contextualMenuForIndex:(NSTreeNode*) item
{
    auto qIdx = [treeController toQIdx:item];

    if (!qIdx.isValid()) {
        return nil;
    }

    auto originIdx = RecentModel::instance().peopleProxy()->mapToSource(qIdx);
    auto contactmethods = RecentModel::instance().getContactMethods(originIdx);
    if (contactmethods.isEmpty())
        return nil;

    NSMenu *theMenu = [[NSMenu alloc] initWithTitle:@""];

    if (contactmethods.size() == 1
        && !contactmethods.first()->contact()
        || contactmethods.first()->contact()->isPlaceHolder()) {

        [theMenu insertItemWithTitle:NSLocalizedString(@"Add to contacts", @"Contextual menu action")
                              action:@selector(addToContact)
                       keyEquivalent:@"a"
                             atIndex:theMenu.itemArray.count];
    } else if (auto person = contactmethods.first()->contact()) {
        NSMenuItem* copyNameItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Copy name", @"Contextual menu action")
                                                             action:@selector(copyStringToPasteboard:)
                                                      keyEquivalent:@""];

        [copyNameItem setRepresentedObject:person->formattedName().toNSString()];
        [theMenu addItem:copyNameItem];
    }

    NSMenu* copySubmenu = [[NSMenu alloc] init];
    NSMenu* callSubmenu = [[NSMenu alloc] init];

    for (auto cm : contactmethods) {
        NSMenuItem* tmpCopyItem = [[NSMenuItem alloc] initWithTitle:cm->uri().toNSString()
                                                             action:@selector(copyStringToPasteboard:)
                                                      keyEquivalent:@""];

        [tmpCopyItem setRepresentedObject:cm->uri().toNSString()];
        [copySubmenu addItem:tmpCopyItem];

        NSMenuItem* tmpCallItem = [[NSMenuItem alloc] initWithTitle:cm->uri().toNSString()
                                                             action:@selector(callNumber:)
                                                      keyEquivalent:@""];
        [tmpCallItem setRepresentedObject:cm->uri().toNSString()];
        [callSubmenu addItem:tmpCallItem];
    }

    NSMenuItem* copyNumberItem = [[NSMenuItem alloc] init];
    [copyNumberItem setTitle:NSLocalizedString(@"Copy number", @"Contextual menu action")];
    [copyNumberItem setSubmenu:copySubmenu];

    NSMenuItem* callItems = [[NSMenuItem alloc] init];
    [callItems setTitle:NSLocalizedString(@"Call number", @"Contextual menu action")];
    [callItems setSubmenu:callSubmenu];

    [theMenu insertItem:copyNumberItem atIndex:theMenu.itemArray.count];
    [theMenu insertItem:[NSMenuItem separatorItem] atIndex:theMenu.itemArray.count];
    [theMenu insertItem:callItems atIndex:theMenu.itemArray.count];

    return theMenu;
}

@end
