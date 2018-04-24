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
#import "views/NSImage+Extensions.h"
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

// Tags for view
NSInteger const GENERIC_INT_TEXT_TAG = 100;
NSInteger const GENERIC_INT_TIME_TAG = 200;

// views size
CGFloat   const GENERIC_CELL_HEIGHT       = 60;
CGFloat   const TIME_BOX_HEIGHT           = 34;
CGFloat   const MESSAGE_TEXT_PADDING      = 10;
CGFloat   const MAX_TRANSFERED_IMAGE_SIZE = 250;
CGFloat   const BUUBLE_HEIGHT_FOR_TRANSFERED_FILE = 82;

@implementation MessagesVC

//MessageBuble type
typedef NS_ENUM(NSInteger, MessageSequencing) {
    SINGLE_WITH_TIME       = 0,
    SINGLE_WITHOUT_TIME    = 1,
    FIRST_WITH_TIME        = 2,
    FIRST_WITHOUT_TIME     = 3,
    MIDDLE_IN_SEQUENCE     = 5,
    LAST_IN_SEQUENCE       = 6,
};

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

-(void) reloadVisibleRows {
    NSScrollView* scrollView = [conversationView enclosingScrollView];

    CGRect visibleRect = scrollView.contentView.visibleRect;

    NSRange range = [conversationView rowsInRect:visibleRect];
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:range];
    [conversationView reloadDataForRowIndexes:indexSet columnIndexes:[NSIndexSet indexSetWithIndex:0]];

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
                                             [conversationView noteNumberOfRowsChanged];
                                             [self reloadVisibleRows];
                                             //[conversationView reloadData];
                                             [conversationView scrollToEndOfDocument:nil];
                                         });
    interactionStatusUpdatedSignal_ = QObject::connect(convModel_, &lrc::api::ConversationModel::interactionStatusUpdated,
                                                       [self](const std::string& uid, uint64_t interactionId, const lrc::api::interaction::Info& interaction){
                                                           if (uid != convUid_)
                                                               return;
                                                           cachedConv_ = nil;
                                                           bool rowHeightChanged = NO;
                                                           NSString* name =  @(interaction.body.c_str());
                                                           if (interaction.status == lrc::api::interaction::Status::TRANSFER_FINISHED) {
                                                               NSImage* image = [self getImageForFilePath:name];
                                                               if(image != nil) {
                                                                   rowHeightChanged = YES;
                                                               }
                                                           }
                                                           [self reloadConversationForMessageUiD:interactionId shouldUpdateHeight:rowHeightChanged];
                                                           if (interaction.type == lrc::api::interaction::Type::INCOMING_DATA_TRANSFER && (interaction.status == lrc::api::interaction::Status::TRANSFER_AWAITING_HOST || interaction.status == lrc::api::interaction::Status::TRANSFER_CREATED)) {
                                                                           lrc::api::datatransfer::Info info = {};
                                                                           convModel_->getTransferInfo(interactionId, info);
                                                                           double convertData = static_cast<double>(info.totalSize);
                                                               if( convertData <= 10485760) {
                                                                   [self acceptFile:interactionId];
                                                               }
                                                           }
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


    NSNib *cellNib = [[NSNib alloc] initWithNibNamed:@"OngoingDataTransferCell" bundle:nil];
    [conversationView registerNib:cellNib forIdentifier:@"LeftIncomingFileView"];
    [conversationView registerNib:cellNib forIdentifier:@"LeftOngoingFileView"];
    [conversationView registerNib:cellNib forIdentifier:@"LeftFinishedFileView"];
    [conversationView reloadData];
    [conversationView scrollToEndOfDocument:nil];
}

-(void) reloadConversationForMessageUiD:(uint64_t) uid shouldUpdateHeight:(bool)update {
    auto* conv = [self getCurrentConversation];

    if (conv == nil)
        return;
    auto it = distance(conv->interactions.begin(),conv->interactions.find(uid));
    NSIndexSet* indexSet = [NSIndexSet indexSetWithIndex:it];
    if (update) {
        [conversationView noteHeightOfRowsWithIndexesChanged:indexSet];
    }
    [conversationView reloadDataForRowIndexes:indexSet columnIndexes:[NSIndexSet indexSetWithIndex:0]];
    if (update) {
        [conversationView scrollToEndOfDocument:nil];
    }
}

-(void)newMessageSent
{
   // [conversationView reloadData];
   // [conversationView scrollToEndOfDocument:nil];
}

-(NSTableCellView*) makeGenericInteractionViewForTableView:(NSTableView*)tableView withText:(NSString*)text andTime:(NSString*) time
{
    NSTableCellView* result = [tableView makeViewWithIdentifier:@"GenericInteractionView" owner:self];
    NSTextField* textField = [result viewWithTag:GENERIC_INT_TEXT_TAG];
    NSTextField* timeField = [result viewWithTag:GENERIC_INT_TIME_TAG];

    // TODO: Fix symbol in LRC
    NSString* fixedString = [text stringByReplacingOccurrencesOfString:@"🕽" withString:@"📞"];
    [textField setStringValue:fixedString];
    [timeField setStringValue:time];

    return result;
}

-(NSImage*) getImageForFilePath: (NSString *) path {
    if (path.length <= 0) {return nil;}
    if (![[NSFileManager defaultManager] fileExistsAtPath: path]) {return nil;}
    NSImage* transferedImage = [[NSImage alloc] initWithContentsOfFile: path];
    if(transferedImage != nil) {
        return [transferedImage imageResizeInsideMax: MAX_TRANSFERED_IMAGE_SIZE];
    }
    return nil;
}

-(NSTableCellView*) configureViewforTransfer:(lrc::api::interaction::Info)interaction interactionID: (uint64_t) interactionID tableView:(NSTableView*)tableView
{
    IMTableCellView* result;

    auto type = interaction.type;
    auto status = interaction.status;

    // First, view is created
    if (type == lrc::api::interaction::Type::INCOMING_DATA_TRANSFER) {
        switch (status) {
            case lrc::api::interaction::Status::TRANSFER_CREATED:
            case lrc::api::interaction::Status::TRANSFER_AWAITING_HOST: {
                result = [tableView makeViewWithIdentifier:@"LeftIncomingFileView" owner: conversationView];
                [result.acceptButton setAction:@selector(acceptIncomingFile:)];
                [result.acceptButton setTarget:self];
                [result.declineButton setAction:@selector(declineIncomingFile:)];
                [result.declineButton setTarget:self];
                break;}
            case lrc::api::interaction::Status::TRANSFER_ACCEPTED:
            case lrc::api::interaction::Status::TRANSFER_ONGOING: {
                result = [tableView makeViewWithIdentifier:@"LeftOngoingFileView" owner:conversationView];
                [result.declineButton setAction:@selector(declineIncomingFile:)];
                [result.declineButton setTarget:self];
                [result.progressIndicator startAnimation:conversationView];
                break;}
            case lrc::api::interaction::Status::TRANSFER_FINISHED:
            case lrc::api::interaction::Status::TRANSFER_CANCELED:
            case lrc::api::interaction::Status::TRANSFER_ERROR:
                result = [tableView makeViewWithIdentifier:@"LeftFinishedFileView" owner:conversationView];
                break;

        }
        result.transferedImage.image = nil;
        [result.msgBackground setHidden:NO];
        NSString* fileName = @"incoming file";
        NSString* name =  @(interaction.body.c_str());
        if (name.length > 0) {
            if (([name rangeOfString:@"/"].location != NSNotFound)) {
                NSArray *listItems = [name componentsSeparatedByString:@"/"];
                NSString* name1 = listItems.lastObject;
                fileName = name1;
            } else {
                fileName = name;
            }
        }
        result.transferedFileName.stringValue = fileName;
        if (status == lrc::api::interaction::Status::TRANSFER_FINISHED) {
            NSImage* image = [self getImageForFilePath:name];
            if(image != nil) {
                result.transferedImage.image = [image roundCorners:14];
            }
        }
    } else if (type == lrc::api::interaction::Type::OUTGOING_DATA_TRANSFER) {
        switch (status) {
            case lrc::api::interaction::Status::TRANSFER_CREATED:
            case lrc::api::interaction::Status::TRANSFER_AWAITING_PEER:
            case lrc::api::interaction::Status::TRANSFER_ONGOING:
            case lrc::api::interaction::Status::TRANSFER_ACCEPTED:
                result = [tableView makeViewWithIdentifier:@"RightOngoingFileView" owner:self];
                [result.progressIndicator startAnimation:nil];
                break;
            case lrc::api::interaction::Status::TRANSFER_FINISHED:
            case lrc::api::interaction::Status::TRANSFER_CANCELED:
            case lrc::api::interaction::Status::TRANSFER_ERROR:
            case lrc::api::interaction::Status::TRANSFER_UNJOINABLE_PEER:
                result = [tableView makeViewWithIdentifier:@"RightFinishedFileView" owner:self];
        }
    }

    // Then status label is updated if needed
    switch (status) {
        case lrc::api::interaction::Status::TRANSFER_FINISHED:
            [result.statusLabel setTextColor:[NSColor greenColor]];
            [result.statusLabel setStringValue:NSLocalizedString(@"Success", @"File transfer successful label")];
            break;
        case lrc::api::interaction::Status::TRANSFER_CANCELED:
            [result.statusLabel setStringValue:NSLocalizedString(@"Canceled", @"File transfer canceled label")];
            break;
        case lrc::api::interaction::Status::TRANSFER_ERROR:
            [result.statusLabel setTextColor:[NSColor redColor]];
            [result.statusLabel setStringValue:NSLocalizedString(@"Failed", @"File transfer failed label")];
            break;
        case lrc::api::interaction::Status::TRANSFER_UNJOINABLE_PEER:
            [result.statusLabel setStringValue:NSLocalizedString(@"Unjoinable", @"File transfer peer unjoinable label")];
            break;
    }
    NSDate* msgTime = [NSDate dateWithTimeIntervalSince1970:interaction.timestamp];
    NSString* timeString = [self timeForMessage: msgTime];
    result.timeLabel.stringValue = timeString;
    bool isOutgoing = lrc::api::interaction::isOutgoing(interaction);
    if (!isOutgoing) {
        auto& imageManip = reinterpret_cast<Interfaces::ImageManipulationDelegate&>(GlobalInstances::pixmapManipulator());
        auto* conv = [self getCurrentConversation];
        [result.photoView setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(imageManip.conversationPhoto(*conv, convModel_->owner)))];
    }
    [result setupForInteraction:interactionID];
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

    auto it = conv->interactions.begin();

    std::advance(it, row);

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
            return [self configureViewforTransfer:interaction interactionID: it->first tableView:tableView];
            break;
        case lrc::api::interaction::Type::CONTACT:
        case lrc::api::interaction::Type::CALL: {
            NSDate* msgTime = [NSDate dateWithTimeIntervalSince1970:interaction.timestamp];
            NSString* timeString = [self timeForMessage: msgTime];
            return [self makeGenericInteractionViewForTableView:tableView withText:@(interaction.body.c_str()) andTime:timeString];
        }
        default:  // If interaction is not of a known type
            return nil;
    }
    MessageSequencing sequence = [self computeSequencingFor:row];
    BubbleType type = SINGLE;
    if (sequence == FIRST_WITHOUT_TIME || sequence == FIRST_WITH_TIME) {
        type = FIRST;
    }
    if (sequence == MIDDLE_IN_SEQUENCE) {
        type = MIDDLE;
    }
    if (sequence == LAST_IN_SEQUENCE) {
        type = LAST;
    }
    result.msgBackground.type = type;
    [result setupForInteraction:it->first];
    bool shouldDisplayTime = (sequence == FIRST_WITH_TIME || sequence == SINGLE_WITH_TIME) ? YES : NO;
    if (row == (conversationView.numberOfRows - 2)) {
        [result.msgBackground setNeedsDisplay:YES];
    }

    NSMutableAttributedString* msgAttString =
    [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@",@(interaction.body.c_str())]
                                           attributes:[self messageAttributes]];

    CGSize messageSize = [self sizeFor: @(interaction.body.c_str()) maxWidth:tableView.frame.size.width * 0.7];

    [result updateConstraint:messageSize.width  andHeight:messageSize.height timeIsVisible:shouldDisplayTime];
    [[result.msgView textStorage] appendAttributedString:msgAttString];
    [result.msgView checkTextInDocument:nil];

    if (shouldDisplayTime) {
        NSDate* msgTime = [NSDate dateWithTimeIntervalSince1970:interaction.timestamp];
        NSString* timeString = [self timeForMessage: msgTime];
        result.timeLabel.stringValue = timeString;
    }

    bool shouldDisplayAvatar = (sequence != MIDDLE_IN_SEQUENCE && sequence != LAST_IN_SEQUENCE) ? YES : NO;
    [result.photoView setHidden:!shouldDisplayAvatar];
    if (!isOutgoing && shouldDisplayAvatar) {
        auto& imageManip = reinterpret_cast<Interfaces::ImageManipulationDelegate&>(GlobalInstances::pixmapManipulator());
        [result.photoView setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(imageManip.conversationPhoto(*conv, convModel_->owner)))];
    }
    return result;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    double someWidth = tableView.frame.size.width * 0.7;

    auto* conv = [self getCurrentConversation];

    if (conv == nil)
        return 0;

    auto it = conv->interactions.begin();

    std::advance(it, row);

    auto& interaction = it->second;

    MessageSequencing sequence = [self computeSequencingFor:row];

    bool shouldDisplayTime = (sequence == FIRST_WITH_TIME || sequence == SINGLE_WITH_TIME) ? YES : NO;


    if(interaction.type == lrc::api::interaction::Type::INCOMING_DATA_TRANSFER || interaction.type == lrc::api::interaction::Type::OUTGOING_DATA_TRANSFER) {

        if( interaction.status == lrc::api::interaction::Status::TRANSFER_FINISHED) {
            NSString* name =  @(interaction.body.c_str());
            NSImage* image = [self getImageForFilePath:name];
            if (image != nil) {
                return image.size.height + TIME_BOX_HEIGHT;
            }
        }
        return BUUBLE_HEIGHT_FOR_TRANSFERED_FILE + TIME_BOX_HEIGHT;
    }

    if(interaction.type == lrc::api::interaction::Type::CONTACT || interaction.type == lrc::api::interaction::Type::CALL)
        return GENERIC_CELL_HEIGHT;

    // TODO Implement interactions other than messages
    if(interaction.type != lrc::api::interaction::Type::TEXT) {
        return 0;
    }

    CGSize messageSize = [self sizeFor: @(interaction.body.c_str()) maxWidth:tableView.frame.size.width * 0.7];
    CGFloat singleLignMessageHeight = 15;

    if (shouldDisplayTime) {
        return MAX(messageSize.height + TIME_BOX_HEIGHT + MESSAGE_TEXT_PADDING * 2,
                   TIME_BOX_HEIGHT + MESSAGE_TEXT_PADDING * 2 + singleLignMessageHeight);
    }
    return MAX(messageSize.height + MESSAGE_TEXT_PADDING * 2,
               singleLignMessageHeight + MESSAGE_TEXT_PADDING * 2);
}

