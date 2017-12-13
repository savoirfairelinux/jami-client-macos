/*
 *  Copyright (C) 2015-2016 Savoir-faire Linux Inc.
 *  Author: Alexandre Lision <alexandre.lision@savoirfairelinux.com>
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

#import "ChatVC.h"

#import "MessagesVC.h"

@interface ChatVC () <MessagesVCDelegate>
{
    IBOutlet MessagesVC* messagesViewVC;

    lrc::api::conversation::Info* conv_;
    lrc::api::ConversationModel* convModel_;
}

@property (unsafe_unretained) IBOutlet NSTextField *messageField;
@property (unsafe_unretained) IBOutlet NSButton *sendButton;

@end

@implementation ChatVC


@synthesize messageField,sendButton;

- (void)awakeFromNib
{
    NSLog(@"Init ChatVC");

    [self.view setWantsLayer:YES];
    [self.view setLayer:[CALayer layer]];
    [self.view.layer setBackgroundColor:[NSColor controlColor].CGColor];

    messagesViewVC.delegate = self;
}

-(void)setConversation:(lrc::api::conversation::Info *)conv model:(lrc::api::ConversationModel *)model
{
    conv_ = conv;
    convModel_ = model;

    [messagesViewVC setConversation:conv_ model:convModel_];
}

#pragma mark - MessagesVC delegate

-(void) newMessageAdded {
    // TODO : Remove if we don't do anything when displaying new messages
}

- (void) takeFocus
{
    [self.view.window makeFirstResponder:self.messageField];
}

- (IBAction)sendMessage:(id)sender {
    /* make sure there is text to send */
    NSString* text = self.message;
    if (text && text.length > 0) {
        convModel_->sendMessage(conv_->uid, std::string([text UTF8String]));
        self.message = @"";
        [messageField setStringValue:@""];
        [messagesViewVC newMessageSent];
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
