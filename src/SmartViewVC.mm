/*
 *  Copyright (C) 2015-2018 Savoir-faire Linux Inc.
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

//std
#import <sstream>

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
#import "RingWindowController.h"

@interface SmartViewVC () <NSTableViewDelegate, NSTableViewDataSource, NSPopoverDelegate, ContextMenuDelegate, ContactLinkedDelegate, KeyboardShortcutDelegate> {

    NSPopover* addToContactPopover;

    //UI elements
    __unsafe_unretained IBOutlet RingTableView* smartView;
    __unsafe_unretained IBOutlet NSSearchField* searchField;
    __strong IBOutlet NSSegmentedControl *listTypeSelector;
    __strong IBOutlet NSLayoutConstraint *listTypeSelectorHeight;
    bool selectorIsPresent;

    QMetaObject::Connection modelSortedConnection_, modelUpdatedConnection_, filterChangedConnection_, newConversationConnection_, conversationRemovedConnection_, newInteractionConnection_, interactionStatusUpdatedConnection_, conversationClearedConnection;

    lrc::api::ConversationModel* convModel_;
    std::string selectedUid_;
    lrc::api::profile::Type currentFilterType;

    __unsafe_unretained IBOutlet RingWindowController *delegate;
}

@end

@implementation SmartViewVC

@synthesize tabbar;

// Tags for views
NSInteger const IMAGE_TAG           = 100;
NSInteger const DISPLAYNAME_TAG     = 200;
NSInteger const NOTIFICATONS_TAG    = 300;
NSInteger const RING_ID_LABEL       = 400;
NSInteger const PRESENCE_TAG        = 500;
NSInteger const TOTALMSGS_TAG       = 600;
NSInteger const TOTALINVITES_TAG    = 700;
NSInteger const DATE_TAG            = 800;
NSInteger const SNIPPET_TAG         = 900;
NSInteger const ADD_BUTTON_TAG            = 1000;
NSInteger const REFUSE_BUTTON_TAG         = 1100;
NSInteger const BLOCK_BUTTON_TAG          = 1200;

// Segment indices for smartlist selector
NSInteger const CONVERSATION_SEG    = 0;
NSInteger const REQUEST_SEG         = 1;

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

    currentFilterType = lrc::api::profile::Type::RING;
    selectorIsPresent = true;

    smartView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;

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
    if (convModel_ == nil)
        return;

    auto conv = convModel_->filteredConversation(row);
    convModel_->placeCall(conv.uid);
}

-(void) reloadSelectorNotifications
{
    NSTextField* totalMsgsCount = [self.view viewWithTag:TOTALMSGS_TAG];
    NSTextField* totalInvites = [self.view viewWithTag:TOTALINVITES_TAG];

    if (!selectorIsPresent) {
        [totalMsgsCount setHidden:true];
        [totalInvites setHidden:true];
        return;
    }

    auto ringConversations = convModel_->getFilteredConversations(lrc::api::profile::Type::RING);
    int totalUnreadMessages = 0;
    std::for_each(ringConversations.begin(), ringConversations.end(),
        [&totalUnreadMessages, self] (const auto& conversation) {
            totalUnreadMessages += convModel_->getNumberOfUnreadMessagesFor(conversation.uid);
        });
    [totalMsgsCount setHidden:(totalUnreadMessages == 0)];
    [totalMsgsCount setIntValue:totalUnreadMessages];

    auto totalRequests = [self chosenAccount].contactModel->pendingRequestCount();
    [totalInvites setHidden:(totalRequests == 0)];
    [totalInvites setIntValue:totalRequests];
}

-(void) reloadData
{
    NSLog(@"reload");
    [smartView deselectAll:nil];
    if (convModel_ == nil)
        return;

    [self reloadSelectorNotifications];

    if (!convModel_->owner.contactModel->hasPendingRequests()) {
        if (currentFilterType == lrc::api::profile::Type::PENDING) {
            [self selectConversationList];
        }
        if (selectorIsPresent) {
            listTypeSelectorHeight.constant = 0.0;
            [listTypeSelector setHidden:YES];
            selectorIsPresent = false;
        }
    } else {
        if (!selectorIsPresent) {
            [listTypeSelector setSelected:YES forSegment:CONVERSATION_SEG];
            listTypeSelectorHeight.constant = 18.0;
            [listTypeSelector setHidden:NO];
            selectorIsPresent = true;
        }
    }

    [smartView reloadData];

    if (!selectedUid_.empty() && convModel_ != nil) {
        auto it = getConversationFromUid(selectedUid_, *convModel_);
        if (it != convModel_->allFilteredConversations().end()) {
            NSIndexSet* indexSet = [NSIndexSet indexSetWithIndex:(it - convModel_->allFilteredConversations().begin())];
            [smartView selectRowIndexes:indexSet byExtendingSelection:NO];
        }
    }

    [smartView scrollToBeginningOfDocument:nil];
}

-(void) reloadConversationWithUid:(NSString *)uid
{
    if (convModel_ == nil) {
        return;
    }

    auto it = getConversationFromUid(std::string([uid UTF8String]), *convModel_);
    if (it != convModel_->allFilteredConversations().end()) {
        NSIndexSet* indexSet = [NSIndexSet indexSetWithIndex:(it - convModel_->allFilteredConversations().begin())];
        NSLog(@"reloadConversationWithUid: %@", uid);
        [smartView reloadDataForRowIndexes:indexSet
                             columnIndexes:[NSIndexSet indexSetWithIndex:0]];
    }
}

- (BOOL)setConversationModel:(lrc::api::ConversationModel *)conversationModel
{
    if (convModel_ == conversationModel) {
        return false;
    }

    convModel_ = conversationModel;
    selectedUid_.clear(); // Clear selected conversation as the selected account is being changed
    QObject::disconnect(modelSortedConnection_);
    QObject::disconnect(modelUpdatedConnection_);
    QObject::disconnect(filterChangedConnection_);
    QObject::disconnect(newConversationConnection_);
    QObject::disconnect(conversationRemovedConnection_);
    QObject::disconnect(conversationClearedConnection);
    QObject::disconnect(interactionStatusUpdatedConnection_);
    QObject::disconnect(newInteractionConnection_);
    [self reloadData];
    if (convModel_ != nil) {
        modelSortedConnection_ = QObject::connect(convModel_, &lrc::api::ConversationModel::modelSorted,
                                                        [self] (){
                                                            [self reloadData];
                                                        });
        modelUpdatedConnection_ = QObject::connect(convModel_, &lrc::api::ConversationModel::conversationUpdated,
                                                        [self] (const std::string& convUid){
                                                            [self reloadConversationWithUid: [NSString stringWithUTF8String:convUid.c_str()]];
                                                        });
        filterChangedConnection_ = QObject::connect(convModel_, &lrc::api::ConversationModel::filterChanged,
                                                        [self] (){
                                                            [self reloadData];
                                                        });
        newConversationConnection_ = QObject::connect(convModel_, &lrc::api::ConversationModel::newConversation,
                                                        [self] (const std::string& convUid) {
                                                            [self reloadData];
                                                            [self updateConversationForNewContact:[NSString stringWithUTF8String:convUid.c_str()]];
                                                        });
        conversationRemovedConnection_ = QObject::connect(convModel_, &lrc::api::ConversationModel::conversationRemoved,
                                                        [self] (){
                                                            [delegate listTypeChanged];
                                                            [self reloadData];
                                                        });
        conversationClearedConnection = QObject::connect(convModel_, &lrc::api::ConversationModel::conversationCleared,
                                                        [self] (const std::string& convUid){
                                                            [self deselect];
                                                            [delegate listTypeChanged];
                                                        });
        interactionStatusUpdatedConnection_ = QObject::connect(convModel_, &lrc::api::ConversationModel::interactionStatusUpdated,
                                                        [self] (const std::string& convUid) {
                                                            if (convUid != selectedUid_)
                                                                return;
                                                            [self reloadConversationWithUid: [NSString stringWithUTF8String:convUid.c_str()]];
                                                        });
        newInteractionConnection_ = QObject::connect(convModel_, &lrc::api::ConversationModel::newInteraction,
                                                        [self](const std::string& convUid, uint64_t interactionId, const lrc::api::interaction::Info& interaction){
                                                            if (convUid == selectedUid_) {
                                                                convModel_->clearUnreadInteractions(convUid);
                                                            }
                                                        });
        convModel_->setFilter(""); // Reset the filter
    }
    [searchField setStringValue:@""];
    return true;
}

-(void)selectConversation:(const lrc::api::conversation::Info&)conv model:(lrc::api::ConversationModel*)model;
{
    auto& uid = conv.uid;
    if (selectedUid_ == uid)
        return;

    [self setConversationModel:model];

    if (convModel_ == nil) {
        return;
    }

    auto it = getConversationFromUid(selectedUid_, *convModel_);
    if (it != convModel_->allFilteredConversations().end()) {
        NSIndexSet* indexSet = [NSIndexSet indexSetWithIndex:(it - convModel_->allFilteredConversations().begin())];
        [smartView selectRowIndexes:indexSet byExtendingSelection:NO];
        selectedUid_ = uid;
    }
}

-(void)deselect
{
    selectedUid_.clear();
    [smartView deselectAll:nil];
}

-(void) clearConversationModel {
    convModel_ = nil;
    [self deselect];
    [smartView reloadData];
    if (selectorIsPresent) {
        [listTypeSelector removeFromSuperview];
        selectorIsPresent = false;
    }
}

- (IBAction) listTypeChanged:(id)sender
{
    selectedUid_.clear();
    NSInteger selectedItem = [sender selectedSegment];
    switch (selectedItem) {
        case CONVERSATION_SEG:
            if (currentFilterType != lrc::api::profile::Type::RING) {
                convModel_->setFilter(lrc::api::profile::Type::RING);
                [delegate listTypeChanged];
                currentFilterType = lrc::api::profile::Type::RING;
            }
            break;
        case REQUEST_SEG:
            if (currentFilterType != lrc::api::profile::Type::PENDING) {
                convModel_->setFilter(lrc::api::profile::Type::PENDING);
                [delegate listTypeChanged];
                currentFilterType = lrc::api::profile::Type::PENDING;
            }
            break;
        default:
            NSLog(@"Invalid item selected in list selector: %d", selectedItem);
    }
}

-(void) selectConversationList
{
    if (currentFilterType == lrc::api::profile::Type::RING)
        return;
    [listTypeSelector setSelectedSegment:CONVERSATION_SEG];

    // Do not invert order of the next two lines or stack overflow
    // may happen on -(void) reloadData call if filter is currently set to PENDING
    currentFilterType = lrc::api::profile::Type::RING;
    convModel_->setFilter(lrc::api::profile::Type::RING);
    convModel_->setFilter("");
}

-(void) selectPendingList
{
    if (currentFilterType == lrc::api::profile::Type::PENDING)
        return;
    [listTypeSelector setSelectedSegment:REQUEST_SEG];

    currentFilterType = lrc::api::profile::Type::PENDING;
    convModel_->setFilter(lrc::api::profile::Type::PENDING);
    convModel_->setFilter("");
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
    NSInteger rows = [smartView numberOfRows];

    for (int i = 0; i< rows; i++) {
        NSTableRowView* cellRowView = [smartView rowViewAtRow:i makeIfNecessary:YES];
        if (i == row) {
            cellRowView.backgroundColor = [NSColor controlColor];
        } else {
            cellRowView.backgroundColor = [NSColor whiteColor];
        }
    }

    if (row == -1)
        return;
    if (convModel_ == nil)
        return;

    auto uid = convModel_->filteredConversation(row).uid;
    if (selectedUid_ != uid) {
        selectedUid_ = uid;
        convModel_->selectConversation(uid);
        convModel_->clearUnreadInteractions(uid);
        [self reloadSelectorNotifications];
    }
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    return [tableView makeViewWithIdentifier:@"HoverRowView" owner:nil];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if (convModel_ == nil)
        return nil;

    auto conversation = convModel_->filteredConversation(row);
    NSTableCellView* result;

    result = [tableView makeViewWithIdentifier:@"MainCell" owner:tableView];

    NSTextField* unreadCount = [result viewWithTag:NOTIFICATONS_TAG];
    [unreadCount setHidden:(conversation.unreadMessages == 0)];
    [unreadCount setIntValue:conversation.unreadMessages];
    NSTextField* displayName = [result viewWithTag:DISPLAYNAME_TAG];
    NSTextField* displayRingID = [result viewWithTag:RING_ID_LABEL];
    NSTextField* lastInteractionDate = [result viewWithTag:DATE_TAG];
    NSTextField* interactionSnippet = [result viewWithTag:SNIPPET_TAG];
    [displayName setStringValue:@""];
    [displayRingID setStringValue:@""];
    [lastInteractionDate setStringValue:@""];
    [interactionSnippet setStringValue:@""];
    NSImageView* photoView = [result viewWithTag:IMAGE_TAG];
    NSString* displayNameString = bestNameForConversation(conversation, *convModel_);
    NSString* displayIDString = bestIDForConversation(conversation, *convModel_);
    if(displayNameString.length == 0 || [displayNameString isEqualToString:displayIDString]) {
        [displayName setStringValue:displayIDString];
        [displayRingID setHidden:YES];
    }
    else {
        [displayName setStringValue:displayNameString];
        [displayRingID setStringValue:displayIDString];
        [displayRingID setHidden:NO];
    }
    auto& imageManip = reinterpret_cast<Interfaces::ImageManipulationDelegate&>(GlobalInstances::pixmapManipulator());
    NSImage* image = QtMac::toNSImage(qvariant_cast<QPixmap>(imageManip.conversationPhoto(conversation, convModel_->owner)));
    if(image) {
        [NSLayoutConstraint deactivateConstraints:[photoView constraints]];
        NSArray* constraints = [NSLayoutConstraint
                                constraintsWithVisualFormat:@"H:[photoView(54)]"
                                options:0
                                metrics:nil                                                                          views:NSDictionaryOfVariableBindings(photoView)];
        [NSLayoutConstraint activateConstraints:constraints];
    } else {
        [NSLayoutConstraint deactivateConstraints:[photoView constraints]];
        NSArray* constraints = [NSLayoutConstraint
                                constraintsWithVisualFormat:@"H:[photoView(0)]"
                                options:0
                                metrics:nil                                                                          views:NSDictionaryOfVariableBindings(photoView)];
        [NSLayoutConstraint activateConstraints:constraints];
    }
    [photoView setImage: image];

    NSView* presenceView = [result viewWithTag:PRESENCE_TAG];
    [presenceView setHidden:YES];
    if (!conversation.participants.empty()){
        try {
            auto contact = convModel_->owner.contactModel->getContact(conversation.participants[0]);
            if (contact.isPresent) {
                [presenceView setHidden:NO];
            }
        } catch (std::out_of_range& e) {
            NSLog(@"viewForTableColumn: getContact - out of range");
        }
    }

    NSButton* addContactButton = [result viewWithTag:ADD_BUTTON_TAG];
    NSButton* refuseContactButton = [result viewWithTag:REFUSE_BUTTON_TAG];
    NSButton* blockContactButton = [result viewWithTag:BLOCK_BUTTON_TAG];
    [addContactButton setHidden:YES];
    [refuseContactButton setHidden:YES];
    [blockContactButton setHidden:YES];

    if (profileType(conversation, *convModel_) == lrc::api::profile::Type::PENDING) {
        [lastInteractionDate setHidden:true];
        [interactionSnippet setHidden:true];
        [addContactButton setHidden:NO];
        [refuseContactButton setHidden:NO];
        [blockContactButton setHidden:NO];
        [addContactButton setAction:@selector(acceptInvitation:)];
        [addContactButton setTarget:self];
        [refuseContactButton setAction:@selector(refuseInvitation:)];
        [refuseContactButton setTarget:self];
        [blockContactButton setAction:@selector(blockPendingContact:)];
        [blockContactButton setTarget:self];
        return result;
    }

    [lastInteractionDate setHidden:false];

    [interactionSnippet setHidden:false];

    auto lastUid = conversation.lastMessageUid;
    if (conversation.interactions.find(lastUid) != conversation.interactions.end()) {
        // last interaction snippet
        std::string lastInteractionSnippet = conversation.interactions[lastUid].body;
        std::stringstream ss(lastInteractionSnippet);
        std::getline(ss, lastInteractionSnippet);
        NSString* lastInteractionSnippetFixedString = [[NSString stringWithUTF8String:lastInteractionSnippet.c_str()]
                                                       stringByReplacingOccurrencesOfString:@"🕽" withString:@""];
        lastInteractionSnippetFixedString = [lastInteractionSnippetFixedString stringByReplacingOccurrencesOfString:@"📞" withString:@""];
        if (conversation.interactions[lastUid].type == lrc::api::interaction::Type::OUTGOING_DATA_TRANSFER
            || conversation.interactions[lastUid].type == lrc::api::interaction::Type::INCOMING_DATA_TRANSFER) {
            lastInteractionSnippetFixedString = [lastInteractionSnippetFixedString lastPathComponent];
        }
        [interactionSnippet setStringValue:lastInteractionSnippetFixedString];

        // last interaction date/time
        std::time_t lastInteractionTimestamp = conversation.interactions[lastUid].timestamp;
        std::time_t now = std::time(nullptr);
        char interactionDay[64];
        char nowDay[64];
        std::strftime(interactionDay, sizeof(interactionDay), "%D", std::localtime(&lastInteractionTimestamp));
        std::strftime(nowDay, sizeof(nowDay), "%D", std::localtime(&now));
        if (std::string(interactionDay) == std::string(nowDay)) {
            char interactionTime[64];
            std::strftime(interactionTime, sizeof(interactionTime), "%R", std::localtime(&lastInteractionTimestamp));
            [lastInteractionDate setStringValue:[NSString stringWithUTF8String:interactionTime]];
        } else {
            [lastInteractionDate setStringValue:[NSString stringWithUTF8String:interactionDay]];
        }
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
    if (tableView == smartView && convModel_ != nullptr) {
        return convModel_->allFilteredConversations().size();
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
    if (convModel_ == nil)
        return;

    auto conv = convModel_->filteredConversation(row);
    auto& callId = conv.callId;

    if (callId.empty())
        return;

    auto* callModel = convModel_->owner.callModel.get();
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
    if (convModel_ == nil) {
        return;
    }

    convModel_->setFilter(std::string([[searchField stringValue] UTF8String]));
}

-(const lrc::api::account::Info&) chosenAccount
{
    return convModel_->owner;
}

- (void) clearSearchField
{
    [searchField setStringValue:@""];
    [self processSearchFieldInput];
}

-(void)updateConversationForNewContact:(NSString *)uId {
    if (convModel_ == nil) {
        return;
    }
    [self clearSearchField];
    auto uid = std::string([uId UTF8String]);
    auto it = getConversationFromUid(uid, *convModel_);
    if (it != convModel_->allFilteredConversations().end()) {
        @try {
            auto contact = convModel_->owner.contactModel->getContact(it->participants[0]);
            if (!contact.profileInfo.uri.empty() && contact.profileInfo.uri.compare(selectedUid_) == 0) {
                selectedUid_ = uid;
                convModel_->selectConversation(uid);
            }
        } @catch (NSException *exception) {
            return;
        }
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

#pragma NSTextFieldDelegate

- (BOOL)control:(NSControl *)control textView:(NSTextView *)fieldEditor doCommandBySelector:(SEL)commandSelector
{
    if (commandSelector != @selector(insertNewline:) || [[searchField stringValue] isEqual:@""]) {
        return NO;
    }
    if (convModel_ == nil) {
        [self displayErrorModalWithTitle:NSLocalizedString(@"No account available", @"Displayed as RingID when no accounts are available for selection") WithMessage:NSLocalizedString(@"Navigate to preferences to create a new account", @"Allert message when no accounts are available")];
        return NO;
    }
    if (convModel_->allFilteredConversations().size() <= 0) {
        return YES;
    }
    auto model = convModel_->filteredConversation(0);
    auto uid = model.uid;
    if (selectedUid_ == uid) {
        return YES;
    }
    @try {
        auto contact = convModel_->owner.contactModel->getContact(model.participants[0]);
        if ((contact.profileInfo.uri.empty() && contact.profileInfo.type != lrc::api::profile::Type::SIP) || contact.profileInfo.type == lrc::api::profile::Type::INVALID) {
            return YES;
        }
        selectedUid_ = uid;
        convModel_->selectConversation(uid);
        [self.view.window makeFirstResponder: smartView];
        return YES;
    } @catch (NSException *exception) {
        return YES;
    }
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
    if (convModel_ == nil)
        return ;

    auto uid = convModel_->filteredConversation([smartView selectedRow]).uid;
    convModel_->makePermanent(uid);
}

#pragma mark - ContextMenuDelegate

- (NSMenu*) contextualMenuForRow:(int) index
{
    if (convModel_ == nil)
        return nil;

    auto conversation = convModel_->filteredConversation(NSInteger(index));

    @try {
        auto contact = convModel_->owner.contactModel->getContact(conversation.participants[0]);
        if (contact.profileInfo.type == lrc::api::profile::Type::INVALID) {
            return nil;
        }

        BOOL isSIP = false;
        BOOL isRingContact = false;
        /* for SIP contact show only call menu options
         * if contact does not have uri that is not RING contact
         * for trusted Ring contact show option block contact
         * for untrasted contact show option add contact
         */

        if (contact.profileInfo.type == lrc::api::profile::Type::SIP) {
            isSIP = true;
        } else if (contact.profileInfo.uri.empty()) {
            return nil;
        }

        else if (contact.profileInfo.type == lrc::api::profile::Type::RING && contact.isTrusted == true) {
            isRingContact = true;
        }
        auto conversationUD = conversation.uid;
        NSMenu *theMenu = [[NSMenu alloc] initWithTitle:@""];
        NSString* conversationUID = @(conversationUD.c_str());
        NSMenuItem* separator = [NSMenuItem separatorItem];
        NSMenuItem* videoCallItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Place video call",
                                                                                        @"Contextual menu action")
                                                               action:@selector(videoCall:)
                                                        keyEquivalent:@""];
        NSMenuItem* audioCallItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Place audio call",
                                                                                        @"Contextual menu action")
                                                               action:@selector(audioCall:)
                                                        keyEquivalent:@""];
        [videoCallItem setRepresentedObject: conversationUID];
        [audioCallItem setRepresentedObject: conversationUID];
        [theMenu addItem:videoCallItem];
        [theMenu addItem:audioCallItem];
        if (isSIP == false) {
            [theMenu addItem:separator];
            NSMenuItem* clearConversationItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Clear conversation", @"Contextual menu action")
                                                                           action:@selector(clearConversation:)
                                                                    keyEquivalent:@""];
            [clearConversationItem setRepresentedObject: conversationUID];
            [theMenu addItem:clearConversationItem];
            if(isRingContact) {
                NSMenuItem* blockContactItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Block contact", @"Contextual menu action")
                                                                          action:@selector(blockContact:)
                                                                   keyEquivalent:@""];
                [blockContactItem setRepresentedObject: conversationUID];
                [theMenu addItem:blockContactItem];
            } else {
                NSMenuItem* addContactItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Add to contacts", @"Contextual menu action")
                                                                        action:@selector(addContact:)
                                                                 keyEquivalent:@"A"];
                [addContactItem setRepresentedObject: conversationUID];
                [theMenu addItem:addContactItem];
            }
        }
        return theMenu;
    }
    @catch (NSException *exception) {
        return nil;
    }
}