-(CGSize) sizeFor:(NSString *) message maxWidth:(CGFloat) width {
    CGFloat horizaontalMargin = 6;
    NSMutableAttributedString* msgAttString =
    [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", message]
                                           attributes:[self messageAttributes]];

    CGFloat finalWidth = MIN(msgAttString.size.width + horizaontalMargin * 2, width);
    NSRect frame = NSMakeRect(0, 0, finalWidth, msgAttString.size.height);
    NSTextView *tv = [[NSTextView alloc] initWithFrame:frame];
    [[tv textStorage] setAttributedString:msgAttString];
    [tv sizeToFit];
    return tv.frame.size;
}

-(MessageSequencing) computeSequencingFor:(NSInteger) row {
    auto* conv = [self getCurrentConversation];
    if (conv == nil)
    return SINGLE_WITHOUT_TIME;
    auto it = conv->interactions.begin();
    std::advance(it, row);
    auto& interaction = it->second;
    if (interaction.type != lrc::api::interaction::Type::TEXT) {
        return SINGLE_WITH_TIME;
    }
    if (row == 0) {
        if (it == conv->interactions.end()) {
            return SINGLE_WITH_TIME;
        }
        auto nextIt = it;
        nextIt++;
        auto& nextInteraction = nextIt->second;
        if ([self sequenceChangedFrom:interaction to: nextInteraction]) {
            return SINGLE_WITH_TIME;
        }
        return FIRST_WITH_TIME;
    }

    if (row == conversationView.numberOfRows - 1) {
        if(it == conv->interactions.begin()) {
            return SINGLE_WITH_TIME;
        }
        auto previousIt = it;
        previousIt--;
        auto& previousInteraction = previousIt->second;
        bool timeChanged = [self sequenceTimeChangedFrom:interaction to:previousInteraction];
        bool authorChanged = [self sequenceAuthorChangedFrom:interaction to:previousInteraction];
        if (!timeChanged && !authorChanged) {
            return LAST_IN_SEQUENCE;
        }
        if (!timeChanged && authorChanged) {
            return SINGLE_WITHOUT_TIME;
        }
        return SINGLE_WITH_TIME;
    }
    if(it == conv->interactions.begin() || it == conv->interactions.end()) {
        return SINGLE_WITH_TIME;
    }
    auto previousIt = it;
    previousIt--;
    auto& previousInteraction = previousIt->second;
    auto nextIt = it;
    nextIt++;
    auto& nextInteraction = nextIt->second;

    bool timeChanged = [self sequenceTimeChangedFrom:interaction to:previousInteraction];
    bool authorChanged = [self sequenceAuthorChangedFrom:interaction to:previousInteraction];
    bool sequenceWillChange = [self sequenceChangedFrom:interaction to: nextInteraction];
    if (!sequenceWillChange) {
        if (!timeChanged && !authorChanged) {
            return MIDDLE_IN_SEQUENCE;
        }
        if (timeChanged) {
            return FIRST_WITH_TIME;
        }
        return FIRST_WITHOUT_TIME;
    } if (!timeChanged && !authorChanged) {
        return LAST_IN_SEQUENCE;
    } if (timeChanged) {
        return SINGLE_WITH_TIME;
    }
    return SINGLE_WITHOUT_TIME;
}

