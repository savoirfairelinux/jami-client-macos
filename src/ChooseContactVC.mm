/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

#import "ChooseContactVC.h"
#import "views/RingTableView.h"
#import "views/HoverTableRowView.h"
#import "utils.h"
#import "delegates/ImageManipulationDelegate.h"

//LRC
#import <globalinstances.h>
#import <api/conversationmodel.h>
#import <api/account.h>
#import <api/newaccountmodel.h>
#import <api/contactmodel.h>
#import <api/contact.h>

//Qt
#import <QtMacExtras/qmacfunctions.h>
#import <QPixmap>

@interface ChooseContactVC () {
    __unsafe_unretained IBOutlet RingTableView* contactsView;
    __unsafe_unretained IBOutlet RingTableView* callsView;
    __unsafe_unretained IBOutlet NSSearchField* searchField;
    __unsafe_unretained IBOutlet NSLayoutConstraint* contactsViewHeightConstraint;
    __unsafe_unretained IBOutlet NSLayoutConstraint* calsViewHeightConstraint;
    __unsafe_unretained IBOutlet NSStackView* callsContainer;
    __unsafe_unretained IBOutlet NSStackView* contactsContainer;
    __unsafe_unretained IBOutlet NSTextField* contactsLabel;
}

@end

@implementation ChooseContactVC

lrc::api::ConversationModel* convModel;
lrc::api::NewAccountModel* accountModel;
QString currentConversation;
QString accountId;
ContactPickerType type;

QMap<lrc::api::ConferenceableItem, lrc::api::ConferenceableValue> values;
QList<lrc::api::contact::Info> contacts;

// Tags for views
NSInteger const IMAGE_TAG           = 100;
NSInteger const DISPLAYNAME_TAG     = 200;
NSInteger const RING_ID_LABEL       = 300;
NSInteger const PRESENCE_TAG        = 400;

NSInteger const ROW_HEIGHT = 60;
NSInteger const MINIMUM_TABLE_SIZE = 0;
NSInteger const NORMAL_TABLE_SIZE = 120;
NSInteger const MAXIMUM_TABLE_SIZE = 240;

- (void)setUpCpntactPickerwithModel:(lrc::api::NewAccountModel *) newaccountModel andAccountId:(const QString&)account{
    accountId = account;
    accountModel = newaccountModel;
    type = FROM_CONTACT;
    [self updateModerators];
    [self reloadView];
}

- (void)setUpForConference:(lrc::api::ConversationModel *)conversationModel
      andCurrentConversation:(const QString&)conversation
{
    type = FROM_CONFERENCABLE_ITEM;
    convModel = conversationModel;
    if (convModel == nil) {
        return;
    }
    currentConversation = conversation;
    values = convModel->getConferenceableConversations(currentConversation, "");
    [self reloadView];
}

- (void)controlTextDidChange:(NSNotification *) notification
{
    if (type == FROM_CONTACT) {
        auto allContacts = accountModel->getAccountInfo(accountId).contactModel->getAllContacts();
        auto moderators = accountModel->getDefaultModerators(accountId);
        contacts.clear();
        auto filter = QString::fromNSString(searchField.stringValue);
        for (auto contact : allContacts.values()) {
            if ((contact.registeredName.contains(filter) || contact.profileInfo.alias.contains(filter)) && !moderators.contains(contact.profileInfo.uri)) {
                contacts.append(contact);
            }
        }
        [self reloadView];
        return;
    }
    values = convModel->getConferenceableConversations(currentConversation, QString::fromNSString(searchField.stringValue));
    [self reloadView];
}

- (void) reloadView
{
    [callsView reloadData];
    [contactsView reloadData];
    if (type == FROM_CONTACT) {
        [callsContainer setHidden: YES];
        contactsViewHeightConstraint.constant = MAXIMUM_TABLE_SIZE + 35;
        calsViewHeightConstraint.constant = 0;
        [contactsLabel setHidden: YES];
        return;
    }
    auto callsSize = [callsView numberOfRows] * ROW_HEIGHT;
    auto contactsSize = [contactsView numberOfRows] * ROW_HEIGHT;
    if (callsSize >= NORMAL_TABLE_SIZE) {
        if (contactsSize >= NORMAL_TABLE_SIZE) {
            contactsViewHeightConstraint.constant = NORMAL_TABLE_SIZE;
            calsViewHeightConstraint.constant = NORMAL_TABLE_SIZE;
        } else {
            contactsViewHeightConstraint.constant = contactsSize;
            calsViewHeightConstraint.constant = MAXIMUM_TABLE_SIZE - contactsSize;
        }
    } else if (callsSize == MINIMUM_TABLE_SIZE) {
        // when call stack view is hidden add 35 to avoid controller size changes
        // 17 - call label height + 8*2 stack view margins
        contactsViewHeightConstraint.constant = MAXIMUM_TABLE_SIZE + 35;
        calsViewHeightConstraint.constant = callsSize;
    } else {
        contactsViewHeightConstraint.constant = MAXIMUM_TABLE_SIZE - callsSize;
        calsViewHeightConstraint.constant = callsSize;
    }

    [callsContainer setHidden: callsSize == 0];
    [contactsLabel setHidden: contactsSize == 0];
}

