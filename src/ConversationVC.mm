/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
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

#import "ConversationVC.h"

#import <QItemSelectionModel>
#import <qstring.h>
#import <QPixmap>
#import <QtMacExtras/qmacfunctions.h>

#import <media/media.h>
#import <recentmodel.h>
#import <person.h>
#import <contactmethod.h>
#import <media/text.h>
#import <media/textrecording.h>
#import <callmodel.h>
#import <globalinstances.h>

#import "views/IconButton.h"
#import "views/IMTableCellView.h"
#import "views/NSColor+RingTheme.h"
#import "QNSTreeController.h"
#import "INDSequentialTextSelectionManager.h"
#import "delegates/ImageManipulationDelegate.h"
#import "SendContactRequestWC.h"
#import "PhoneDirectoryModel.h"
#import "account.h"
#import "AvailableAccountModel.h"
#import "MessagesVC.h"


#import <QuartzCore/QuartzCore.h>

@interface ConversationVC () <NSOutlineViewDelegate, MessagesVCDelegate> {

    __unsafe_unretained IBOutlet NSTextField* messageField;
    QVector<ContactMethod*> contactMethods;
    NSMutableString* textSelection;

    QMetaObject::Connection contactMethodChanged;
    ContactMethod* selectedContactMethod;
    SendContactRequestWC* sendRequestWC;

    __unsafe_unretained IBOutlet NSView* sendPanel;
    __unsafe_unretained IBOutlet NSTextField* conversationTitle;
    __unsafe_unretained IBOutlet NSTextField* emptyConversationPlaceHolder;
    __unsafe_unretained IBOutlet IconButton* sendButton;
    __unsafe_unretained IBOutlet NSPopUpButton* contactMethodsPopupButton;
    __unsafe_unretained IBOutlet NSLayoutConstraint* sentContactRequestWidth;
    __unsafe_unretained IBOutlet NSButton* sentContactRequestButton;
    IBOutlet MessagesVC* messagesViewVC;
}


@end

@implementation ConversationVC

- (void)loadView {
    [super loadView];
    // Do view setup here.
    [self.view setWantsLayer:YES];
    [self.view setLayer:[CALayer layer]];
    [self.view.layer setBackgroundColor:[NSColor ringGreyHighlight].CGColor];
    [self.view.layer setCornerRadius:5.0f];

    [sendPanel setWantsLayer:YES];
    [sendPanel setLayer:[CALayer layer]];

    [self setupChat];

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

- (void) setupChat
{
    QObject::connect(RecentModel::instance().selectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {

                         contactMethods = RecentModel::instance().getContactMethods(current);
                         if (contactMethods.isEmpty()) {
                             return ;
                         }

                         [contactMethodsPopupButton removeAllItems];
                         for (auto cm : contactMethods) {
                             [contactMethodsPopupButton addItemWithTitle:cm->uri().toNSString()];
                         }

                         [contactMethodsPopupButton setEnabled:(contactMethods.length() > 1)];

                         [emptyConversationPlaceHolder setHidden:NO];
                         // Select first cm
                         [contactMethodsPopupButton selectItemAtIndex:0];
                         [self itemChanged:contactMethodsPopupButton];
                     });
}

- (IBAction)sendMessage:(id)sender
{
    /* make sure there is text to send */
    NSString* text = self.message;
    if (text && text.length > 0) {
        QMap<QString, QString> messages;
        messages["text/plain"] = QString::fromNSString(text);
        contactMethods.at([contactMethodsPopupButton indexOfSelectedItem])->sendOfflineTextMessage(messages);
        self.message = @"";
    }
}

- (IBAction)placeCall:(id)sender
{
    if(auto cm = contactMethods.at([contactMethodsPopupButton indexOfSelectedItem])) {
        auto c = CallModel::instance().dialingCall();
        c->setPeerContactMethod(cm);
        c << Call::Action::ACCEPT;
        CallModel::instance().selectCall(c);
    }
}

- (IBAction)backPressed:(id)sender {
    RecentModel::instance().selectionModel()->clearCurrentIndex();
    messagesViewVC.delegate = nil;
}

- (IBAction)openSendContactRequestWindow:(id)sender
{
    if(auto cm = contactMethods.at([contactMethodsPopupButton indexOfSelectedItem])) {
        sendRequestWC = [[SendContactRequestWC alloc] initWithWindowNibName:@"SendContactRequest"];
        sendRequestWC.contactMethod = cm;
        [sendRequestWC.window makeKeyAndOrderFront:sendRequestWC.window];
    }
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

-(BOOL)shouldHideSendRequestBtn {
    /*to send contact request we need to meet thre condition:
     1)contact method has RING protocol
     2)accound is used to send request is also RING
     3)contact  have not acceppt request yet*/
    if(selectedContactMethod->protocolHint() != URI::ProtocolHint::RING) {
        return YES;
    }
    if(selectedContactMethod->isConfirmed()) {
        return YES;
    }
    if(selectedContactMethod->account()) {
        return selectedContactMethod->account()->protocol() != Account::Protocol::RING;
    }
    if([self chosenAccount]) {
        return [self chosenAccount]->protocol() != Account::Protocol::RING;
    }
    return NO;
}

-(void)updateSendButtonVisibility
{
    [sentContactRequestButton setHidden:[self shouldHideSendRequestBtn]];
    sentContactRequestWidth.priority = [self shouldHideSendRequestBtn] ? 999: 250;
}

#pragma mark - NSPopUpButton item selection

- (IBAction)itemChanged:(id)sender {
    NSInteger index = [(NSPopUpButton *)sender indexOfSelectedItem];

    selectedContactMethod = contactMethods.at(index);

    [self updateSendButtonVisibility];

    [conversationTitle setStringValue:selectedContactMethod->primaryName().toNSString()];
    QObject::disconnect(contactMethodChanged);
    contactMethodChanged = QObject::connect(selectedContactMethod,
                                            &ContactMethod::changed,
                                            [self] {
                                                [conversationTitle setStringValue:selectedContactMethod->primaryName().toNSString()];
                                                [self updateSendButtonVisibility];
                                            });

    if (auto txtRecording = selectedContactMethod->textRecording()) {
        messagesViewVC.delegate = self;
        [messagesViewVC setUpViewWithModel:txtRecording->instantMessagingModel()];
        [self.view.window makeFirstResponder:messageField];
    }
}

#pragma mark - MessagesVC delegate

-(void) newMessageAdded {

    if (auto txtRecording = contactMethods.at([contactMethodsPopupButton indexOfSelectedItem])->textRecording()) {
        [emptyConversationPlaceHolder setHidden:txtRecording->instantMessagingModel()->rowCount() > 0];
        txtRecording->setAllRead();
    }
}

@end