-(bool) sequenceChangedFrom:(lrc::api::interaction::Info) firstInteraction to:(lrc::api::interaction::Info) secondInteraction {
    return ([self sequenceTimeChangedFrom:firstInteraction to:secondInteraction] || [self sequenceAuthorChangedFrom:firstInteraction to:secondInteraction]);
}

-(bool) sequenceTimeChangedFrom:(lrc::api::interaction::Info) firstInteraction to:(lrc::api::interaction::Info) secondInteraction {
    bool timeChanged = NO;
    NSDate* firstMessageTime = [NSDate dateWithTimeIntervalSince1970:firstInteraction.timestamp];
    NSDate* secondMessageTime = [NSDate dateWithTimeIntervalSince1970:secondInteraction.timestamp];
    bool hourComp = [[NSCalendar currentCalendar] compareDate:firstMessageTime toDate:secondMessageTime toUnitGranularity:NSCalendarUnitHour];
    bool minutComp = [[NSCalendar currentCalendar] compareDate:firstMessageTime toDate:secondMessageTime toUnitGranularity:NSCalendarUnitMinute];
    if(hourComp != NSOrderedSame || minutComp != NSOrderedSame) {
        timeChanged = YES;
    }
    return timeChanged;
}

-(bool) sequenceAuthorChangedFrom:(lrc::api::interaction::Info) firstInteraction to:(lrc::api::interaction::Info) secondInteraction {
    bool authorChanged = YES;
    bool isOutgoing = lrc::api::interaction::isOutgoing(firstInteraction);
    if ((secondInteraction.type == lrc::api::interaction::Type::TEXT) && (isOutgoing == lrc::api::interaction::isOutgoing(secondInteraction))) {
        authorChanged = NO;
    }
    return authorChanged;
}

