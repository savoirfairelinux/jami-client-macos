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

#import "ChatVC.h"

#import <QItemSelectionModel>
#import <qstring.h>

#import <media/media.h>
#import <media/text.h>
#import <media/textrecording.h>
#import <callmodel.h>

@interface MediaConnectionsHolder : NSObject

@property QMetaObject::Connection newMediaAdded;
@property QMetaObject::Connection newMessage;

@end

@implementation MediaConnectionsHolder

@end

@interface ChatVC ()

@property (unsafe_unretained) IBOutlet NSTextView *chatView;
@property (unsafe_unretained) IBOutlet NSTextField *messageField;
@property (unsafe_unretained) IBOutlet NSButton *sendButton;

@property MediaConnectionsHolder* mediaHolder;

@end

@implementation ChatVC
@synthesize messageField,chatView,sendButton, mediaHolder;

- (void)awakeFromNib
{
    NSLog(@"Init ChatVC");

    [self.view setWantsLayer:YES];
    [self.view setLayer:[CALayer layer]];
    [self.view.layer setBackgroundColor:[NSColor blackColor].CGColor];

    mediaHolder = [[MediaConnectionsHolder alloc] init];

    QObject::connect(CallModel::instance().selectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {
                         [self setupChat];
                     });

    // Override default style to add interline space
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle  alloc] init];
    paragraphStyle.lineSpacing = 8;
    [chatView setDefaultParagraphStyle:paragraphStyle];
}


- (void) setupChat
{
    QObject::disconnect(mediaHolder.newMediaAdded);
    QObject::disconnect(mediaHolder.newMessage);

    QModelIndex callIdx = CallModel::instance().selectionModel()->currentIndex();

    if (!callIdx.isValid())
        return;

    Call* call = CallModel::instance().getCall(callIdx);

    /* check if text media is already present */
    if (call->hasMedia(Media::Media::Type::TEXT, Media::Media::Direction::IN)) {
        Media::Text *text = call->firstMedia<Media::Text>(Media::Media::Direction::IN);
        [self parseChatModel:text->recording()->instantMessagingModel()];
    } else if (call->hasMedia(Media::Media::Type::TEXT, Media::Media::Direction::OUT)) {
        Media::Text *text = call->firstMedia<Media::Text>(Media::Media::Direction::OUT);
        [self parseChatModel:text->recording()->instantMessagingModel()];
    } else {
        /* monitor media for messaging text messaging */
        mediaHolder.newMediaAdded = QObject::connect(call,
                                                     &Call::mediaAdded,
                                                     [self] (Media::Media* media) {
                                                         if (media->type() == Media::Media::Type::TEXT) {
                                                             QObject::disconnect(mediaHolder.newMediaAdded);
                                                             [self parseChatModel:((Media::Text*)media)->recording()->instantMessagingModel()];

                                                         }
                                                     });
    }
}

- (void) parseChatModel:(QAbstractItemModel *)model
{
    QObject::disconnect(mediaHolder.newMessage);
    [self.messageField setStringValue:@""];
    self.message = @"";
    [self.chatView.textStorage.mutableString setString:@""];

    /* put all the messages in the im model into the text view */
    for (int row = 0; row < model->rowCount(); ++row) {
        [self appendNewMessage:model->index(row, 0)];
    }

    /* append new messages */
    mediaHolder.newMessage = QObject::connect(model,
                                              &QAbstractItemModel::rowsInserted,
                                              [self, model] (const QModelIndex &parent, int first, int last) {
                                                  for (int row = first; row <= last; ++row) {
                                                      [self appendNewMessage:model->index(row, 0, parent)];
                                                  }
                                              });
}

- (void) appendNewMessage:(const QModelIndex&) msgIdx
{
    if (!msgIdx.isValid())
        return;

    NSString* message = msgIdx.data(Qt::DisplayRole).value<QString>().toNSString();
    NSString* author = msgIdx.data((int)Media::TextRecording::Role::AuthorDisplayname).value<QString>().toNSString();

    NSMutableAttributedString* attr = [[NSMutableAttributedString alloc] initWithString:
                                [NSString stringWithFormat:@"%@: %@\n",author, message]];

    // put in bold type author name
    [attr applyFontTraits:NSBoldFontMask range: NSMakeRange(0, [author length])];

    [[chatView textStorage] appendAttributedString:attr];

    // reapply paragraph style on all the text
    NSRange range = NSMakeRange(0,[chatView textStorage].length);
    [[self.chatView textStorage] addAttribute:NSParagraphStyleAttributeName
                                        value:chatView.defaultParagraphStyle
                                        range:range];

    [chatView scrollRangeToVisible:NSMakeRange([[chatView string] length], 0)];

}

- (void) takeFocus
{
    [self.view.window makeFirstResponder:self.messageField];
}

- (IBAction)sendMessage:(id)sender {

    QModelIndex callIdx = CallModel::instance().selectionModel()->currentIndex();
    Call* call = CallModel::instance().getCall(callIdx);

    /* make sure there is text to send */
    NSString* text = self.message;
    if (text && text.length > 0) {
        QMap<QString, QString> messages;
        messages["text/plain"] = QString::fromNSString(text);
        call->addOutgoingMedia<Media::Text>()->send(messages);
        // Empty the text after sending it
        [self.messageField setStringValue:@""];
        self.message = @"";
    }
}

#pragma mark - NSTextFieldDelegate

- (BOOL)control:(NSControl *)control textView:(NSTextView *)fieldEditor doCommandBySelector:(SEL)commandSelector
{
    if (commandSelector == @selector(insertNewline:) && self.message.length > 0) {
        [self sendMessage:nil];
        return YES;
    }
    return NO;
}

@end
