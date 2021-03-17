/*
 *  Copyright (C) 2015-2019 Savoir-faire Linux Inc.
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

//LRC
#import <globalinstances.h>
#import <api/newaccountmodel.h>
#import <api/conversationmodel.h>
#import <api/account.h>
#import <api/contact.h>
#import <api/contactmodel.h>
#import <api/newcallmodel.h>

#import "delegates/ImageManipulationDelegate.h"
#import "views/HoverTableRowView.h"
#import "views/IconButton.h"
#import "views/RingTableView.h"
#import "views/ContextualTableCellView.h"
#import "utils.h"
#import "RingWindowController.h"

@interface SmartViewVC () <NSTableViewDelegate, NSTableViewDataSource, NSPopoverDelegate, ContextMenuDelegate, KeyboardShortcutDelegate> {

    NSPopover* addToContactPopover;

    //UI elements
    __unsafe_unretained IBOutlet RingTableView* smartView;
    __unsafe_unretained IBOutlet RingTableView* searchResultsView;
    __unsafe_unretained IBOutlet NSSearchField* searchField;
    __unsafe_unretained IBOutlet NSTextField* searchStatus;
    __unsafe_unretained IBOutlet NSBox* contactsHeader;
    __unsafe_unretained IBOutlet NSBox* searchResultHeader;
    __strong IBOutlet NSSegmentedControl *listTypeSelector;
    __strong IBOutlet NSLayoutConstraint *listTypeSelectorHeight;
    __strong IBOutlet NSLayoutConstraint *listTypeSelectorBottom;
    bool selectorIsPresent;

    QMetaObject::Connection modelSortedConnection_, modelUpdatedConnection_, filterChangedConnection_, newConversationConnection_, conversationRemovedConnection_, newInteractionConnection_, interactionStatusUpdatedConnection_, conversationClearedConnection, searchStatusChangedConnection_,
    searchResultUpdated_;

    lrc::api::ConversationModel* convModel_;
    QString selectedUid_;
    lrc::api::FilterType currentFilterType;

    __unsafe_unretained IBOutlet RingWindowController *delegate;
}

@end

@implementation SmartViewVC

@synthesize tabbar;

// Tags for views
NSInteger const IMAGE_TAG           = 100;
NSInteger const DISPLAYNAME_TAG     = 200;
NSInteger const NOTIFICATONS_TAG    = 300;
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
    currentFilterType = lrc::api::FilterType::JAMI;
    selectorIsPresent = true;
    NSFont *searchBarFont = [NSFont systemFontOfSize: 12.0 weight: NSFontWeightLight];
    NSColor *color = [NSColor secondaryLabelColor];
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    NSDictionary *searchBarAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
                                    searchBarFont, NSFontAttributeName,
                                    style, NSParagraphStyleAttributeName,
                                    color, NSForegroundColorAttributeName,
                                    nil];
    NSAttributedString* attributedName = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"Search for new or existing contact", @"search bar placeholder") attributes: searchBarAttrs];
    searchField.placeholderAttributedString = attributedName;
    smartView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;

    [searchResultsView setContextMenuDelegate:self];
    [searchResultsView setShortcutsDelegate:self];
    [searchResultsView setDoubleAction:@selector(placeCall:)];
    searchResultsView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
}

- (void)placeCall:(id)sender
{
    NSInteger row;
    if (sender != nil && [sender clickedRow] != -1)
        row = [sender clickedRow];
    else if ([smartView selectedRow] != -1)
        row = [smartView selectedRow];
    else if ([searchResultsView selectedRow] != -1)
        row = [searchResultsView selectedRow];
    else
        return;
    if (convModel_ == nil)
        return;

    auto convOpt = sender == searchResultsView ? convModel_->searchResultForRow(row) : convModel_->filteredConversation(row);
    if (!convOpt.has_value())
        return;
    convModel_->placeCall(convOpt->get().uid);
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

    auto ringConversations = convModel_->getFilteredConversations(lrc::api::FilterType::JAMI);
    int totalUnreadMessages = 0;
    std::for_each(ringConversations.get().begin(), ringConversations.get().end(),
                  [&totalUnreadMessages, self] (const auto& conversation) {
        totalUnreadMessages += conversation.get().unreadMessages;
    });
    [totalMsgsCount setHidden:(totalUnreadMessages == 0)];
    [totalMsgsCount setIntValue:totalUnreadMessages];

    auto totalRequests = [self chosenAccount].conversationModel->pendingRequestCount();
    [totalInvites setHidden:(totalRequests == 0)];
    [totalInvites setIntValue:totalRequests];
}

-(void) reloadSearchResults
{
    [searchResultHeader setHidden: convModel_->getAllSearchResults().size() == 0];
    [searchResultsView reloadData];
    [searchResultsView layoutSubtreeIfNeeded];
}


-(void) reloadData
{
    [contactsHeader setHidden: convModel_->allFilteredConversations().get().empty() || searchField.stringValue.length == 0];
    [smartView deselectAll:nil];
    if (convModel_ == nil)
        return;

    [self reloadSelectorNotifications];

    if (!convModel_->owner.conversationModel->hasPendingRequests()) {
        if (currentFilterType == lrc::api::FilterType::REQUEST) {
            [self selectConversationList];
        }
        if (selectorIsPresent) {
            listTypeSelectorHeight.constant = 0.0;
            listTypeSelectorBottom.priority = 250;
            [listTypeSelector setHidden:YES];
            selectorIsPresent = false;
        }
    } else {
        if (!selectorIsPresent) {
            [listTypeSelector setSelected:YES forSegment:CONVERSATION_SEG];
            listTypeSelectorHeight.constant = 18.0;
            listTypeSelectorBottom.priority = 999;
            [listTypeSelector setHidden:NO];
            selectorIsPresent = true;
        }
    }

    [smartView reloadData];
    [smartView layoutSubtreeIfNeeded];

    if (!selectedUid_.isEmpty() && convModel_ != nil) {
        auto index = getFilteredConversationIndexFromUid(selectedUid_, *convModel_);
        if (index >= 0) {
            NSIndexSet* indexSet = [NSIndexSet indexSetWithIndex:(index)];
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

    auto index = getFilteredConversationIndexFromUid(QString::fromNSString(uid), *convModel_);
    if (index >= 0) {
        NSIndexSet* indexSet = [NSIndexSet indexSetWithIndex:(index)];
        [smartView reloadDataForRowIndexes:indexSet
                             columnIndexes:[NSIndexSet indexSetWithIndex:0]];
        return;
    }
    index = getSearchResultIndexFromUid(QString::fromNSString(uid), *convModel_);
    if (index < 0) {
        return;
    }
    NSIndexSet* indexSet = [NSIndexSet indexSetWithIndex:(index)];
    [searchResultsView reloadDataForRowIndexes:indexSet
                                 columnIndexes:[NSIndexSet indexSetWithIndex:0]];
}

-(void) reloadConversationWithURI:(NSString *)uri
{
    if (convModel_ == nil) {
        return;
    }
    [smartView reloadData];
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
    QObject::disconnect(searchStatusChangedConnection_);
    QObject::disconnect(searchResultUpdated_);
    [self reloadData];
    [self reloadSearchResults];

    if (convModel_ != nil) {
        modelSortedConnection_ = QObject::connect(convModel_, &lrc::api::ConversationModel::modelChanged,
                                                        [self] (){
                                                            [self reloadData];
                                                        });
        searchStatusChangedConnection_ = QObject::connect(convModel_, &lrc::api::ConversationModel::searchStatusChanged,
                                                          [self](const QString &status) {
            [searchStatus setHidden:status.isEmpty()];
            auto statusString = status.toNSString();
            [searchStatus setStringValue: statusString];
                                                          });
        modelUpdatedConnection_ = QObject::connect(convModel_, &lrc::api::ConversationModel::conversationUpdated,
                                                        [self] (const QString& convUid){
                                                            [self reloadConversationWithUid: convUid.toNSString()];
                                                        });
        searchResultUpdated_ = QObject::connect(convModel_, &lrc::api::ConversationModel::searchResultUpdated,
                                                               [self] (){
                                                                   [self reloadSearchResults];
                                                               });
        filterChangedConnection_ = QObject::connect(convModel_, &lrc::api::ConversationModel::filterChanged,
                                                        [self] (){
                                                            [self reloadData];
                                                        });
        newConversationConnection_ = QObject::connect(convModel_, &lrc::api::ConversationModel::newConversation,
                                                        [self] (const QString& convUid) {
            [self reloadData];
                                                            [self updateConversationForNewContact:convUid.toNSString()];
                                                        });
        conversationRemovedConnection_ = QObject::connect(convModel_, &lrc::api::ConversationModel::conversationRemoved,
                                                        [self] (){
                                                            [delegate listTypeChanged];
                                                            [smartView noteNumberOfRowsChanged];
                                                        });
        conversationClearedConnection = QObject::connect(convModel_, &lrc::api::ConversationModel::conversationCleared,
                                                        [self] (const QString& convUid){
                                                            [self deselect];
                                                            [delegate listTypeChanged];
                                                        });
        interactionStatusUpdatedConnection_ = QObject::connect(convModel_, &lrc::api::ConversationModel::interactionStatusUpdated,
                                                        [self] (const QString& convUid, const QString& interactionId) {
                                                            if (convUid != selectedUid_)
                                                                return;
                                                            [self reloadConversationWithUid: convUid.toNSString()];
                                                        });
        newInteractionConnection_ = QObject::connect(convModel_, &lrc::api::ConversationModel::newInteraction,
                                                        [self](const QString& convUid, QString& interactionId, const lrc::api::interaction::Info& interaction){
                                                            if (convUid == selectedUid_) {
                                                                convModel_->clearUnreadInteractions(convUid);
                                                            }
                                                        });
        convModel_->setFilter(""); // Reset the filter
    }
    [searchField setStringValue:@""];
    return true;
}

-(QString)getSelectedUID {
    return selectedUid_;
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

    auto index = getFilteredConversationIndexFromUid(uid, *convModel_);
    if (index >= 0) {
        NSIndexSet* indexSet = [NSIndexSet indexSetWithIndex:index];
        [smartView selectRowIndexes:indexSet byExtendingSelection:NO];
        selectedUid_ = uid;
    } else {
        index = getSearchResultIndexFromUid(uid, *convModel_);
        if (index < 0) {
            return;
        }
        NSIndexSet* indexSet = [NSIndexSet indexSetWithIndex:(index)];
        [searchResultsView selectRowIndexes:indexSet byExtendingSelection:NO];
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
            if (currentFilterType != lrc::api::FilterType::JAMI) {
                 convModel_->setFilter(lrc::api::FilterType::JAMI);
                [delegate listTypeChanged];
                currentFilterType = lrc::api::FilterType::JAMI;
            }
            break;
        case REQUEST_SEG:
            if (currentFilterType != lrc::api::FilterType::REQUEST) {
                convModel_->setFilter(lrc::api::FilterType::REQUEST);
                [delegate listTypeChanged];
                currentFilterType = lrc::api::FilterType::REQUEST;
            }
            break;
        default:
            NSLog(@"Invalid item selected in list selector: %d", selectedItem);
    }
}

-(void) selectConversationList
{
    if (currentFilterType == lrc::api::FilterType::JAMI)
        return;
    [listTypeSelector setSelectedSegment:CONVERSATION_SEG];

    // Do not invert order of the next two lines or stack overflow
    // may happen on -(void) reloadData call if filter is currently set to PENDING
    currentFilterType = lrc::api::FilterType::JAMI;
    convModel_->setFilter(lrc::api::FilterType::JAMI);
    convModel_->setFilter("");
}

-(void) selectPendingList
{
    if (currentFilterType == lrc::api::FilterType::REQUEST)
        return;
    [listTypeSelector setSelectedSegment:REQUEST_SEG];

    currentFilterType = lrc::api::FilterType::REQUEST;
    convModel_->setFilter(lrc::api::FilterType::REQUEST);
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
    NSInteger rows = notification.object == smartView ? [smartView numberOfRows] : [searchResultsView numberOfRows];

    if (notification.object == smartView) {

        for (int i = 0; i< rows; i++) {
            HoverTableRowView* cellRowView = [smartView rowViewAtRow:i makeIfNecessary: NO];
            [cellRowView drawSelection: (i == row)];
        }

    } else {
        for (int i = 0; i< rows; i++) {
            HoverTableRowView* cellRowView = [searchResultsView rowViewAtRow:i makeIfNecessary: NO];
            [cellRowView drawSelection: (i == row)];
        }
    }
    if (row == -1)
        return;
    if (convModel_ == nil)
        return;

    auto convOpt = notification.object == smartView ? convModel_->filteredConversation(row) : convModel_->searchResultForRow(row);
    if (!convOpt.has_value())
        return;
    lrc::api::conversation::Info& conversation = *convOpt;
    if (selectedUid_ != conversation.uid && !conversation.uid.isEmpty()) {
        selectedUid_ = conversation.uid;
        convModel_->selectConversation(selectedUid_);
        convModel_->clearUnreadInteractions(selectedUid_);
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

    bool isSearching = tableView == searchResultsView;

    auto convOpt = isSearching ? convModel_->searchResultForRow(row) : convModel_->filteredConversation(row);
    if (!convOpt.has_value())
        return nil;
    lrc::api::conversation::Info& conversation = *convOpt;
    NSTableCellView* result;

    result = [tableView makeViewWithIdentifier:@"MainCell" owner:tableView];

    NSTextField* unreadCount = [result viewWithTag:NOTIFICATONS_TAG];
    [unreadCount setHidden:(conversation.unreadMessages == 0)];
    [unreadCount setIntValue:conversation.unreadMessages];
    NSTextField* displayName = [result viewWithTag:DISPLAYNAME_TAG];
    NSTextField* lastInteractionDate = [result viewWithTag:DATE_TAG];
    NSTextField* interactionSnippet = [result viewWithTag:SNIPPET_TAG];
    [displayName setStringValue:@""];
    [lastInteractionDate setStringValue:@""];
    [interactionSnippet setStringValue:@""];
    NSImageView* photoView = [result viewWithTag:IMAGE_TAG];
    NSString* displayNameString = bestNameForConversation(conversation, *convModel_);
    NSString* displayIDString = bestIDForConversation(conversation, *convModel_);
    if(displayNameString.length == 0 || [displayNameString isEqualToString:displayIDString]) {
        [displayName setStringValue:displayIDString];
    }
    else {
        [displayName setStringValue:displayNameString];
    }
    @autoreleasepool {
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
    }

    NSView* presenceView = [result viewWithTag:PRESENCE_TAG];
    [presenceView setHidden:YES];
    if (!conversation.participants.empty()){
        try {
            auto contact = convModel_->owner.contactModel->getContact(conversation.participants[0]);
            if (contact.isPresent) {
                [presenceView setHidden:NO];
            }
        } catch (std::out_of_range& e) {
            NSLog(@"contact out of range");
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
    auto callId = conversation.confId.isEmpty() ? conversation.callId : conversation.confId;
    NSString *callInfo = @"";
    if (!callId.isEmpty()) {
        if ([self chosenAccount].callModel.get()->hasCall(callId)) {
        auto call = [self chosenAccount].callModel.get()->getCall(callId);
            callInfo = (call.status == lrc::api::call::Status::IN_PROGRESS) ? @"Talking" :  to_string(call.status).toNSString();
        }
    }
    
    if (callInfo.length > 0) {
        [lastInteractionDate setStringValue: callInfo];
        [interactionSnippet setHidden:true];
        return result;
    }
    if (conversation.interactions.find(lastUid) != conversation.interactions.end()) {
        // last interaction snippet
        auto lastInteractionSnippet = conversation.interactions[lastUid].body.trimmed().replace("\r","").replace("\n","");
        NSString* lastInteractionSnippetFixedString = [lastInteractionSnippet.toNSString()
                                                       stringByReplacingOccurrencesOfString:@"🕽" withString:@""];
        lastInteractionSnippetFixedString = [lastInteractionSnippetFixedString stringByReplacingOccurrencesOfString:@"📞" withString:@""];
        if (conversation.interactions[lastUid].type == lrc::api::interaction::Type::DATA_TRANSFER) {
            lastInteractionSnippetFixedString = [lastInteractionSnippetFixedString lastPathComponent];
        }
        [interactionSnippet setStringValue:lastInteractionSnippetFixedString];

        // last interaction date/time
        NSString *timeString = @"";
        NSDate* msgTime = [NSDate dateWithTimeIntervalSince1970:conversation.interactions[lastUid].timestamp];
        NSDate *today = [NSDate date];
        NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
        [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:[[NSLocale currentLocale] localeIdentifier]]];
        if ([[NSCalendar currentCalendar] compareDate:today
                                               toDate:msgTime
                                    toUnitGranularity:NSCalendarUnitYear]!= NSOrderedSame) {
            timeString = [NSDateFormatter localizedStringFromDate:msgTime dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterNoStyle];
        } else if ([[NSCalendar currentCalendar] compareDate:today
                                                      toDate:msgTime
                                           toUnitGranularity:NSCalendarUnitDay]!= NSOrderedSame ||
                   [[NSCalendar currentCalendar] compareDate:today
                                                      toDate:msgTime
                                           toUnitGranularity:NSCalendarUnitMonth]!= NSOrderedSame) {
            timeString = [NSDateFormatter localizedStringFromDate:msgTime dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterNoStyle];
        } else {
            timeString = [NSDateFormatter localizedStringFromDate:msgTime dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterShortStyle];
        }
        [lastInteractionDate setStringValue:timeString];
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
        bool hideSmartView = convModel_->getAllSearchResults().size() > 0 && convModel_->allFilteredConversations().size() == 0;
        [[[smartView superview] superview] setHidden: hideSmartView];
        return convModel_->allFilteredConversations().size();
    }

    if (tableView == searchResultsView && convModel_ != nullptr) {
        [[[searchResultsView superview] superview] setHidden: convModel_->getAllSearchResults().size() == 0];
        return convModel_->getAllSearchResults().size();
    }
    return 0;
}

- (void)startCallForRow:(id)sender {
    NSInteger row = [smartView rowForView:sender];
    [smartView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [self placeCall:nil];
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

    convModel_->setFilter(QString::fromNSString([searchField stringValue]));
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
    auto uid = QString::fromNSString(uId);
    auto convOpt = getConversationFromUid(uid, *convModel_);
    if (!convOpt.has_value())
        return;
    lrc::api::conversation::Info& conversation = *convOpt;
    @try {
        auto contact = convModel_->owner.contactModel->getContact(conversation.participants[0]);
        if (!contact.profileInfo.uri.isEmpty() && contact.profileInfo.uri.compare(selectedUid_) == 0) {
            selectedUid_ = uid;
            convModel_->selectConversation(uid);
        }
    } @catch (NSException *exception) {
        return;
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
    if (convModel_->getAllSearchResults().size() <= 0 && convModel_->allFilteredConversations().size() <= 0) {
        return YES;
    }
    bool hasSearchResult = convModel_->getAllSearchResults().size() > 0;
    auto convOpt = hasSearchResult ? convModel_->searchResultForRow(0) : convModel_->filteredConversation(0);
    if (!convOpt.has_value())
        return NO;
    lrc::api::conversation::Info& conversation = *convOpt;
    auto uid = conversation.uid;

    if (selectedUid_ == uid) {
        return YES;
    }
    @try {
        auto contact = convModel_->owner.contactModel->getContact(conversation.participants[0]);
        if ((contact.profileInfo.uri.isEmpty() && contact.profileInfo.type != lrc::api::profile::Type::SIP) || contact.profileInfo.type == lrc::api::profile::Type::INVALID) {
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
    auto convID = [self conversationUIDFrom: [smartView selectedRow]];
    if (convID.isEmpty())
        return;
    convModel_->makePermanent(convID);
}

#pragma mark - ContextMenuDelegate

- (NSMenu*) contextualMenuForRow:(int) index table:(NSTableView*) table
{
    if (convModel_ == nil)
        return nil;

    auto convOpt = table == smartView ? convModel_->filteredConversation(NSInteger(index)) :
    convModel_->searchResultForRow(NSInteger(index));
    if (!convOpt.has_value())
        return nil;
    lrc::api::conversation::Info& conversation = *convOpt;

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
        } else if (contact.profileInfo.uri.isEmpty()) {
            return nil;
        }

        else if (contact.profileInfo.type == lrc::api::profile::Type::JAMI && contact.isTrusted == true) {
            isRingContact = true;
        }
        auto conversationUD = conversation.uid;
        NSMenu *theMenu = [[NSMenu alloc] initWithTitle:@""];
        NSString* conversationUID = conversationUD.toNSString();
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
        [theMenu addItem:separator];
        NSMenuItem* clearConversationItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Clear conversation", @"Contextual menu action")
                                                                       action:@selector(clearConversation:)
                                                                keyEquivalent:@""];
        [clearConversationItem setRepresentedObject: conversationUID];
        [theMenu addItem:clearConversationItem];
        NSMenuItem* removeContactItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Remove conversation", @"Contextual menu action")
                                                                   action:@selector(removeContact:)
                                                            keyEquivalent:@""];
        [removeContactItem setRepresentedObject: conversationUID];
        [theMenu addItem:removeContactItem];
        if(isRingContact) {
            NSMenuItem* blockContactItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Block contact", @"Contextual menu action")
                                                                      action:@selector(blockContact:)
                                                               keyEquivalent:@""];
            [blockContactItem setRepresentedObject: conversationUID];
            [theMenu addItem:blockContactItem];
        } else if (isSIP == false) {
            NSMenuItem* addContactItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Add to contacts", @"Contextual menu action")
                                                                    action:@selector(addContact:)
                                                             keyEquivalent:@"A"];
            [addContactItem setRepresentedObject: conversationUID];
            [theMenu addItem:addContactItem];
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
    QString conversationID = QString::fromNSString(convUId);
    convModel_->makePermanent(conversationID);
}

- (void) blockContact: (NSMenuItem* ) item  {
    auto menuObject = item.representedObject;
    if(menuObject == nil) {
        return;
    }
    NSString * convUId = (NSString*)menuObject;
    QString conversationID = QString::fromNSString(convUId);
    convModel_->removeConversation(conversationID, true);
}

- (void) removeContact: (NSMenuItem* ) item  {
    auto menuObject = item.representedObject;
    if(menuObject == nil) {
        return;
    }
    NSString * convUId = (NSString*)menuObject;
    QString conversationID = QString::fromNSString(convUId);
    convModel_->removeConversation(conversationID, false);
}

- (void) audioCall: (NSMenuItem* ) item  {
    auto menuObject = item.representedObject;
    if(menuObject == nil) {
        return;
    }
    NSString * convUId = (NSString*)menuObject;
    QString conversationID = QString::fromNSString(convUId);
    convModel_->placeAudioOnlyCall(conversationID);

}

- (void) videoCall: (NSMenuItem* ) item  {
    auto menuObject = item.representedObject;
    if(menuObject == nil) {
        return;
    }
    NSString * convUId = (NSString*)menuObject;
    QString conversationID = QString::fromNSString(convUId);
    convModel_->placeCall(conversationID);
}

- (void) clearConversation:(NSMenuItem* ) item  {
    auto menuObject = item.representedObject;
    if(menuObject == nil) {
        return;
    }
    NSString * convUId = (NSString*)menuObject;
    QString conversationID = QString::fromNSString(convUId);
    convModel_->clearHistory(conversationID);
}

- (void)acceptInvitation:(id)sender {
    NSInteger row = [smartView rowForView:sender];
    auto convID = [self conversationUIDFrom: row];
    if (convID.isEmpty())
        return;
    convModel_->makePermanent(convID);
}

- (void)refuseInvitation:(id)sender {
    NSInteger row = [smartView rowForView:sender];
    auto convID = [self conversationUIDFrom: row];
    if (convID.isEmpty())
        return;
    convModel_->removeConversation(convID);
}

- (void)blockPendingContact:(id)sender {
    NSInteger row = [smartView rowForView:sender];
    auto convID = [self conversationUIDFrom: row];
    if (convID.isEmpty())
        return;
    convModel_->removeConversation(convID, true);
    [self deselect];
    [delegate listTypeChanged];
}
// return convUid for given row if exists. Otherwise return an empty string
- (QString)conversationUIDFrom:(int)row {
    if (row == -1)
        return "";
    if (convModel_ == nil)
        return "";
    auto convRef = convModel_->filteredConversation(row);
    if (!convRef.has_value())
        return "";
    lrc::api::conversation::Info& conversation = *convRef;
    auto& convID = conversation.Info::uid;
    return convID;
}

@end