- (void) addContact: (NSMenuItem* ) item  {
    auto menuObject = item.representedObject;
    if(menuObject == nil) {
        return;
    }
    NSString * convUId = (NSString*)menuObject;
    std::string conversationID = std::string([convUId UTF8String]);
    convModel_->makePermanent(conversationID);
}

- (void) blockContact: (NSMenuItem* ) item  {
    auto menuObject = item.representedObject;
    if(menuObject == nil) {
        return;
    }
    NSString * convUId = (NSString*)menuObject;
    std::string conversationID = std::string([convUId UTF8String]);
    //convModel_->clearHistory(conversationID);
    convModel_->removeConversation(conversationID, true);
}

- (void) audioCall: (NSMenuItem* ) item  {
    auto menuObject = item.representedObject;
    if(menuObject == nil) {
        return;
    }
    NSString * convUId = (NSString*)menuObject;
    std::string conversationID = std::string([convUId UTF8String]);
    convModel_->placeAudioOnlyCall(conversationID);

}

- (void) videoCall: (NSMenuItem* ) item  {
    auto menuObject = item.representedObject;
    if(menuObject == nil) {
        return;
    }
    NSString * convUId = (NSString*)menuObject;
    std::string conversationID = std::string([convUId UTF8String]);
    convModel_->placeCall(conversationID);
}

