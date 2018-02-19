/*
 *  Copyright (C) 2015-2018 Savoir-faire Linux Inc.
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *          Anthony Léonard <anthony.leonard@savoirfairelinux.com>
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

#import <QItemSelectionModel>
#import <QPixmap>
#import <QtMacExtras/qmacfunctions.h>

// LRC
#import <globalinstances.h>
#import <api/interaction.h>

#import "MessagesVC.h"
#import "views/IMTableCellView.h"
#import "views/MessageBubbleView.h"
#import "INDSequentialTextSelectionManager.h"
#import "delegates/ImageManipulationDelegate.h"
#import "utils.h"

@interface MessagesVC () <NSTableViewDelegate, NSTableViewDataSource> {

    __unsafe_unretained IBOutlet NSTableView* conversationView;

    std::string convUid_;
    lrc::api::ConversationModel* convModel_;
    const lrc::api::conversation::Info* cachedConv_;

    QMetaObject::Connection newInteractionSignal_;

    // Both are needed to invalidate cached conversation as pointer
    // may not be referencing the same conversation anymore
    QMetaObject::Connection modelSortedSignal_;
    QMetaObject::Connection filterChangedSignal_;
    QMetaObject::Connection interactionStatusUpdatedSignal_;
}

@property (nonatomic, strong, readonly) INDSequentialTextSelectionManager* selectionManager;

@end

@implementation MessagesVC

-(const lrc::api::conversation::Info*) getCurrentConversation
{
    if (convModel_ == nil || convUid_.empty())
        return nil;

    if (cachedConv_ != nil)
        return cachedConv_;

    auto& convQueue = convModel_->allFilteredConversations();

    auto it = getConversationFromUid(convUid_, *convModel_);

    if (it != convQueue.end())
        cachedConv_ = &(*it);

    return cachedConv_;
}

-(void)setConversationUid:(const std::string)convUid model:(lrc::api::ConversationModel *)model
{
    if (convUid_ == convUid && convModel_ == model)
        return;

    cachedConv_ = nil;
    convUid_ = convUid;
    convModel_ = model;

    // Signal triggered when messages are received or their status updated
    QObject::disconnect(newInteractionSignal_);
    QObject::disconnect(interactionStatusUpdatedSignal_);
    newInteractionSignal_ = QObject::connect(convModel_, &lrc::api::ConversationModel::newInteraction,
                                         [self](const std::string& uid, uint64_t interactionId, const lrc::api::interaction::Info& interaction){
                                             if (uid != convUid_)
                                                 return;
                                             cachedConv_ = nil;
                                             [conversationView reloadData];
                                             [conversationView scrollToEndOfDocument:nil];
                                         });
    interactionStatusUpdatedSignal_ = QObject::connect(convModel_, &lrc::api::ConversationModel::interactionStatusUpdated,
                                                       [self](const std::string& uid, uint64_t interactionId, const lrc::api::interaction::Info& interaction){
                                                           if (uid != convUid_)
                                                               return;
                                                           cachedConv_ = nil;
                                                           [conversationView reloadData];
                                                           [conversationView scrollToEndOfDocument:nil];
                                                       });

    // Signals tracking changes in conversation list, we need them as cached conversation can be invalid
    // after a reordering.
    QObject::disconnect(modelSortedSignal_);
    QObject::disconnect(filterChangedSignal_);
    modelSortedSignal_ = QObject::connect(convModel_, &lrc::api::ConversationModel::modelSorted,
                                          [self](){
                                              cachedConv_ = nil;
                                          });
    filterChangedSignal_ = QObject::connect(convModel_, &lrc::api::ConversationModel::filterChanged,
                                          [self](){
                                              cachedConv_ = nil;
                                          });



    [conversationView reloadData];
    [conversationView scrollToEndOfDocument:nil];
}

-(void)newMessageSent
{
    [conversationView reloadData];
    [conversationView scrollToEndOfDocument:nil];
}

-(IMTableCellView*) makeViewforTransferStatus:(lrc::api::interaction::Status)status type:(lrc::api::interaction::Type)type tableView:(NSTableView*)tableView
{
    IMTableCellView* result;

    // First, view is created
    if (type == lrc::api::interaction::Type::INCOMING_DATA_TRANSFER) {
        switch (status) {
            case lrc::api::interaction::Status::TRANSFER_CREATED:
            case lrc::api::interaction::Status::TRANSFER_AWAITING:
                result = [tableView makeViewWithIdentifier:@"LeftIncomingFileView" owner:self];
                break;
            case lrc::api::interaction::Status::TRANSFER_ACCEPTED:
            case lrc::api::interaction::Status::TRANSFER_ONGOING:
                result = [tableView makeViewWithIdentifier:@"LeftOngoingFileView" owner:self];
                [result.progressIndicator startAnimation:nil];
                break;
            case lrc::api::interaction::Status::TRANSFER_FINISHED:
            case lrc::api::interaction::Status::TRANSFER_CANCELED:
            case lrc::api::interaction::Status::TRANSFER_ERROR:
                result = [tableView makeViewWithIdentifier:@"LeftFinishedFileView" owner:self];
        }
    } else if (type == lrc::api::interaction::Type::OUTGOING_DATA_TRANSFER) {
        switch (status) {
            case lrc::api::interaction::Status::TRANSFER_CREATED:
            case lrc::api::interaction::Status::TRANSFER_AWAITING:
            case lrc::api::interaction::Status::TRANSFER_ONGOING:
            case lrc::api::interaction::Status::TRANSFER_ACCEPTED:
                result = [tableView makeViewWithIdentifier:@"RightOngoingFileView" owner:self];
                [result.progressIndicator startAnimation:nil];
                break;
            case lrc::api::interaction::Status::TRANSFER_FINISHED:
            case lrc::api::interaction::Status::TRANSFER_CANCELED:
            case lrc::api::interaction::Status::TRANSFER_ERROR:
                result = [tableView makeViewWithIdentifier:@"RightFinishedFileView" owner:self];
        }
    }

    // Then status label is updated if needed
    switch (status) {
        case lrc::api::interaction::Status::TRANSFER_FINISHED:
            [result.statusLabel setStringValue:NSLocalizedString(@"Success", @"File transfer successful label")];
            break;
        case lrc::api::interaction::Status::TRANSFER_CANCELED:
            [result.statusLabel setStringValue:NSLocalizedString(@"Canceled", @"File transfer canceled label")];
            break;
        case lrc::api::interaction::Status::TRANSFER_ERROR:
            [result.statusLabel setStringValue:NSLocalizedString(@"Failed", @"File transfer failed label")];
    }
    return result;
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

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    auto* conv = [self getCurrentConversation];

    if (conv == nil)
        return nil;

    // HACK HACK HACK HACK HACK
    // The following code has to be replaced when every views are implemented for every interaction types
    // This is an iterator which "jumps over" any interaction which is not a text or datatransfer one.
    // It behaves as if interaction list was only containing text interactions.
    std::map<uint64_t, lrc::api::interaction::Info>::const_iterator it;

    {
        int msgCount = 0;
        it = std::find_if(conv->interactions.begin(), conv->interactions.end(), [&msgCount, row](const std::pair<uint64_t, lrc::api::interaction::Info>& inter) {
            if (inter.second.type == lrc::api::interaction::Type::TEXT
                || inter.second.type == lrc::api::interaction::Type::INCOMING_DATA_TRANSFER
                || inter.second.type == lrc::api::interaction::Type::OUTGOING_DATA_TRANSFER) {
                if (msgCount == row) {
                    return true;
                } else {
                    msgCount++;
                    return false;
                }
            }
            return false;
        });
    }

    if (it == conv->interactions.end())
        return nil;

    IMTableCellView* result;

    auto& interaction = it->second;

    bool isOutgoing = lrc::api::interaction::isOutgoing(interaction);

    switch (interaction.type) {
        case lrc::api::interaction::Type::TEXT:
            if (isOutgoing) {
                result = [tableView makeViewWithIdentifier:@"RightMessageView" owner:self];
            } else {
                result = [tableView makeViewWithIdentifier:@"LeftMessageView" owner:self];
            }
            if (interaction.status == lrc::api::interaction::Status::UNREAD)
                convModel_->setInteractionRead(convUid_, it->first);
            break;
        case lrc::api::interaction::Type::INCOMING_DATA_TRANSFER:
        case lrc::api::interaction::Type::OUTGOING_DATA_TRANSFER:
            result = [self makeViewforTransferStatus:interaction.status type:interaction.type tableView:tableView];
            break;
        default:  // If interaction is not of a known type
            return nil;
    }

    // check if the message first in incoming or outgoing messages sequence
    Boolean isFirstInSequence = true;
    if (it != conv->interactions.begin()) {
        auto previousIt = it;
        previousIt--;
        auto& previousInteraction = previousIt->second;
        if ((previousInteraction.type == lrc::api::interaction::Type::TEXT
             || previousInteraction.type == lrc::api::interaction::Type::INCOMING_DATA_TRANSFER
             || previousInteraction.type == lrc::api::interaction::Type::OUTGOING_DATA_TRANSFER) && (isOutgoing == lrc::api::interaction::isOutgoing(previousInteraction)))
            isFirstInSequence = false;
    }
    [result.photoView setHidden:!isFirstInSequence];
    result.msgBackground.needPointer = isFirstInSequence;
    [result setupForInteraction:it->first];

    NSMutableAttributedString* msgAttString =
    [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n",@(interaction.body.c_str())]
                                           attributes:[self messageAttributes]];

    NSDate *msgTime = [NSDate dateWithTimeIntervalSince1970:interaction.timestamp];
    NSAttributedString* timestampAttrString =
    [[NSAttributedString alloc] initWithString:[NSDateFormatter localizedStringFromDate:msgTime dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterMediumStyle]
                                    attributes:[self timestampAttributes]];

    CGFloat finalWidth = MAX(msgAttString.size.width, timestampAttrString.size.width);

    finalWidth = MIN(finalWidth + 30, tableView.frame.size.width * 0.7);

    [msgAttString appendAttributedString:timestampAttrString];
    [[result.msgView textStorage] appendAttributedString:msgAttString];
    [result.msgView checkTextInDocument:nil];
    [result updateWidthConstraint:finalWidth];

    auto& imageManip = reinterpret_cast<Interfaces::ImageManipulationDelegate&>(GlobalInstances::pixmapManipulator());
    if (isOutgoing) {
        [result.photoView setImage:[NSImage imageNamed:@"default_user_icon"]];
    } else {
        [result.photoView setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(imageManip.conversationPhoto(*conv, convModel_->owner)))];
    }

    return result;
}

- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
    if (IMTableCellView* cellView = [tableView viewAtColumn:0 row:row makeIfNecessary:NO]) {
        [self.selectionManager registerTextView:cellView.msgView withUniqueIdentifier:@(row).stringValue];
    }
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    double someWidth = tableView.frame.size.width * 0.7;

    auto* conv = [self getCurrentConversation];

    if (conv == nil)
        return 0;

    // HACK HACK HACK HACK HACK
    // The following code has to be replaced when every views are implemented for every interaction types
    // This is an iterator which "jumps over" any interaction which is not a text or datatransfer one.
    // It behaves as if interaction list was only containing text interactions.
    std::map<uint64_t, lrc::api::interaction::Info>::const_iterator it;

    {
        int msgCount = 0;
        it = std::find_if(conv->interactions.begin(), conv->interactions.end(), [&msgCount, row](const std::pair<uint64_t, lrc::api::interaction::Info>& inter) {
            if (inter.second.type == lrc::api::interaction::Type::TEXT
                || inter.second.type == lrc::api::interaction::Type::INCOMING_DATA_TRANSFER
                || inter.second.type == lrc::api::interaction::Type::OUTGOING_DATA_TRANSFER) {
                if (msgCount == row) {
                    return true;
                } else {
                    msgCount++;
                    return false;
                }
            }
            return false;
        });
    }

    if (it == conv->interactions.end())
        return 0;

    auto& interaction = it->second;

    if(interaction.type == lrc::api::interaction::Type::INCOMING_DATA_TRANSFER || interaction.type == lrc::api::interaction::Type::OUTGOING_DATA_TRANSFER)
        return 52.0;

    // TODO Implement interactions other than messages
    if(interaction.type != lrc::api::interaction::Type::TEXT) {
        return 0;
    }

    NSMutableAttributedString* msgAttString =
    [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n",@(interaction.body.c_str())]
                                           attributes:[self messageAttributes]];

    NSDate *msgTime = [NSDate dateWithTimeIntervalSince1970:interaction.timestamp];
    NSAttributedString* timestampAttrString =
    [[NSAttributedString alloc] initWithString:[NSDateFormatter localizedStringFromDate:msgTime dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterMediumStyle]
                                    attributes:[self timestampAttributes]];

    [msgAttString appendAttributedString:timestampAttrString];

    [msgAttString appendAttributedString:timestampAttrString];

    NSRect frame = NSMakeRect(0, 0, someWidth, MAXFLOAT);
    NSTextView *tv = [[NSTextView alloc] initWithFrame:frame];
    [tv setEnabledTextCheckingTypes:NSTextCheckingTypeLink];
    [tv setAutomaticLinkDetectionEnabled:YES];
    [[tv textStorage] setAttributedString:msgAttString];
    [tv sizeToFit];

    double height = tv.frame.size.height + 10;
    return MAX(height, 50.0f);
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    auto* conv = [self getCurrentConversation];

    if (conv) {
        int count;
        count = std::count_if(conv->interactions.begin(), conv->interactions.end(), [](const std::pair<uint64_t, lrc::api::interaction::Info>& inter) {
            return inter.second.type == lrc::api::interaction::Type::TEXT
            || inter.second.type == lrc::api::interaction::Type::INCOMING_DATA_TRANSFER
            || inter.second.type == lrc::api::interaction::Type::OUTGOING_DATA_TRANSFER;
        });
        NSLog(@"$$$ Interaction count: %d", count);
        return count;
    }
    return 0;

#if 0
    // TODO: Replace above code by the following one when every interaction types implemented
    if (conv_) {
        return conv_->interactions.size();
    }
#endif
}

#pragma mark - Text formatting

- (NSMutableDictionary*) timestampAttributes
{
    NSMutableDictionary* attrs = [NSMutableDictionary dictionary];
    attrs[NSForegroundColorAttributeName] = [NSColor grayColor];
    NSFont* systemFont = [NSFont systemFontOfSize:12.0f];
    attrs[NSFontAttributeName] = systemFont;
    attrs[NSParagraphStyleAttributeName] = [self paragraphStyle];

    return attrs;
}

- (NSMutableDictionary*) messageAttributes
{
    NSMutableDictionary* attrs = [NSMutableDictionary dictionary];
    attrs[NSForegroundColorAttributeName] = [NSColor blackColor];
    NSFont* systemFont = [NSFont systemFontOfSize:14.0f];
    attrs[NSFontAttributeName] = systemFont;
    attrs[NSParagraphStyleAttributeName] = [self paragraphStyle];

    return attrs;
}

- (NSParagraphStyle*) paragraphStyle
{
    /*
     The only way to instantiate an NSMutableParagraphStyle is to mutably copy an
     NSParagraphStyle. And since we don't have an existing NSParagraphStyle available
     to copy, we use the default one.

     The default values supplied by the default NSParagraphStyle are:
     Alignment   NSNaturalTextAlignment
     Tab stops   12 left-aligned tabs, spaced by 28.0 points
     Line break mode   NSLineBreakByWordWrapping
     All others   0.0
     */
       NSMutableParagraphStyle* aMutableParagraphStyle =
     [[NSParagraphStyle defaultParagraphStyle] mutableCopy];

     // Now adjust our NSMutableParagraphStyle formatting to be whatever we want.
     // The numeric values below are in points (72 points per inch)
     [aMutableParagraphStyle setLineSpacing:1.5];
     [aMutableParagraphStyle setParagraphSpacing:5.0];
     [aMutableParagraphStyle setHeadIndent:5.0];
     [aMutableParagraphStyle setTailIndent:-5.0];
     [aMutableParagraphStyle setFirstLineHeadIndent:5.0];
     return aMutableParagraphStyle;
}

#pragma mark - Actions

- (IBAction)acceptIncomingFile:(id)sender {
    auto interId = [(IMTableCellView*)[[sender superview] superview] interaction];
    auto& inter = [self getCurrentConversation]->interactions.find(interId)->second;
    if (convModel_ && !convUid_.empty()) {
        NSSavePanel* filePicker = [NSSavePanel savePanel];
        [filePicker setNameFieldStringValue:@(inter.body.c_str())];

        if ([filePicker runModal] == NSFileHandlingPanelOKButton) {
            const char* fullPath = [[filePicker URL] fileSystemRepresentation];
            convModel_->acceptTransfer(convUid_, interId, fullPath);
        }
    }
}

- (IBAction)declineIncomingFile:(id)sender {
    auto inter = [(IMTableCellView*)[[sender superview] superview] interaction];
    if (convModel_ && !convUid_.empty()) {
        convModel_->cancelTransfer(convUid_, inter);
    }
}

@end
