/*
 *  Copyright (C) 2015-2017 Savoir-faire Linux Inc.
 *  Author: Alexandre Lision <alexandre.lision@savoirfairelinux.com>
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

#import "ChatVC.h"

#import "MessagesVC.h"
#import "NSString+Extensions.h"

@interface ChatVC ()
{
    IBOutlet MessagesVC* messagesViewVC;

    QString convUid_;
    lrc::api::ConversationModel* convModel_;
}

@property (unsafe_unretained) IBOutlet NSTextField *messageField;
@property (unsafe_unretained) IBOutlet NSButton *sendButton;

@end

@implementation ChatVC


@synthesize messageField,sendButton;

-(void)setConversationUid:(const QString&)convUid model:(lrc::api::ConversationModel *)model
{
    convUid_ = convUid;
    convModel_ = model;

    [messagesViewVC setConversationUid:convUid_ model:convModel_];
}

- (void) takeFocus
{
    [self.view.window makeFirstResponder:self.messageField];
}

- (void)setMessage:(NSString *)newValue {
    _message = [newValue removeEmptyLinesAtBorders];
}

- (void) clearData {
    [messagesViewVC clearData];
}

- (IBAction)sendMessage:(id)sender {
    /* make sure there is text to send */
    NSString* text = self.message;
    if (text && text.length > 0) {
        convModel_->sendMessage(convUid_, QString::fromNSString(text));
        self.message = @"";
        [messageField setStringValue:@""];
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