-(void)viewDidLoad {
    [super viewDidLoad];
    if (@available(macOS 11.0, *)) {
        contactsView.style = NSTableViewStylePlain;
        callsView.style = NSTableViewStylePlain;
    }
    [self reloadView];
}

-(void) updateModerators {
    auto allContacts = accountModel->getAccountInfo(accountId).contactModel->getAllContacts();
    auto moderators = accountModel->getDefaultModerators(accountId);
    for (auto moderator : moderators) {
        if (allContacts.find(moderator) != allContacts.end()) {
            allContacts.remove(moderator);
        }
    }
    contacts = allContacts.values();
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
    NSTableView *table = notification.object;

    NSInteger rows = [table numberOfRows];
    for (int i = 0; i< rows; i++) {
        HoverTableRowView* cellRowView = [table rowViewAtRow:i makeIfNecessary: NO];
        [cellRowView drawSelection: (i == row)];
    }
    if (type == FROM_CONTACT) {
        [self chooseContactForRow:row];
        return;
    }
    if (row == -1 || convModel == nil)
        return;
    QVector<QVector<lrc::api::AccountConversation>> conversations = table == callsView ? values.value(lrc::api::ConferenceableItem::CALL) : values.value(lrc::api::ConferenceableItem::CONTACT);
    if (conversations.size() < row) {
        return;
    }
    QVector<lrc::api::AccountConversation> participants = conversations[row];
    if (participants.isEmpty()) {
        return;
    }
    auto conversation = participants[0];
    auto accountID = conversation.accountId;
    auto convID = conversation.convId;
    auto convMod = convModel->owner.accountModel->getAccountInfo(accountID).conversationModel.get();
    auto conversationInfo = convMod->getConversationForUid(convID);
    if (!conversationInfo.has_value()) {
        return;
    }
    lrc::api::conversation::Info& conv = *conversationInfo;
    if (table == callsView) {
        auto callID = conv.confId.isEmpty() ? conv.callId : conv.confId;
        if ([self.delegate respondsToSelector: @selector(joinCall:)]) {
            [self.delegate joinCall: callID];
        }
    } else if (table == contactsView) {
        auto uid = conv.participants.front();
        if ([self.delegate respondsToSelector: @selector(joinCall:)]) {
            [self.delegate callToContact:uid convUID: convID];
        }
    }
}

-(void)chooseContactForRow:(NSInteger) row {
    if (row < 0 ||  row >= contacts.size()) {
        return;
    }
    auto contact = contacts[row];
    if ([self.delegate respondsToSelector: @selector(contactChosen:)]) {
        [self.delegate contactChosen: contact.profileInfo.uri];
        [self updateModerators];
        NSIndexSet *indexes = [[NSIndexSet alloc] initWithIndex:row];
        [contactsView removeRowsAtIndexes:indexes withAnimation: NSTableViewAnimationSlideUp];
    }
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    HoverTableRowView *howerRow = [tableView makeViewWithIdentifier:@"HoverRowView" owner:nil];
    [howerRow setBlurType:7];
    return howerRow;
}