- (void) clearConversation:(NSMenuItem* ) item  {
    auto menuObject = item.representedObject;
    if(menuObject == nil) {
        return;
    }
    NSString * convUId = (NSString*)menuObject;
    std::string conversationID = std::string([convUId UTF8String]);
    convModel_->clearHistory(conversationID);
}

- (void)acceptInvitation:(id)sender {
    NSInteger row = [smartView rowForView:sender];

    if (row == -1)
        return;
    if (convModel_ == nil)
        return;

    auto conv = convModel_->filteredConversation(row);
    auto& convID = conv.Info::uid;

    if (convID.empty())
        return;
    convModel_->makePermanent(convID);
}

- (void)refuseInvitation:(id)sender {
    NSInteger row = [smartView rowForView:sender];

    if (row == -1)
        return;
    if (convModel_ == nil)
        return;

    auto conv = convModel_->filteredConversation(row);
    auto& convID = conv.Info::uid;

    if (convID.empty())
        return;
    convModel_->removeConversation(convID);
}

- (void)blockPendingContact:(id)sender {
    NSInteger row = [smartView rowForView:sender];

    if (row == -1)
        return;
    if (convModel_ == nil)
        return;

    auto conv = convModel_->filteredConversation(row);
    auto& convID = conv.Info::uid;

    if (convID.empty())
        return;
    convModel_->removeConversation(convID, true);
    [self deselect];
    [delegate listTypeChanged];
}

@end
