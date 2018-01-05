/*
 *  Copyright (C) 2015-2016 Savoir-faire Linux Inc.
 *  Author: Alexandre Lision <alexandre.lision@savoirfairelinux.com>
 *  Author: Olivier Soldano <olivier.soldano@savoirfairelinux.com>
 *  Author: Anthony Léonard <anthony.leonard@savoirfairelinux.com>
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
#import <globalinstances.h>
#import <api/newaccountmodel.h>
#import <api/conversationmodel.h>
#import <api/account.h>
#import <api/contact.h>
#import <api/contactmodel.h>
#import <api/newcallmodel.h>

#import "QNSTreeController.h"
#import "delegates/ImageManipulationDelegate.h"
#import "views/HoverTableRowView.h"
#import "PersonLinkerVC.h"
#import "views/IconButton.h"
#import "views/RingTableView.h"
#import "views/ContextualTableCellView.h"
#import "utils.h"

@interface SmartViewVC () <NSTableViewDelegate, NSTableViewDataSource, NSPopoverDelegate, ContextMenuDelegate, ContactLinkedDelegate, KeyboardShortcutDelegate> {

    NSPopover* addToContactPopover;

    //UI elements
    __unsafe_unretained IBOutlet RingTableView* smartView;
    __unsafe_unretained IBOutlet NSSearchField* searchField;

    QMetaObject::Connection modelSortedConnection_, filterChangedConnection_, newConversationConnection_, conversationRemovedConnection_;

    lrc::api::ConversationModel* model_;
    std::string selectedUid_;
}

@end

@implementation SmartViewVC

@synthesize tabbar;

// Tags for views
NSInteger const IMAGE_TAG           = 100;
NSInteger const DISPLAYNAME_TAG     = 200;
NSInteger const DETAILS_TAG         = 300;
NSInteger const CALL_BUTTON_TAG     = 400;
NSInteger const TXT_BUTTON_TAG      = 500;
NSInteger const CANCEL_BUTTON_TAG   = 600;
NSInteger const RING_ID_LABEL       = 700;
NSInteger const PRESENCE_TAG        = 800;

- (void)awakeFromNib
{
    NSLog(@"INIT SmartView VC");
    //get selected account
    //encapsulate conversationmodel in local version

    [smartView setTarget:self];
    [smartView setDoubleAction:@selector(placeCall:)];

    [smartView setContextMenuDelegate:self];
    [smartView setShortcutsDelegate:self];

    [smartView setDataSource: self];

    [self.view setWantsLayer:YES];
    [self.view setLayer:[CALayer layer]];
    [self.view.layer setBackgroundColor:[NSColor whiteColor].CGColor];

    [searchField setWantsLayer:YES];
    [searchField setLayer:[CALayer layer]];
    [searchField.layer setBackgroundColor:[NSColor colorWithCalibratedRed:0.949 green:0.949 blue:0.949 alpha:0.9].CGColor];
}

- (void)placeCall:(id)sender
{
    NSInteger row;
    if (sender != nil && [sender clickedRow] != -1)
        row = [sender clickedRow];
    else if ([smartView selectedRow] != -1)
        row = [smartView selectedRow];
    else
        return;

    auto conv = model_->filteredConversation(row);
    model_->placeCall(conv.uid);
}

-(void) reloadData
{
    [smartView deselectAll:nil];
    [smartView reloadData];

    if (!selectedUid_.empty() && model_ != nil) {
        auto it = getConversationFromUid(selectedUid_, *model_);
        if (it != model_->allFilteredConversations().end()) {
            NSIndexSet* indexSet = [NSIndexSet indexSetWithIndex:(it - model_->allFilteredConversations().begin())];
            [smartView selectRowIndexes:indexSet byExtendingSelection:NO];
        } else {
            selectedUid_.clear();
        }
    }

    [smartView scrollToBeginningOfDocument:nil];
}

- (BOOL)setConversationModel:(lrc::api::ConversationModel *)conversationModel
{
    if (model_ != conversationModel) {
        model_ = conversationModel;
        selectedUid_.clear(); // Clear selected conversation as the selected account is being changed
        [self reloadData];
        QObject::disconnect(modelSortedConnection_);
        QObject::disconnect(filterChangedConnection_);
        QObject::disconnect(newConversationConnection_);
        QObject::disconnect(conversationRemovedConnection_);
        if (model_ != nil) {
            modelSortedConnection_ = QObject::connect(model_, &lrc::api::ConversationModel::modelSorted,
                                                      [self] (){
                                                          [self reloadData];
                                                      });
            filterChangedConnection_ = QObject::connect(model_, &lrc::api::ConversationModel::filterChanged,
                                                        [self] (){
                                                            [self reloadData];
                                                        });
            newConversationConnection_ = QObject::connect(model_, &lrc::api::ConversationModel::newConversation,
                                                          [self] (){
                                                              [self reloadData];
                                                          });
            conversationRemovedConnection_ = QObject::connect(model_, &lrc::api::ConversationModel::conversationRemoved,
                                                              [self] (){
                                                                  [self reloadData];
                                                              });
            model_->setFilter(""); // Reset the filter
        }
        [searchField setStringValue:@""];
        return YES;
    }
    return NO;
}

-(void)selectConversation:(const lrc::api::conversation::Info&)conv model:(lrc::api::ConversationModel*)model;
{
    auto& uid = conv.uid;
    if (selectedUid_ == uid)
        return;

    [self setConversationModel:model];

    if (model_ != nil) {
        auto it = getConversationFromUid(selectedUid_, *model_);
        if (it != model_->allFilteredConversations().end()) {
            NSIndexSet* indexSet = [NSIndexSet indexSetWithIndex:(it - model_->allFilteredConversations().begin())];
            [smartView selectRowIndexes:indexSet byExtendingSelection:NO];
            selectedUid_ = uid;
        }
    }
}

-(void)deselect
{
    selectedUid_.clear();
    [smartView deselectAll:nil];
}

#pragma mark - NSTableViewDelegate methods

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
    return YES;
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    return NO;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    NSInteger row = [notification.object selectedRow];

    if (row == -1)
        return;

    auto uid = model_->filteredConversation(row).uid;
    if (selectedUid_ != uid) {
        selectedUid_ = uid;
        model_->selectConversation(uid);
    }
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    return [tableView makeViewWithIdentifier:@"HoverRowView" owner:nil];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if (model_ == nil)
        return nil;

    auto conversation = model_->filteredConversation(row);
    NSTableCellView* result;

    result = [tableView makeViewWithIdentifier:@"MainCell" owner:tableView];
//    NSTextField* details = [result viewWithTag:DETAILS_TAG];

    NSMutableArray* controls = [NSMutableArray arrayWithObject:[result viewWithTag:CALL_BUTTON_TAG]];
    [((ContextualTableCellView*) result) setContextualsControls:controls];
    [((ContextualTableCellView*) result) setShouldBlurParentView:YES];

//    if (auto call = RecentModel::instance().getActiveCall(qIdx)) {
//        [details setStringValue:call->roleData((int)Ring::Role::FormattedState).toString().toNSString()];
//        [((ContextualTableCellView*) result) setActiveState:YES];
//    } else {
//        [details setStringValue:qIdx.data((int)Ring::Role::FormattedLastUsed).toString().toNSString()];
//        [((ContextualTableCellView*) result) setActiveState:NO];
//    }

    NSTextField* unreadCount = [result viewWithTag:TXT_BUTTON_TAG];
    [unreadCount setHidden:(conversation.unreadMessages == 0)];
    [unreadCount setIntValue:conversation.unreadMessages];

    NSTextField* displayName = [result viewWithTag:DISPLAYNAME_TAG];
    NSString* displayNameString = bestNameForConversation(conversation, *model_);
    NSString* displayIDString = bestIDForConversation(conversation, *model_);
    if(displayNameString.length == 0 || [displayNameString isEqualToString:displayIDString]) {
        NSTextField* displayRingID = [result viewWithTag:RING_ID_LABEL];
        [displayName setStringValue:displayIDString];
        [displayRingID setHidden:YES];
    }
    else {
        NSTextField* displayRingID = [result viewWithTag:RING_ID_LABEL];
        [displayName setStringValue:displayNameString];
        [displayRingID setStringValue:displayIDString];
        [displayRingID setHidden:NO];
    }
    NSImageView* photoView = [result viewWithTag:IMAGE_TAG];

    auto& imageManip = reinterpret_cast<Interfaces::ImageManipulationDelegate&>(GlobalInstances::pixmapManipulator());
    [photoView setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(imageManip.conversationPhoto(conversation, model_->owner)))];

    NSView* presenceView = [result viewWithTag:PRESENCE_TAG];
    if (model_->owner.contactModel->getContact(conversation.participants[0]).isPresent) {
        [presenceView setHidden:NO];
    } else {
        [presenceView setHidden:YES];
    }
    return result;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    return 60.0;
}

#pragma mark - NSTableDataSource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if (tableView == smartView) {
        if (model_ != nullptr)
            return model_->allFilteredConversations().size();
    }

    return 0;
}

- (void)startCallForRow:(id)sender {
    NSInteger row = [smartView rowForView:sender];
    [smartView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [self placeCall:nil];
}

- (IBAction)hangUpClickedAtRow:(id)sender {
    NSInteger row = [smartView rowForView:sender];

    if (row == -1)
        return;

    auto conv = model_->filteredConversation(row);
    auto& callId = conv.callId;

    if (callId.empty())
        return;

    auto* callModel = model_->owner.callModel.get();
    callModel->hangUp(callId);
}

- (void) displayErrorModalWithTitle:(NSString*) title WithMessage:(NSString*) message
{
    NSAlert* alert = [NSAlert alertWithMessageText:title
                                     defaultButton:@"Ok"
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:message];

    [alert beginSheetModalForWindow:self.view.window modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (void) processSearchFieldInput
{
    model_->setFilter(std::string([[searchField stringValue] UTF8String]));
}

-(const lrc::api::account::Info&) chosenAccount
{
    return model_->owner;
}

- (void) clearSearchField
{
    [searchField setStringValue:@""];
    [self processSearchFieldInput];
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

#pragma NSTextFieldDelegate

- (BOOL)control:(NSControl *)control textView:(NSTextView *)fieldEditor doCommandBySelector:(SEL)commandSelector
{
    if (commandSelector == @selector(insertNewline:)) {
        if([[searchField stringValue] isNotEqualTo:@""]) {
            [self processSearchFieldInput];
            return YES;
        }
    }
    return NO;
}

- (void)controlTextDidChange:(NSNotification *) notification
{
    [self processSearchFieldInput];
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
    if ([smartView selectedRow] == -1)
        return;

    auto uid = model_->filteredConversation([smartView selectedRow]).uid;
    model_->makePermanent(uid);
}

#pragma mark - ContextMenuDelegate

#if 0
// TODO: Reimplement contextual menu with new models and behaviors
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

        NSMenuItem* addContactItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Add to contacts", @"Contextual menu action")
                                                                action:@selector(addContactForRow:)
                                                         keyEquivalent:@""];
        [addContactItem setRepresentedObject:item];
        [theMenu addItem:addContactItem];
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
#endif

@end