-(NSView *)configureContactRowForRow:(NSInteger)row tableView:(NSTableView*)tableView {
    if (tableView != contactsView || row < 0 ||  row >= contacts.size()) {
        return nil;
    }
    NSTableCellView* result = [tableView makeViewWithIdentifier:@"MainCell" owner:tableView];

    NSTextField* displayName = [result viewWithTag:DISPLAYNAME_TAG];
    NSTextField* displayRingID = [result viewWithTag:RING_ID_LABEL];
    NSImageView* photoView = [result viewWithTag:IMAGE_TAG];
    NSView* presenceView = [result viewWithTag:PRESENCE_TAG];
    [presenceView setHidden:YES];
    auto contact = contacts[row];

    auto convOpt = getConversationFromURI(contact.profileInfo.uri, *accountModel->getAccountInfo(accountId).conversationModel);
    if (convOpt.has_value()) {
        lrc::api::conversation::Info& conversation = *convOpt;
        auto& imageManip = reinterpret_cast<Interfaces::ImageManipulationDelegate&>(GlobalInstances::pixmapManipulator());
        NSImage* image = QtMac::toNSImage(qvariant_cast<QPixmap>(imageManip.conversationPhoto(conversation, accountModel->getAccountInfo(accountId))));
        if(image) {
            photoView.wantsLayer = YES;
            photoView.layer.cornerRadius = photoView.frame.size.width * 0.5;
        [photoView setImage:image];
        }
    }
    [displayRingID setStringValue: bestIDForContact(contact)];
    [displayName setStringValue: bestNameForContact(contact)];
    return result;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if (type == FROM_CONTACT) {
        return [self configureContactRowForRow:row tableView: tableView];
    }
    if (convModel == nil)
        return nil;

    QVector<QVector<lrc::api::AccountConversation>> allConversations;
    if (tableView == callsView && convModel != nullptr) {
        allConversations = values.value(lrc::api::ConferenceableItem::CALL);
    } else if (tableView == contactsView && convModel != nullptr) {
        allConversations = values.value(lrc::api::ConferenceableItem::CONTACT);
    }
    if (allConversations.size() < row) {
        return nil;
    }

    QVector<lrc::api::AccountConversation> conversations = allConversations[row];
    if (conversations.size() < 1) {
        return nil;
    }

    NSTableCellView* result = [tableView makeViewWithIdentifier:@"MainCell" owner:tableView];

    NSTextField* displayName = [result viewWithTag:DISPLAYNAME_TAG];
    NSTextField* displayRingID = [result viewWithTag:RING_ID_LABEL];
    NSImageView* photoView = [result viewWithTag:IMAGE_TAG];
    NSView* presenceView = [result viewWithTag:PRESENCE_TAG];

    [displayName setStringValue:@""];
    [displayRingID setStringValue:@""];
    [photoView setHidden: YES];
    [presenceView setHidden:YES];

    // setup conference cell
    if(conversations.size() > 1) {
        NSString* displayNameString = @"";
        for (auto conversation : conversations) {
            auto accountID = conversation.accountId;
            auto convID = conversation.convId;
            auto convMod = convModel->owner.accountModel->getAccountInfo(accountID).conversationModel.get();
            auto conversationOpt = getConversationFromUid(convID, *convMod);
            if (!conversationOpt.has_value()) {
                return nil;
            }
            if (displayNameString.length > 0) {
                displayNameString = [displayNameString stringByAppendingString:@", "];
            }
            lrc::api::conversation::Info& conv = *conversationOpt;
            displayNameString = [displayNameString stringByAppendingString: bestNameForConversation(conv, *convMod)];
        }
        [displayName setStringValue:displayNameString];
        [NSLayoutConstraint deactivateConstraints:[photoView constraints]];
        NSArray* constraints = [NSLayoutConstraint
                                constraintsWithVisualFormat:@"H:[photoView(0)]"
                                options:0
                                metrics:nil                                                                          views:NSDictionaryOfVariableBindings(photoView)];
        [NSLayoutConstraint activateConstraints:constraints];
        return result;
    }

    lrc::api::AccountConversation conversation = conversations.front();
    auto accountID = conversation.accountId;
    auto convID = conversation.convId;
    auto convMod = convModel->owner.accountModel->getAccountInfo(accountID).conversationModel.get();
    auto convOpt = getConversationFromUid(convID, *convMod);
    if (!convOpt.has_value()) {
        return nil;
    }
    lrc::api::conversation::Info& conversationInfo = *convOpt;
    NSString* displayNameString = bestNameForConversation(conversationInfo, *convMod);
    NSString* displayIDString = bestIDForConversation(conversationInfo, *convMod);
    if(displayNameString.length == 0 || [displayNameString isEqualToString:displayIDString]) {
        [displayName setStringValue:displayIDString];
        [displayRingID setHidden:YES];
    } else {
        [displayName setStringValue:displayNameString];
        [displayRingID setStringValue:displayIDString];
        [displayRingID setHidden:NO];
    }
    auto& imageManip = reinterpret_cast<Interfaces::ImageManipulationDelegate&>(GlobalInstances::pixmapManipulator());
    NSImage* image = QtMac::toNSImage(qvariant_cast<QPixmap>(imageManip.conversationPhoto(conversationInfo, convMod->owner)));
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
    [photoView setHidden: NO];
    [photoView setImage: image];
    try {
        auto contact = convModel->owner.contactModel->getContact(conversationInfo.participants[0]);
        if (contact.isPresent) {
            [presenceView setHidden:NO];
        }
    } catch (std::out_of_range& e) {
        NSLog(@"viewForTableColumn: getContact - out of range");
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
    if (type == FROM_CONTACT) {
        return contacts.size();
    }
    if(!convModel) {
        return 0;
    }
    if (tableView == contactsView) {
        return values.count(lrc::api::ConferenceableItem::CONTACT) ? values.value(lrc::api::ConferenceableItem::CONTACT).size() : 0;
    } else if (tableView == callsView) {
        return values.count(lrc::api::ConferenceableItem::CALL) ? values.value(lrc::api::ConferenceableItem::CALL).size() : 0;
    }
    return 0;
}

@end
