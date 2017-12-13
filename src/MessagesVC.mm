/*
 *  Copyright (C) 2015-2017 Savoir-faire Linux Inc.
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

@interface MessagesVC () <NSTableViewDelegate, NSTableViewDataSource> {

    __unsafe_unretained IBOutlet NSTableView* conversationView;

    const lrc::api::conversation::Info* conv_;
    const lrc::api::ConversationModel* convModel_;

    QMetaObject::Connection newMessageSignal_;
}

@property (nonatomic, strong, readonly) INDSequentialTextSelectionManager* selectionManager;

@end

@implementation MessagesVC

-(void)setConversation:(const lrc::api::conversation::Info *)conv model:(const lrc::api::ConversationModel *)model {
    conv_ = conv;
    convModel_ = model;

    QObject::disconnect(newMessageSignal_);
    newMessageSignal_ = QObject::connect(convModel_, &lrc::api::ConversationModel::newUnreadMessage,
                                         [self](const std::string& uid, uint64_t msgId, const lrc::api::interaction::Info& msg){
                                             if (uid != conv_->uid)
                                                 return;
                                             [conversationView reloadData];
                                             [conversationView scrollToEndOfDocument:nil];
                                         });

    [conversationView reloadData];
    [conversationView scrollToEndOfDocument:nil];
}

-(void)newMessageSent
{
    [conversationView reloadData];
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
    if(convModel_ == nil || conv_ == nil) {
        return nil;
    }

    // HACK HACK HACK HACK HACK
    // The following code has to be replaced when every views are implemented for every interaction types
    // This is an iterator which "jumps over" any interaction which is not a text one.
    // It behaves as if interaction list was only containing text interactions.
    std::map<uint64_t, lrc::api::interaction::Info>::const_iterator it;

    {
        int msgCount = 0;
        it = std::find_if(conv_->interactions.begin(), conv_->interactions.end(), [&msgCount, row](const std::pair<uint64_t, lrc::api::interaction::Info>& inter) {
            if (inter.second.type == lrc::api::interaction::Type::TEXT) {
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

    if (it == conv_->interactions.end())
        return nil;

    IMTableCellView* result;

    auto& interaction = it->second;

    // TODO Implement interactions other than messages
    if(interaction.type != lrc::api::interaction::Type::TEXT) {
        return nil;
    }

    bool isOutgoing = lrc::api::interaction::isOutgoing(interaction);

    if (isOutgoing) {
        result = [tableView makeViewWithIdentifier:@"RightMessageView" owner:self];
    } else {
        result = [tableView makeViewWithIdentifier:@"LeftMessageView" owner:self];
    }

    // check if the message first in incoming or outgoing messages sequence
    Boolean isFirstInSequence = true;
    if (it != conv_->interactions.begin()) {
        auto previousIt = it;
        previousIt--;
        auto& previousInteraction = previousIt->second;
        if (previousInteraction.type == lrc::api::interaction::Type::TEXT && (isOutgoing == lrc::api::interaction::isOutgoing(previousInteraction)))
            isFirstInSequence = false;
    }
    [result.photoView setHidden:!isFirstInSequence];
    result.msgBackground.needPointer = isFirstInSequence;
    [result setup];

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
    [result.photoView setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(imageManip.conversationPhoto(*conv_, convModel_->owner)))];
    return result;
}

- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
    if (IMTableCellView* cellView = [tableView viewAtColumn:0 row:row makeIfNecessary:NO]) {
        [self.selectionManager registerTextView:cellView.msgView withUniqueIdentifier:@(row).stringValue];
    }
    [self.delegate newMessageAdded];
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    double someWidth = tableView.frame.size.width * 0.7;

    if(convModel_ == nil || conv_ == nil) {
        return 0;
    }

    // HACK HACK HACK HACK HACK
    // The following code has to be replaced when every views are implemented for every interaction types
    // This is an iterator which "jumps over" any interaction which is not a text one.
    // It behaves as if interaction list was only containing text interactions.
    std::map<uint64_t, lrc::api::interaction::Info>::const_iterator it;

    {
        int msgCount = 0;
        it = std::find_if(conv_->interactions.begin(), conv_->interactions.end(), [&msgCount, row](const std::pair<uint64_t, lrc::api::interaction::Info>& inter) {
            if (inter.second.type == lrc::api::interaction::Type::TEXT) {
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

    if (it == conv_->interactions.end())
        return 0;

    auto& interaction = it->second;

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
    if (conv_) {
        int count;
        count = std::count_if(conv_->interactions.begin(), conv_->interactions.end(), [](const std::pair<uint64_t, lrc::api::interaction::Info>& inter) {
            return inter.second.type == lrc::api::interaction::Type::TEXT;
        });
        return count;
    }
    return 0;

    // TODO: Replace current code by the following one when every interactions implemented
//    if (conv_) {
//        return conv_->interactions.size();
//    }
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

@end
