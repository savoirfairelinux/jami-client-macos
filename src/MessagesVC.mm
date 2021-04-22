
/*
 *  Copyright (C) 2015-2019 Savoir-faire Linux Inc.
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

#import <QPixmap>
#import <QtMacExtras/qmacfunctions.h>

// LRC
#import <globalinstances.h>
#import <api/interaction.h>

#import "MessagesVC.h"
#import "views/IMTableCellView.h"
#import "views/MessageBubbleView.h"
#import "views/NSImage+Extensions.h"
#import "views/FileToSendCollectionItem.h"
#import "delegates/ImageManipulationDelegate.h"
#import "utils.h"
#import "views/NSColor+RingTheme.h"
#import "views/IconButton.h"
#import "views/TextViewWithPlaceholder.h"
#import <QuickLook/QuickLook.h>
#import <Quartz/Quartz.h>
#import <AVFoundation/AVFoundation.h>

#import "RecordFileVC.h"

@implementation PendingFile
@end

@interface MessagesVC () <NSTableViewDelegate, NSTableViewDataSource, QLPreviewPanelDataSource, NSTextViewDelegate, NSCollectionViewDataSource> {

    __unsafe_unretained IBOutlet NSTableView* conversationView;
    __unsafe_unretained IBOutlet DraggingDestinationView* draggingDestinationView;
    __unsafe_unretained IBOutlet NSCollectionView* pendingFilesCollectionView;
    __unsafe_unretained IBOutlet NSView* containerView;
    __unsafe_unretained IBOutlet TextViewWithPlaceholder* messageView;
    __unsafe_unretained IBOutlet IconButton *sendFileButton;
    __unsafe_unretained IBOutlet IconButton *recordVideoButton;
    __unsafe_unretained IBOutlet IconButton *recordAudioButton;
    __unsafe_unretained IBOutlet NSLayoutConstraint* sendPanelHeight;
    __unsafe_unretained IBOutlet NSLayoutConstraint* messageHeight;
    __unsafe_unretained IBOutlet NSLayoutConstraint* textBottomConstraint;
    IBOutlet NSPopover *recordMessagePopover;

    QString convUid_;
    lrc::api::ConversationModel* convModel_;
    const lrc::api::conversation::Info* cachedConv_;
    lrc::api::AVModel* avModel;
    QMetaObject::Connection newInteractionSignal_;

    // Both are needed to invalidate cached conversation as pointer
    // may not be referencing the same conversation anymore
    QMetaObject::Connection modelSortedSignal_;
    QMetaObject::Connection filterChangedSignal_;
    QMetaObject::Connection interactionStatusUpdatedSignal_;
    QMetaObject::Connection peerComposingMsgSignal_;
    QMetaObject::Connection lastDisplayedChanged_;
    NSString* previewImage;
    NSMutableDictionary *pendingMessagesToSend;
    RecordFileVC* recordingController;
}

@end

// Tags for view
NSInteger const GENERIC_INT_TEXT_TAG = 100;
NSInteger const GENERIC_INT_TIME_TAG = 200;

// views size
CGFloat   const GENERIC_CELL_HEIGHT       = 60;
CGFloat   const TIME_BOX_HEIGHT           = 34;
CGFloat   const MESSAGE_TEXT_PADDING      = 10;
CGFloat   const MAX_TRANSFERED_IMAGE_SIZE = 250;
CGFloat   const BUBBLE_HEIGHT_FOR_TRANSFERED_FILE = 87;
CGFloat   const DEFAULT_ROW_HEIGHT = 10;
CGFloat   const HEIGHT_FOR_COMPOSING_INDICATOR = 46;
CGFloat   const HEIGHT_DEFAULT = 34;
NSInteger const SEND_PANEL_DEFAULT_HEIGHT = 60;
NSInteger const SEND_PANEL_MAX_HEIGHT = 167;
NSInteger const SEND_PANEL_BOTTOM_MARGIN = 13;
NSInteger MESSAGE_VIEW_DEFAULT_HEIGHT = 17;
NSInteger const BOTTOM_MARGIN = 8;
NSInteger const BOTTOM_MARGIN_MIN = 0;
NSInteger const TOP_MARGIN = 20;
NSInteger const TOP_MARGIN_MIN = 13;

BOOL peerComposingMessage = false;
BOOL composingMessage = false;

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

- (void)awakeFromNib
{
    NSNib *cellNib = [[NSNib alloc] initWithNibNamed:@"MessageCells" bundle:nil];
    [conversationView registerNib:cellNib forIdentifier:@"LeftIncomingFileView"];
    [conversationView registerNib:cellNib forIdentifier:@"LeftOngoingFileView"];
    [conversationView registerNib:cellNib forIdentifier:@"LeftFinishedFileView"];
    [conversationView registerNib:cellNib forIdentifier:@"RightOngoingFileView"];
    [conversationView registerNib:cellNib forIdentifier:@"RightFinishedFileView"];
    [conversationView registerNib:cellNib forIdentifier:@"PeerComposingMsgView"];
    [[conversationView.enclosingScrollView contentView] setCopiesOnScroll:NO];
    [messageView setFont: [NSFont systemFontOfSize: 14 weight: NSFontWeightLight]];
    [conversationView setWantsLayer:YES];
    draggingDestinationView.draggingDestinationDelegate = self;
}

-(void)callFinished {
    [self reloadPendingFiles];
    dispatch_async(dispatch_get_main_queue(), ^{
        [conversationView scrollToEndOfDocument:nil];
        [messageView.window makeFirstResponder: messageView];
    });
}

+(NSMutableDictionary*)pendingFiles
{
    static NSMutableDictionary* files = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        files = [[NSMutableDictionary alloc] init];
    });
    return files;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        pendingMessagesToSend = [[NSMutableDictionary alloc] init];
    }
    return self;
}

-(void) setAVModel: (lrc::api::AVModel*) avmodel {
    avModel = avmodel;
    if (recordingController == nil) {
        recordingController = [[RecordFileVC alloc] initWithNibName:@"RecordFileVC" bundle:nil avModel: self->avModel];
        recordingController.delegate = self;
    }
}

- (void)setMessage:(NSString *)newValue {
    _message = [newValue removeEmptyLinesAtBorders];
}

-(void) clearData {
    if (!convUid_.isEmpty()) {
        pendingMessagesToSend[convUid_.toNSString()] = self.message;
    }
    cachedConv_ = nil;
    convUid_ = "";
    convModel_ = nil;

    QObject::disconnect(modelSortedSignal_);
    QObject::disconnect(filterChangedSignal_);
    QObject::disconnect(interactionStatusUpdatedSignal_);
    QObject::disconnect(newInteractionSignal_);
    QObject::disconnect(peerComposingMsgSignal_);
    QObject::disconnect(lastDisplayedChanged_);
    [self closeRecordingView];
}

-(void) scrollToBottom {
    CGRect visibleRect = [conversationView enclosingScrollView].contentView.visibleRect;
    NSRange range = [conversationView rowsInRect:visibleRect];
    NSIndexSet* visibleIndexes = [NSIndexSet indexSetWithIndexesInRange:range];
    NSUInteger lastvisibleRow = [visibleIndexes lastIndex];
    NSInteger numberOfRows = [conversationView numberOfRows];
    if ((numberOfRows > 0) &&
        lastvisibleRow > (numberOfRows - 5)) {
        [conversationView scrollToEndOfDocument: nil];
    }
}

-(const lrc::api::conversation::Info*) getCurrentConversation
{
    if (convModel_ == nil || convUid_.isEmpty())
        return nil;

    if (cachedConv_ != nil)
        return cachedConv_;
    auto convOpt = getConversationFromUid(convUid_, *convModel_);
    if (convOpt.has_value()) {
        lrc::api::conversation::Info& conversation = *convOpt;
        cachedConv_ = &conversation;
    }
    return cachedConv_;
}

-(void) reloadConversationForMessage:(uint64_t) uid updateSize:(BOOL) update {
    auto* conv = [self getCurrentConversation];
    if (conv == nil)
        return;
    auto it = conv->interactions.find(uid);
    if (it == conv->interactions.end()) {
        return;
    }
    auto itIndex = distance(conv->interactions.begin(),it);
    if (itIndex >= ([conversationView numberOfRows] - 1) || itIndex >= conv->interactions.size()) {
        return;
    }
    NSRange rangeToUpdate = NSMakeRange(itIndex, 2);
    NSIndexSet* indexSet = [NSIndexSet indexSetWithIndexesInRange:rangeToUpdate];
    //reload previous message to update bubbleview
    if (itIndex > 0) {
        auto previousIt = it;
        previousIt--;
        auto previousInteraction = previousIt->second;
        if (previousInteraction.type == lrc::api::interaction::Type::TEXT) {
            NSRange range = NSMakeRange(itIndex - 1, 3);
            indexSet = [NSIndexSet indexSetWithIndexesInRange:range];
        }
    }
    if (update) {
        NSRange insertRange = NSMakeRange(itIndex, 1);
        NSIndexSet* insertRangeSet = [NSIndexSet indexSetWithIndexesInRange:insertRange];
        [conversationView removeRowsAtIndexes:insertRangeSet withAnimation:(NSTableViewAnimationEffectNone)];
        [conversationView insertRowsAtIndexes:insertRangeSet withAnimation:(NSTableViewAnimationEffectNone)];
    }
    [conversationView reloadDataForRowIndexes: indexSet
                                columnIndexes:[NSIndexSet indexSetWithIndex:0]];
    [self scrollToBottom];
}

-(void)setConversationUid:(const QString&)convUid model:(lrc::api::ConversationModel *)model
{
    if (convUid_ == convUid && convModel_ == model)
        return;

    cachedConv_ = nil;
    convUid_ = convUid;
    convModel_ = model;
    peerComposingMessage = false;
    composingMessage = false;

    // Signal triggered when messages are received or their status updated
    QObject::disconnect(newInteractionSignal_);
    QObject::disconnect(interactionStatusUpdatedSignal_);
    QObject::disconnect(peerComposingMsgSignal_);
    QObject::disconnect(lastDisplayedChanged_);
    lastDisplayedChanged_ =
    QObject::connect(convModel_,
                     &lrc::api::ConversationModel::displayedInteractionChanged,
                     [self](const QString &uid,
                            const QString &participantURI,
                            const uint64_t &previousUid,
                            const uint64_t &newdUid) {
        if (uid != convUid_)
            return;
        [self reloadConversationForMessage:newdUid updateSize: NO];
        [self reloadConversationForMessage:previousUid updateSize: NO];
    });

    peerComposingMsgSignal_ = QObject::connect(convModel_,
                                               &lrc::api::ConversationModel::composingStatusChanged,
                                               [self](const QString &uid,
                                                      const QString &contactUri,
                                                      bool isComposing) {
        if (uid != convUid_)
            return;
        bool shouldUpdate = isComposing != peerComposingMessage;
        if (!shouldUpdate) {
            return;
        }
        // reload and update height for composing indicator
        peerComposingMessage = isComposing;
        auto* conv = [self getCurrentConversation];
        if (conv == nil)
            return;
        auto row = [conversationView numberOfRows] - 1;
        if (row < 0) {
            return;
        }
        if(peerComposingMessage) {
            NSIndexSet* indexSet = [NSIndexSet indexSetWithIndex:row];
            [conversationView reloadDataForRowIndexes: indexSet
                                                       columnIndexes:[NSIndexSet indexSetWithIndex:0]];
            [conversationView noteHeightOfRowsWithIndexesChanged:indexSet];
            [self scrollToBottom];
        } else {
            //whait for possible incoming message to avoid view jumping
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                auto row = [conversationView numberOfRows] - 1;
                NSIndexSet* indexSet = [NSIndexSet indexSetWithIndex:row];
                [conversationView noteHeightOfRowsWithIndexesChanged:indexSet];
                [conversationView reloadDataForRowIndexes: indexSet
                                            columnIndexes:[NSIndexSet indexSetWithIndex:0]];
                [self scrollToBottom];
            });
        }
    });
    newInteractionSignal_ = QObject::connect(convModel_, &lrc::api::ConversationModel::newInteraction,
                                             [self](const QString& uid, uint64_t interactionId, const lrc::api::interaction::Info& interaction){
        if (uid != convUid_)
            return;
        cachedConv_ = nil;
        peerComposingMessage = false;
        [conversationView noteNumberOfRowsChanged];
        [self reloadConversationForMessage:interactionId updateSize: YES];
        [self scrollToBottom];
    });
    interactionStatusUpdatedSignal_ = QObject::connect(convModel_, &lrc::api::ConversationModel::interactionStatusUpdated,
                                                       [self](const QString& uid, uint64_t interactionId, const lrc::api::interaction::Info& interaction){
        if (uid != convUid_)
            return;
        cachedConv_ = nil;
        bool isOutgoing = lrc::api::interaction::isOutgoing(interaction);
        if (interaction.type == lrc::api::interaction::Type::TEXT && isOutgoing) {
            convModel_->refreshFilter();
        }
        [self reloadConversationForMessage:interactionId updateSize: interaction.type == lrc::api::interaction::Type::DATA_TRANSFER];
        [self scrollToBottom];
    });

    // Signals tracking changes in conversation list, we need them as cached conversation can be invalid
    // after a reordering.
    QObject::disconnect(modelSortedSignal_);
    QObject::disconnect(filterChangedSignal_);
    modelSortedSignal_ = QObject::connect(convModel_, &lrc::api::ConversationModel::modelChanged,
                                          [self](){
                                              cachedConv_ = nil;
                                          });
    filterChangedSignal_ = QObject::connect(convModel_, &lrc::api::ConversationModel::filterChanged,
                                          [self](){
                                              cachedConv_ = nil;
                                          });
    if (pendingMessagesToSend[convUid_.toNSString()]) {
        NSString *mess = pendingMessagesToSend[convUid_.toNSString()];
        self.message = pendingMessagesToSend[convUid_.toNSString()];
        [self updateSendMessageHeight];
    } else {
        self.message = @"";
        [self resetSendMessagePanelToDefaultSize];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [messageView.window makeFirstResponder: messageView];
    });
    auto* conv = [self getCurrentConversation];

    if (conv == nil)
        return;
    NSString* name = bestNameForConversation(*conv, *convModel_);
    NSString *placeholder = [NSString stringWithFormat:@"%@%@", @"Write to ", name];

    NSFont *fontName = [NSFont systemFontOfSize: 14.0 weight: NSFontWeightRegular];
    NSColor *color = [NSColor tertiaryLabelColor];
    NSDictionary *nameAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
                               fontName, NSFontAttributeName,
                               color, NSForegroundColorAttributeName,
                               nil];
    NSAttributedString* attributedPlaceholder = [[NSAttributedString alloc] initWithString: placeholder attributes:nameAttrs];
    messageView.placeholderAttributedString = attributedPlaceholder;
    [self reloadPendingFiles];
    conversationView.alphaValue = 0.0;
    [conversationView reloadData];
    [conversationView scrollToEndOfDocument:nil];
    CABasicAnimation *fadeIn = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fadeIn.fromValue = [NSNumber numberWithFloat:0.0];
    fadeIn.toValue = [NSNumber numberWithFloat:1.0];
    fadeIn.duration = 0.4f;

    [conversationView.layer addAnimation:fadeIn forKey:fadeIn.keyPath];
    conversationView.alphaValue = 1;
    try {
        [sendFileButton setEnabled:(convModel_->owner.contactModel->getContact(conv->participants[0]).profileInfo.type != lrc::api::profile::Type::SIP)];
    } catch (std::out_of_range& e) {
        NSLog(@"contact out of range");
    }
}

#pragma mark - configure cells

-(NSTableCellView*) makeGenericInteractionViewForTableView:(NSTableView*)tableView withText:(NSString*)text andTime:(NSString*) time
{
    NSTableCellView* result = [tableView makeViewWithIdentifier:@"GenericInteractionView" owner:self];
    NSTextField* textField = [result viewWithTag:GENERIC_INT_TEXT_TAG];
    NSTextField* timeField = [result viewWithTag:GENERIC_INT_TIME_TAG];

    // TODO: Fix symbol in LRC
    NSString* fixedString = [[text stringByReplacingOccurrencesOfString:@"🕽" withString:@""] stringByReplacingOccurrencesOfString:@"📞"  withString:@""];
    [textField setStringValue:fixedString];
    [timeField setStringValue:time];

    return result;
}

-(NSTableCellView*) configureViewforTransfer:(lrc::api::interaction::Info)interaction interactionID: (uint64_t) interactionID tableView:(NSTableView*)tableView
{
    IMTableCellView* result;

    auto type = interaction.type;
    auto status = interaction.status;

    NSString* fileName = @"incoming file";

    // First, view is created
    if (!interaction.authorUri.isEmpty()) {
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
                [result.progressIndicator startAnimation:conversationView];
                [result.declineButton setAction:@selector(declineIncomingFile:)];
                [result.declineButton setTarget:self];
                break;}
            case lrc::api::interaction::Status::TRANSFER_FINISHED:
                result = [tableView makeViewWithIdentifier:@"LeftFinishedFileView" owner:conversationView];
                [result.transferedFileName setAction:@selector(imagePreview:)];
                [result.transferedFileName setTarget:self];
                [result.transferedFileName.cell setHighlightsBy:NSContentsCellMask];
                break;
            case lrc::api::interaction::Status::TRANSFER_CANCELED:
            case lrc::api::interaction::Status::TRANSFER_ERROR:
                result = [tableView makeViewWithIdentifier:@"LeftFinishedFileView" owner:conversationView];
                break;
        }
    } else {
        NSString* fileName = @"sent file";
        switch (status) {
            case lrc::api::interaction::Status::TRANSFER_CREATED:
            case lrc::api::interaction::Status::TRANSFER_ONGOING:
            case lrc::api::interaction::Status::TRANSFER_AWAITING_PEER:
            case lrc::api::interaction::Status::TRANSFER_ACCEPTED:
                result = [tableView makeViewWithIdentifier:@"RightOngoingFileView" owner:conversationView];
                [result.progressIndicator startAnimation:nil];
                [result.declineButton setAction:@selector(declineIncomingFile:)];
                [result.declineButton setTarget:self];
                break;
            case lrc::api::interaction::Status::TRANSFER_FINISHED:
                result = [tableView makeViewWithIdentifier:@"RightFinishedFileView" owner:conversationView];
                [result.transferedFileName.cell setHighlightsBy:NSContentsCellMask];
                break;
            case lrc::api::interaction::Status::TRANSFER_CANCELED:
            case lrc::api::interaction::Status::TRANSFER_ERROR:
            case lrc::api::interaction::Status::TRANSFER_UNJOINABLE_PEER:
                result = [tableView makeViewWithIdentifier:@"RightFinishedFileView" owner:conversationView];
        }
    }

    // Then status label is updated if needed
    switch (status) {
            [result.statusLabel setTextColor:[NSColor textColor]];
        case lrc::api::interaction::Status::TRANSFER_FINISHED:
            [result.statusLabel setTextColor:[NSColor greenSuccessColor]];
            [result.statusLabel setStringValue:NSLocalizedString(@"Success", @"File transfer successful label")];
            break;
        case lrc::api::interaction::Status::TRANSFER_CANCELED:
            [result.statusLabel setTextColor:[NSColor orangeColor]];
            [result.statusLabel setStringValue:NSLocalizedString(@"Canceled", @"File transfer canceled label")];
            break;
        case lrc::api::interaction::Status::TRANSFER_ERROR:
            [result.statusLabel setTextColor:[NSColor errorTransferColor]];
            [result.statusLabel setStringValue:NSLocalizedString(@"Failed", @"File transfer failed label")];
            break;
        case lrc::api::interaction::Status::TRANSFER_UNJOINABLE_PEER:
             [result.statusLabel setTextColor:[NSColor textColor]];
            [result.statusLabel setStringValue:NSLocalizedString(@"Unjoinable", @"File transfer peer unjoinable label")];
            break;
    }
    result.transferedImage.image = nil;
    [result.openImagebutton setHidden:YES];
    [result.openFileButton setHidden:YES];
    [result.msgBackground setHidden:NO];
    NSString* name =  interaction.body.toNSString();
    if (name.length > 0) {
       fileName = [name lastPathComponent];
    }
    NSFont *nameFont = [NSFont systemFontOfSize: 12 weight: NSFontWeightLight];
    NSColor *nameColor = [NSColor textColor];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    paragraphStyle.alignment = NSTextAlignmentLeft;
    NSDictionary *nameAttr = [NSDictionary dictionaryWithObjectsAndKeys:nameFont,NSFontAttributeName,
                                 nameColor,NSForegroundColorAttributeName,
                                 paragraphStyle,NSParagraphStyleAttributeName, nil];
    NSAttributedString* nameAttributedString = [[NSAttributedString alloc] initWithString:fileName attributes:nameAttr];
    result.transferedFileName.attributedTitle = nameAttributedString;
    if (status == lrc::api::interaction::Status::TRANSFER_FINISHED) {
        NSColor *higlightColor = [NSColor grayColor];
        NSDictionary *alternativeNametAttr = [NSDictionary dictionaryWithObjectsAndKeys:nameFont,NSFontAttributeName,
                                  higlightColor,NSForegroundColorAttributeName,
                                  paragraphStyle,NSParagraphStyleAttributeName, nil];
        NSAttributedString* alternativeString = [[NSAttributedString alloc] initWithString:fileName attributes:alternativeNametAttr];
        result.transferedFileName.attributedAlternateTitle = alternativeString;
        NSString* path = name;
        NSImage* image = [self getImageForFilePath:name];
        if (([name rangeOfString:@"/"].location == NSNotFound)) {
            path = [self getDataTransferPath:interactionID];
            image = [self getImageForFilePath: path];
        }
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        BOOL isDir = false;
        BOOL fileExists = ([fileManager fileExistsAtPath: path isDirectory:&isDir] && !isDir);
        if(image != nil) {
            result.transferedImage.image = image;
            [result updateImageConstraintWithMax: MAX_TRANSFERED_IMAGE_SIZE];
            [result.openImagebutton setAction:@selector(imagePreview:)];
            [result.openImagebutton setTarget:self];
            [result.openImagebutton setHidden:NO];
        } else if (fileExists) {
            [result.openFileButton setAction:@selector(filePreview:)];
            [result.openFileButton setTarget:self];
            [result.openFileButton setHidden:NO];
        }
    }
    [result setupForInteraction:interactionID];
    NSDate* msgTime = [NSDate dateWithTimeIntervalSince1970:interaction.timestamp];
    NSString* timeString = [self timeForMessage: msgTime];
    result.timeLabel.stringValue = timeString;
    bool isOutgoing = lrc::api::interaction::isOutgoing(interaction);
    if (!isOutgoing) {
        @autoreleasepool {
            auto& imageManip = reinterpret_cast<Interfaces::ImageManipulationDelegate&>(GlobalInstances::pixmapManipulator());
            auto* conv = [self getCurrentConversation];
            [result.photoView setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(imageManip.conversationPhoto(*conv, convModel_->owner)))];
        }
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

    IMTableCellView* result;
    auto it = conv->interactions.begin();
    auto size = [conversationView numberOfRows] - 1;

    if (row > size || row > conv->interactions.size()) {
        return [[NSView alloc] init];
    }

    if (row == size) {
        if (size < 1) {
            return nil;
        }
        //last row peer composing view
        result = [tableView makeViewWithIdentifier:@"PeerComposingMsgView" owner:conversationView];
        result.alphaValue = 0;
        [result animateCompozingIndicator: NO];
        CGFloat alpha = peerComposingMessage ? 1 : 0;
        CGFloat height = peerComposingMessage ? HEIGHT_FOR_COMPOSING_INDICATOR : DEFAULT_ROW_HEIGHT;
        [result updateHeightConstraints: height];
        if (alpha == 1) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                if (peerComposingMessage) {
                    result.alphaValue  = alpha;
                    [result animateCompozingIndicator: YES];
                }
            });
        }
        return result;
    }

    std::advance(it, row);

    if (it == conv->interactions.end()) {
        return [[NSView alloc] init];
    }

    auto interaction = it->second;
    bool isOutgoing = lrc::api::interaction::isOutgoing(interaction);

    switch (interaction.type) {
        case lrc::api::interaction::Type::TEXT:
            if (isOutgoing) {
                result = [tableView makeViewWithIdentifier:@"RightMessageView" owner:self];
            } else {
                result = [tableView makeViewWithIdentifier:@"LeftMessageView" owner:self];
            }
            break;
        case lrc::api::interaction::Type::DATA_TRANSFER:
            return [self configureViewforTransfer:interaction interactionID: it->first tableView:tableView];
            break;
        case lrc::api::interaction::Type::CONTACT:
        case lrc::api::interaction::Type::CALL: {
            NSDate* msgTime = [NSDate dateWithTimeIntervalSince1970:interaction.timestamp];
            NSString* timeString = [self timeForMessage: msgTime];
            return [self makeGenericInteractionViewForTableView:tableView withText:interaction.body.toNSString() andTime:timeString];
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
    bool sendingFail = false;
    [result.messageStatus setHidden:YES];
    if (interaction.type == lrc::api::interaction::Type::TEXT && isOutgoing) {
        if (interaction.status == lrc::api::interaction::Status::SENDING) {
            [result.messageStatus setHidden:NO];
            [result.sendingMessageIndicator startAnimation:nil];
            [result.messageFailed setHidden:YES];
        } else if (interaction.status == lrc::api::interaction::Status::FAILURE) {
            [result.messageStatus setHidden:NO];
            [result.sendingMessageIndicator setHidden:YES];
            [result.messageFailed setHidden:NO];
            sendingFail = true;
        }
    }
    [result setupForInteraction:it->first isFailed: sendingFail];
    bool shouldDisplayTime = (sequence == FIRST_WITH_TIME || sequence == SINGLE_WITH_TIME) ? YES : NO;
    bool shouldApplyPadding = (sequence == FIRST_WITHOUT_TIME || sequence == SINGLE_WITHOUT_TIME) ? YES : NO;
    [result.msgBackground setNeedsDisplay:YES];
    [result setNeedsDisplay:YES];
    [result.timeBox setNeedsDisplay:YES];

    NSString *text = interaction.body.toNSString();
    text = [text removeEmptyLinesAtBorders];

    NSMutableAttributedString* msgAttString =
    [[NSMutableAttributedString alloc] initWithString:text
                                           attributes:[self messageAttributes]];

    CGSize messageSize = [self sizeFor: text maxWidth:tableView.frame.size.width * 0.7];

    [result updateMessageConstraint:messageSize.width  andHeight:messageSize.height timeIsVisible:shouldDisplayTime isTopPadding: shouldApplyPadding];
    [[result.msgView textStorage] appendAttributedString:msgAttString];

    NSDataDetector *linkDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil];
    NSArray *matches = [linkDetector matchesInString:result.msgView.string options:0 range:NSMakeRange(0, result.msgView.string.length)];

    [result.msgView.textStorage beginEditing];

    for (NSTextCheckingResult *match in matches) {
        if (!match.URL) continue;

        NSDictionary *linkAttributes = @{
                                         NSLinkAttributeName: match.URL,
                                         };
        [result.msgView.textStorage addAttributes:linkAttributes range:match.range];
    }

    [result.msgView.textStorage endEditing];

    if (shouldDisplayTime) {
        NSDate* msgTime = [NSDate dateWithTimeIntervalSince1970:interaction.timestamp];
        NSString* timeString = [self timeForMessage: msgTime];
        result.timeLabel.stringValue = timeString;
    }

    bool shouldDisplayAvatar = (sequence != MIDDLE_IN_SEQUENCE && sequence != FIRST_WITHOUT_TIME
                                && sequence != FIRST_WITH_TIME) ? YES : NO;
    [result.photoView setHidden:!shouldDisplayAvatar];
    BOOL showIndicator = convModel_->isLastDisplayed(convUid_, it->first, conv->participants.front());
    [result.readIndicator setHidden: !showIndicator];
    @autoreleasepool {
        auto& imageManip = reinterpret_cast<Interfaces::ImageManipulationDelegate&>(GlobalInstances::pixmapManipulator());
        auto image = QtMac::toNSImage(qvariant_cast<QPixmap>(imageManip.conversationPhoto(*conv, convModel_->owner)));
        [result.readIndicator setImage:image];
        if (!isOutgoing && shouldDisplayAvatar) {
            [result.photoView setImage:image];
        }
    }
    return result;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    try {
        double someWidth = tableView.frame.size.width * 0.7;

        auto* conv = [self getCurrentConversation];

        if (conv == nil)
            return HEIGHT_DEFAULT;

        auto size = [conversationView numberOfRows] - 1;

        if (row > size || row > conv->interactions.size()) {
            return HEIGHT_DEFAULT;
        }
        if (row == size) {
            return peerComposingMessage ? HEIGHT_FOR_COMPOSING_INDICATOR : DEFAULT_ROW_HEIGHT;
        }

        auto it = conv->interactions.begin();

        std::advance(it, row);

        if (it == conv->interactions.end()) {
            return HEIGHT_DEFAULT;
        }

        auto interaction = it->second;

        MessageSequencing sequence = [self computeSequencingFor:row];

        bool shouldDisplayTime = (sequence == FIRST_WITH_TIME || sequence == SINGLE_WITH_TIME) ? YES : NO;

        if(interaction.type == lrc::api::interaction::Type::DATA_TRANSFER) {
            if( interaction.status == lrc::api::interaction::Status::TRANSFER_FINISHED) {
                NSString* name =  interaction.body.toNSString();
                NSImage* image = [self getImageForFilePath:name];
                if (([name rangeOfString:@"/"].location == NSNotFound)) {
                    image = [self getImageForFilePath:[self getDataTransferPath:it->first]];
                }
                if (image != nil) {
                    CGFloat widthScaleFactor = MAX_TRANSFERED_IMAGE_SIZE / image.size.width;
                    CGFloat heightScaleFactor = MAX_TRANSFERED_IMAGE_SIZE / image.size.height;
                    CGFloat heigt = 0;
                    if((widthScaleFactor >= 1) && (heightScaleFactor >= 1)) {
                        heigt = image.size.height;
                    } else {
                        CGFloat scale = MIN(widthScaleFactor, heightScaleFactor);
                        heigt = image.size.height * scale;
                    }
                    return heigt + TIME_BOX_HEIGHT;
                }
            }
            return BUBBLE_HEIGHT_FOR_TRANSFERED_FILE + TIME_BOX_HEIGHT;
        }

        if(interaction.type == lrc::api::interaction::Type::CONTACT || interaction.type == lrc::api::interaction::Type::CALL)
            return GENERIC_CELL_HEIGHT;

        NSString *text = interaction.body.toNSString();
        text = [text removeEmptyLinesAtBorders];

        CGSize messageSize = [self sizeFor: text maxWidth:tableView.frame.size.width * 0.7];
        CGFloat singleLignMessageHeight = 15;

        bool shouldApplyPadding = (sequence == FIRST_WITHOUT_TIME || sequence == SINGLE_WITHOUT_TIME) ? YES : NO;

        if (shouldDisplayTime) {
            return MAX(messageSize.height + TIME_BOX_HEIGHT + MESSAGE_TEXT_PADDING * 2,
                       TIME_BOX_HEIGHT + MESSAGE_TEXT_PADDING * 2 + singleLignMessageHeight);
        }
        if(shouldApplyPadding) {
            return MAX(messageSize.height + MESSAGE_TEXT_PADDING * 2 + 15,
                       singleLignMessageHeight + MESSAGE_TEXT_PADDING * 2 + 15);
        }
        return MAX(messageSize.height + MESSAGE_TEXT_PADDING * 2,
                   singleLignMessageHeight + MESSAGE_TEXT_PADDING * 2);
    } catch (std::out_of_range& e) {
        return DEFAULT_ROW_HEIGHT;
    }
}

#pragma mark - message view parameters

-(NSString *) getDataTransferPath:(uint64_t)interactionId {
    lrc::api::datatransfer::Info info = {};
    convModel_->getTransferInfo(interactionId, info);
    double convertData = static_cast<double>(info.totalSize);
    return info.path.toNSString();
}

-(NSImage*) getImageForFilePath: (NSString *) path {
    if (path.length <= 0) {return nil;}
    if (![[NSFileManager defaultManager] fileExistsAtPath: path]) {return nil;}
    NSImage* transferedImage = [[NSImage alloc] initWithContentsOfFile: path];
    return transferedImage;
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
    try {
        auto* conv = [self getCurrentConversation];
        if (row >= conversationView.numberOfRows - 1 || row >= conv->interactions.size()) {
            return SINGLE_WITHOUT_TIME;
        }
        if (conv == nil)
            return SINGLE_WITHOUT_TIME;
        auto it = conv->interactions.begin();
        std::advance(it, row);
        if (it == conv->interactions.end()) {
            return SINGLE_WITHOUT_TIME;
        }
        auto interaction = it->second;
        if (interaction.type != lrc::api::interaction::Type::TEXT) {
            return SINGLE_WITH_TIME;
        }
        // first message in comversation
        if (row == 0) {
            if (it == conv->interactions.end() || conv->interactions.size() < 2) {
                return SINGLE_WITH_TIME;
            }
            auto nextIt = it;
            nextIt++;
            if (nextIt == conv->interactions.end()) {
                return SINGLE_WITH_TIME;
            }
            auto nextInteraction = nextIt->second;
            if ([self sequenceChangedFrom:interaction to: nextInteraction]) {
                return SINGLE_WITH_TIME;
            }
            return FIRST_WITH_TIME;
        }
        // last message in comversation
        if (row == conv->interactions.size() - 1) {
            if(it == conv->interactions.begin()) {
                return SINGLE_WITH_TIME;
            }
            auto previousIt = it;
            previousIt--;
            auto previousInteraction = previousIt->second;
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
        // single message in comversation
        if(it == conv->interactions.begin() || it == conv->interactions.end()) {
            return SINGLE_WITH_TIME;
        }
        // message in the middle of conversation
        auto previousIt = it;
        previousIt--;
        auto previousInteraction = previousIt->second;
        auto nextIt = it;
        nextIt++;
        if (nextIt == conv->interactions.end()) {
            return SINGLE_WITHOUT_TIME;
        }
        auto nextInteraction = nextIt->second;

        bool timeChanged = [self sequenceTimeChangedFrom:interaction to:previousInteraction];
        bool authorChanged = [self sequenceAuthorChangedFrom:interaction to:previousInteraction];
        bool sequenceWillChange = [self sequenceChangedFrom:interaction to: nextInteraction];
        if (previousInteraction.type == lrc::api::interaction::Type::DATA_TRANSFER) {
            if(!sequenceWillChange) {
                return FIRST_WITH_TIME;
            }
            return SINGLE_WITH_TIME;
        }
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
    } catch (std::out_of_range& e) {
        return SINGLE_WITHOUT_TIME;
    }
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
    [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:[[NSLocale currentLocale] localeIdentifier]]];
    if ([[NSCalendar currentCalendar] compareDate:today
                                           toDate:msgTime
                                toUnitGranularity:NSCalendarUnitYear]!= NSOrderedSame) {
        return [NSDateFormatter localizedStringFromDate:msgTime dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterMediumStyle];
    }
    if ([[NSCalendar currentCalendar] compareDate:today
                                           toDate:msgTime
                                toUnitGranularity:NSCalendarUnitDay]!= NSOrderedSame ||
        [[NSCalendar currentCalendar] compareDate:today
                                           toDate:msgTime
                                toUnitGranularity:NSCalendarUnitMonth]!= NSOrderedSame) {
            return [NSDateFormatter localizedStringFromDate:msgTime dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle];
    }
     return [NSDateFormatter localizedStringFromDate:msgTime dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterShortStyle];
}

- (void) updateSendMessageHeight {
    NSAttributedString *msgAttString = messageView.attributedString;
    if (!msgAttString || msgAttString.length == 0) {
        [self resetSendMessagePanelToDefaultSize];
        return;
    }
    NSRect frame = NSMakeRect(0, 0, messageView.frame.size.width, msgAttString.size.height);
    NSTextView *tv = [[NSTextView alloc] initWithFrame:frame];
    [[tv textStorage] setAttributedString:msgAttString];
    [tv sizeToFit];
    // check the height of one line and update default line height if it does not match
    NSAttributedString *firstLetter = [msgAttString attributedSubstringFromRange:NSMakeRange(0, 1)];
    auto lineHeight = firstLetter.size.height;
    // we do not want to update constraints if number of lines does not change. Save difference between actual line height and default height and use it after to check messageHeight.constant
    auto accuracy = abs(lineHeight - MESSAGE_VIEW_DEFAULT_HEIGHT);
    // top and bottom margins change for single line and multiline. MESSAGE_VIEW_DEFAULT_HEIGHT is the height of one line
    auto top = tv.frame.size.height > MESSAGE_VIEW_DEFAULT_HEIGHT ? TOP_MARGIN_MIN : TOP_MARGIN;
    auto bottom = tv.frame.size.height > MESSAGE_VIEW_DEFAULT_HEIGHT ? BOTTOM_MARGIN_MIN : BOTTOM_MARGIN;
    CGFloat heightWithMargins = tv.frame.size.height + top + bottom + SEND_PANEL_BOTTOM_MARGIN;
    CGFloat newSendPanelHeight = MIN(SEND_PANEL_MAX_HEIGHT, MAX(SEND_PANEL_DEFAULT_HEIGHT, heightWithMargins));
    CGFloat msgHeight = MAX(MESSAGE_VIEW_DEFAULT_HEIGHT, MIN(SEND_PANEL_MAX_HEIGHT - SEND_PANEL_BOTTOM_MARGIN - top, tv.frame.size.height));
    if (abs(messageHeight.constant - msgHeight) <= accuracy) {
        return;
    }
    if (MESSAGE_VIEW_DEFAULT_HEIGHT != lineHeight) {
        MESSAGE_VIEW_DEFAULT_HEIGHT = lineHeight;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.05 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self scrollToBottom];
        messageHeight.constant = msgHeight;
        textBottomConstraint.constant = bottom;
        sendPanelHeight.constant = newSendPanelHeight;
    });
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    auto* conv = [self getCurrentConversation];

    // return conversation +1 view for composing indicator
    if (conv)
        return conv->interactions.size() + 1;
    else
        return 0;
}

#pragma mark - Text formatting

- (NSMutableDictionary*) messageAttributes
{
    NSMutableDictionary* attrs = [NSMutableDictionary dictionary];
    NSFont *font = [NSFont systemFontOfSize: 12 weight: NSFontWeightLight];
    attrs[NSForegroundColorAttributeName] = [NSColor labelColor];
    attrs[NSParagraphStyleAttributeName] = [self paragraphStyle];
    attrs[NSFontAttributeName] = font;
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

#pragma mark - Actions

- (void)acceptIncomingFile:(id)sender {
    auto interId = [(IMTableCellView*)[[[[[[sender superview] superview] superview] superview] superview] superview] interaction];
    auto& inter = [self getCurrentConversation]->interactions.find(interId)->second;
    if (convModel_ && !convUid_.isEmpty()) {
        convModel_->acceptTransfer(convUid_, interId);
    }
}

- (void)declineIncomingFile:(id)sender {
    auto inter = [(IMTableCellView*)[[[[[[sender superview] superview] superview] superview] superview] superview] interaction];
    if (convModel_ && !convUid_.isEmpty()) {
        convModel_->cancelTransfer(convUid_, inter);
    }
}

- (void)filePreview:(id)sender {
    [self preview: sender isImage: false];
}

- (void)imagePreview:(id)sender {
    [self preview: sender isImage: true];
}

- (void)preview:(id)sender isImage:(BOOL)isImage {
    uint64_t interId;
    if ([[[[[[sender superview] superview] superview] superview] superview] isKindOfClass:[IMTableCellView class]]) {
        interId = [(IMTableCellView*)[[[[[sender superview] superview] superview] superview] superview] interaction];
    } else if ([[[[[sender superview] superview] superview] superview] isKindOfClass:[IMTableCellView class]]) {
        interId = [(IMTableCellView*)[[[[sender superview] superview] superview] superview] interaction];
    } else {
        return;
    }
    auto it = [self getCurrentConversation]->interactions.find(interId);
    if (it == [self getCurrentConversation]->interactions.end()) {
        return;
    }
    auto& interaction = it->second;
    NSString* name =  interaction.body.toNSString();
    if (([name rangeOfString:@"/"].location == NSNotFound)) {
        name = [self getDataTransferPath:interId];
    }
    previewImage = name;
    if (!previewImage || previewImage.length <= 0) {
        return;
    }
    if (!isImage) {
        [[NSWorkspace sharedWorkspace] selectFile: name inFileViewerRootedAtPath:nil];
        return;
    }
    [self addToResponderChain];
    if ([QLPreviewPanel sharedPreviewPanelExists] && [[QLPreviewPanel sharedPreviewPanel] isVisible]) {
        [[QLPreviewPanel sharedPreviewPanel] orderOut:nil];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[QLPreviewPanel sharedPreviewPanel] makeKeyAndOrderFront:self];
        });
    }
}

- (IBAction)sendMessage:(id)sender {
    NSString* text = self.message;
    unichar separatorChar = NSLineSeparatorCharacter;
    NSString *separatorString = [NSString stringWithCharacters:&separatorChar length:1];
    text = [text stringByReplacingOccurrencesOfString: separatorString withString: @"\n"];
    // send files
    NSMutableArray* files = [MessagesVC pendingFiles][convUid_.toNSString()];
    for (PendingFile* file : files) {
        convModel_->sendFile(convUid_, QString::fromNSString(file.fileUrl.path), QString::fromNSString(file.name));
    }
    [MessagesVC.pendingFiles removeObjectForKey: convUid_.toNSString()];
    [self reloadPendingFiles];

    if (text && text.length > 0) {
        auto* conv = [self getCurrentConversation];
        if (conv == nil)
            return;
        convModel_->sendMessage(convUid_, QString::fromNSString(text));
        self.message = @"";
        [self resetSendMessagePanelToDefaultSize];
        if (composingMessage) {
            composingMessage = false;
            convModel_->setIsComposing(convUid_, composingMessage);
        }
    }
}

-(void) resetSendMessagePanelToDefaultSize {
    if(messageHeight.constant != MESSAGE_VIEW_DEFAULT_HEIGHT) {
        sendPanelHeight.constant = SEND_PANEL_DEFAULT_HEIGHT;
        messageHeight.constant = MESSAGE_VIEW_DEFAULT_HEIGHT;
        textBottomConstraint.constant = BOTTOM_MARGIN;
        [self scrollToBottom];
    }
}

- (IBAction)openEmojy:(id)sender {
    [messageView.window makeFirstResponder: messageView];
    [NSApp orderFrontCharacterPalette: messageView];
}

- (IBAction)startVideoMessage:(id)sender
{
    [self startRecording:NO];
}

- (IBAction)startAudioMessage:(id)sender
{
    [self startRecording:YES];
}
-(void) startRecording:(BOOL)isAudio {
    if (recordingController == nil) {
        recordingController = [[RecordFileVC alloc] initWithNibName:@"RecordFileVC" bundle:nil avModel: self->avModel];
        recordingController.delegate = self;
    }
    if(recordMessagePopover != nil)
    {
        [self closeRecordingView];
        return;
    }
    recordMessagePopover = [[NSPopover alloc] init];
    [recordingController prepareRecordingView: isAudio];
    [recordMessagePopover setContentSize: recordingController.view.frame.size];
    [recordMessagePopover setContentViewController:recordingController];
    [recordMessagePopover setAnimates:YES];
    NSButton *anchorButton = isAudio ? recordAudioButton : recordVideoButton;
    [recordMessagePopover showRelativeToRect: anchorButton.bounds
                                      ofView: anchorButton
                               preferredEdge: NSMaxYEdge];
}

-(void) sendFile:(NSString *) name withFilePath:(NSString *) path {
    convModel_->sendFile(convUid_, QString::fromNSString(path), QString::fromNSString(name));
}

-(void) closeRecordingView {
    if(recordMessagePopover != nil) {
        [recordMessagePopover close];
        recordMessagePopover = nil;
        recordingController.stopRecordingView;
    }
}

- (IBAction)sendFile:(id)sender {
    NSOpenPanel* filePicker = [NSOpenPanel openPanel];
    [filePicker setCanChooseFiles:YES];
    [filePicker setCanChooseDirectories:NO];
    [filePicker setAllowsMultipleSelection:YES];

    if ([filePicker runModal] == NSFileHandlingPanelOKButton) {
        [self filesDragged: [filePicker URLs]];
    }
}


#pragma mark - NSTextViewDelegate

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (commandSelector == @selector(insertNewline:)) {
        if(self.message.length > 0 || [(NSMutableArray*)MessagesVC. pendingFiles[convUid_.toNSString()] count] > 0) {
            [self sendMessage: nil];
            return YES;
        }
        [self resetSendMessagePanelToDefaultSize];
        return YES;
    }
    return NO;
}

-(void)textDidChange:(NSNotification *)notification {
    [self checkIfComposingMsg];
    self.enableSendButton = self.message.length > 0 || [(NSMutableArray*)MessagesVC. pendingFiles[convUid_.toNSString()] count] > 0;
}

- (void) checkIfComposingMsg {
    [self updateSendMessageHeight];
    BOOL haveText = [messageView.string removeEmptyLinesAtBorders].length != 0;
    if (haveText != composingMessage) {
        composingMessage = haveText;
        convModel_->setIsComposing(convUid_, composingMessage);
    }
}

#pragma mark - QLPreviewPanelDataSource

-(void)beginPreviewPanelControl:(QLPreviewPanel *)panel
{
    panel.dataSource = self;
}

- (void)endPreviewPanelControl:(QLPreviewPanel *)panel {
    panel.dataSource = nil;
    [self removeFromResponderChain];
}

-(BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel
{
    return YES;
}

- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel {
    return 1;
}

- (id <QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)index {
    if (previewImage == nil) {
        return nil;
    }
    try {
        return [NSURL fileURLWithPath: previewImage];
    } catch (NSException *exception) {
        nil;
    }
}

- (void)addToResponderChain {
    if (conversationView.window &&
        ![[conversationView.window nextResponder] isEqual:self]) {
        NSResponder * aNextResponder = [conversationView.window nextResponder];
        [conversationView.window setNextResponder:self];
    }
}

- (void)removeFromResponderChain {
    if (conversationView.window &&
        [[conversationView.window nextResponder] isEqual:self]) {
        NSResponder * aNextResponder = [conversationView.window nextResponder];
        [conversationView.window setNextResponder:[self nextResponder]];
    }
}

#pragma mark - NSCollectionViewDataSource

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [(NSMutableArray*)MessagesVC.pendingFiles[convUid_.toNSString()] count];
}
- (NSCollectionViewItem*)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    FileToSendCollectionItem* fileCell = [collectionView makeItemWithIdentifier:@"FileToSendCollectionItem" forIndexPath:indexPath];
    PendingFile* file = MessagesVC.pendingFiles[convUid_.toNSString()][indexPath.item];
    fileCell.filePreview.image = file.preview;
    fileCell.fileName.stringValue = file.name;
    fileCell.fileName.toolTip = file.name;
    fileCell.fileSize.stringValue = file.size;
    [fileCell.closeButton setAction:@selector(removePendingFile:)];
    fileCell.closeButton.tag = indexPath.item;
    [fileCell.closeButton setTarget:self];
    return fileCell;
}

#pragma mark - DraggingDestinationDelegate

-(void)filesDragged:(NSArray*)urls {
    [self prepareFilesToSend: urls];
}

-(NSString*)convertBytedToString:(double)bytes {
    if (bytes <= 1000) {
        return [NSString stringWithFormat:@"%.2f%@", bytes, @" B"];
    } else if (bytes <= 1e6) {
        return [NSString stringWithFormat:@"%.2f%@",(bytes * 1e-3), @" KB"];
    } else if (bytes <= 1e9) {
       return [NSString stringWithFormat:@"%.2f%@",(bytes * 1e-6), @" MB"];
    }
    return [NSString stringWithFormat:@"%.2f%@",(bytes * 1e-9), @" GB"];
}

-(void)prepareFilesToSend:(NSArray*)urls {
    NSMutableArray* files = [[NSMutableArray alloc] init];
    NSMutableArray* existingFiles = MessagesVC.pendingFiles[convUid_.toNSString()];
    [files addObjectsFromArray: existingFiles];
    for (NSURL* url : urls) {
        NSString* filePath = [url path];
        NSImage* preview = [[NSImage alloc] initWithContentsOfFile: filePath];
        NSString* name = [url lastPathComponent];
        NSData* documentBytes = [[NSData alloc] initWithContentsOfFile: filePath];
        PendingFile* file = [[PendingFile alloc] init];
        file.name = name;
        file.size = [self convertBytedToString: documentBytes.length];
        file.preview = preview;
        file.fileUrl = url;
        [files addObject: file];
    }
    MessagesVC.pendingFiles[convUid_.toNSString()] = files;
    [self reloadPendingFiles];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self scrollToBottom];
    });
}

- (void)removePendingFile:(id)sender {
    NSButton* closeButton = (NSButton*)sender;
    NSInteger index = closeButton.tag;
    if(index < 0) {
        return;
    }
    [MessagesVC.pendingFiles[convUid_.toNSString()] removeObjectAtIndex:index];
    [self reloadPendingFiles];
}

- (void)reloadPendingFiles {
    self.hideFilesCollection = [(NSMutableArray*)MessagesVC .pendingFiles[convUid_.toNSString()] count]== 0;
    self.enableSendButton = self.message.length > 0 || [(NSMutableArray*)MessagesVC. pendingFiles[convUid_.toNSString()] count] > 0;
    [pendingFilesCollectionView reloadData];
}

@end
