/*
 *  Copyright (C) 2016-2017 Savoir-faire Linux Inc.
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

#import "ConversationVC.h"

#import <QItemSelectionModel>
#import <qstring.h>
#import <QPixmap>
#import <QtMacExtras/qmacfunctions.h>

// LRC
#import <globalinstances.h>

#import "views/IconButton.h"
#import "views/IMTableCellView.h"
#import "views/NSColor+RingTheme.h"
#import "QNSTreeController.h"
#import "INDSequentialTextSelectionManager.h"
#import "delegates/ImageManipulationDelegate.h"
#import "PhoneDirectoryModel.h"
#import "account.h"
#import "AvailableAccountModel.h"
#import "MessagesVC.h"
#import "utils.h"

#import <QuartzCore/QuartzCore.h>

@interface ConversationVC () <MessagesVCDelegate> {

    __unsafe_unretained IBOutlet NSTextField* messageField;
    NSMutableString* textSelection;

    __unsafe_unretained IBOutlet NSView* sendPanel;
    __unsafe_unretained IBOutlet NSTextField* conversationTitle;
    __unsafe_unretained IBOutlet NSTextField* emptyConversationPlaceHolder;
    __unsafe_unretained IBOutlet IconButton* sendButton;
    __unsafe_unretained IBOutlet NSPopUpButton* contactMethodsPopupButton;
    __unsafe_unretained IBOutlet NSLayoutConstraint* sentContactRequestWidth;
    __unsafe_unretained IBOutlet NSButton* sentContactRequestButton;
    IBOutlet MessagesVC* messagesViewVC;

    IBOutlet NSLayoutConstraint* titleHoverButtonConstraint;
    IBOutlet NSLayoutConstraint* titleTopConstraint;

    const lrc::api::conversation::Info* conv_;
    lrc::api::ConversationModel* convModel_;
}


@end

@implementation ConversationVC

-(void) setConversation:(const lrc::api::conversation::Info *)conv model:(lrc::api::ConversationModel *)model {
    conv_ = conv;
    convModel_ = model;

    [messagesViewVC setConversation:conv_ model:convModel_];

    if (conv_ == nil || convModel_ == nil)
        return;

    // Setup UI elements according to new conversation
    NSString* bestName = bestNameForConversation(*conv_, *convModel_);
    [conversationTitle setStringValue: bestName];

    [contactMethodsPopupButton setEnabled:NO];
    [contactMethodsPopupButton setBordered:NO];
    BOOL hideCMPopupButton = [bestNameForConversation(*conv_, *convModel_) isEqualTo:bestIDForConversation(*conv_, *convModel_)];
    [contactMethodsPopupButton setHidden:hideCMPopupButton];

    [titleHoverButtonConstraint setActive:hideCMPopupButton];
    [titleTopConstraint setActive:!hideCMPopupButton];

    [emptyConversationPlaceHolder setHidden:NO];
}

- (void)loadView {
    [super loadView];
    // Do view setup here.
    [self.view setWantsLayer:YES];
    [self.view setLayer:[CALayer layer]];
    [self.view.layer setBackgroundColor:[NSColor ringGreyHighlight].CGColor];
    [self.view.layer setCornerRadius:5.0f];

    [messageField setFocusRingType:NSFocusRingTypeNone];
}

-(Account* ) chosenAccount
{
    QModelIndex index = AvailableAccountModel::instance().selectionModel()->currentIndex();
    if(!index.isValid()) {
        return nullptr;
    }
    Account* account = index.data(static_cast<int>(Account::Role::Object)).value<Account*>();
    return account;
}

- (void) initFrame
{
    [self.view setFrame:self.view.superview.bounds];
    [self.view setHidden:YES];
    self.view.layer.position = self.view.frame.origin;
}

- (IBAction)sendMessage:(id)sender
{
    /* make sure there is text to send */
    NSString* text = self.message;
    if (text && text.length > 0) {
        convModel_->sendMessage(conv_->uid, std::string([text UTF8String]));
        self.message = @"";
        [messagesViewVC newMessageSent];
    }
}

- (IBAction)placeCall:(id)sender
{
    convModel_->placeCall(conv_->uid);
}

- (IBAction)backPressed:(id)sender {
//    RecentModel::instance().selectionModel()->clearCurrentIndex();
//    messagesViewVC.delegate = nil;
}

# pragma mark private IN/OUT animations

-(void) animateIn
{
    CGRect frame = CGRectOffset(self.view.superview.bounds, -self.view.superview.bounds.size.width, 0);
    [self.view setHidden:NO];

    [CATransaction begin];
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
    [animation setFromValue:[NSValue valueWithPoint:frame.origin]];
    [animation setToValue:[NSValue valueWithPoint:self.view.superview.bounds.origin]];
    [animation setDuration:0.2f];
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn]];
    [self.view.layer addAnimation:animation forKey:animation.keyPath];

    [CATransaction commit];
}

-(void) animateOut
{
    if(self.view.frame.origin.x < 0) {
        return;
    }

    CGRect frame = CGRectOffset(self.view.frame, -self.view.frame.size.width, 0);
    [CATransaction begin];
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
    [animation setFromValue:[NSValue valueWithPoint:self.view.frame.origin]];
    [animation setToValue:[NSValue valueWithPoint:frame.origin]];
    [animation setDuration:0.2f];
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];

    [CATransaction setCompletionBlock:^{
        [self.view setHidden:YES];
    }];
    [self.view.layer addAnimation:animation forKey:animation.keyPath];

    [self.view.layer setPosition:frame.origin];
    [CATransaction commit];
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

#pragma mark - MessagesVC delegate

-(void) newMessageAdded {
    // TODO : Remove if we don't do anything when displaying new messages
}

@end