-(NSString *)timeForMessage:(NSDate*) msgTime {
    NSDate *today = [NSDate date];
    NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
    if ([[NSCalendar currentCalendar] compareDate:today
                                           toDate:msgTime
                                toUnitGranularity:NSCalendarUnitYear]!= NSOrderedSame) {
        return [NSDateFormatter localizedStringFromDate:msgTime dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterMediumStyle];
    }

    if ([[NSCalendar currentCalendar] compareDate:today
                                           toDate:msgTime
                                toUnitGranularity:NSCalendarUnitDay]!= NSOrderedSame ||
        [[NSCalendar currentCalendar] compareDate:today
                                           toDate:msgTime
                                toUnitGranularity:NSCalendarUnitMonth]!= NSOrderedSame) {
            [dateFormatter setDateFormat:@"MMM dd, HH:mm"];
            return [dateFormatter stringFromDate:msgTime];
        }

    [dateFormatter setDateFormat:@"HH:mm"];
    return [dateFormatter stringFromDate:msgTime];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    auto* conv = [self getCurrentConversation];

    if (conv)
        return conv->interactions.size();
    else
        return 0;
}

#pragma mark - Text formatting

- (NSMutableDictionary*) messageAttributes
{
    NSMutableDictionary* attrs = [NSMutableDictionary dictionary];
    attrs[NSForegroundColorAttributeName] = [NSColor labelColor];
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
    [aMutableParagraphStyle setHeadIndent:1.0];
    [aMutableParagraphStyle setFirstLineHeadIndent:1.0];
    return aMutableParagraphStyle;
}

- (void)acceptFile:(uint64_t)interactionID {
    NSURL *downloadsURL = [[NSFileManager defaultManager]
                           URLForDirectory:NSDownloadsDirectory
                           inDomain:NSUserDomainMask appropriateForURL:nil
                           create:YES error:nil];
    auto& inter = [self getCurrentConversation]->interactions.find(interactionID)->second;
    if (convModel_ && !convUid_.empty()) {
         NSURL *bUrl = [downloadsURL URLByAppendingPathComponent:@(inter.body.c_str())];
        const char* fullPath = [bUrl fileSystemRepresentation];
        convModel_->acceptTransfer(convUid_, interactionID, fullPath);
    }
}

#pragma mark - Actions

- (void)acceptIncomingFile:(id)sender {
    auto interId = [(IMTableCellView*)[[sender superview] superview] interaction];
    //[(IMTableCellView*)[[sender superview] superview] interaction];
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
