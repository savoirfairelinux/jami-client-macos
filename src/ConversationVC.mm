/*
 *  Copyright (C) 2016-2018 Savoir-faire Linux Inc.
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

#import "ConversationVC.h"

#import <QItemSelectionModel>
#import <qstring.h>
#import <QPixmap>
#import <QtMacExtras/qmacfunctions.h>

// LRC
#import <globalinstances.h>

#import "views/IconButton.h"
#import "views/HoverButton.h"
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
#import "RingWindowController.h"
#import "NSString+Extensions.h"

#import <QuartzCore/QuartzCore.h>

@interface ConversationVC () {

    __unsafe_unretained IBOutlet NSTextField* messageField;
    NSMutableString* textSelection;

    __unsafe_unretained IBOutlet NSView* sendPanel;
    __unsafe_unretained IBOutlet NSTextField* conversationTitle;
    __unsafe_unretained IBOutlet NSTextField *conversationID;
    __unsafe_unretained IBOutlet IconButton* sendButton;
    __unsafe_unretained IBOutlet IconButton *sendFileButton;
    __unsafe_unretained IBOutlet HoverButton *addContactButton;
    __unsafe_unretained IBOutlet NSLayoutConstraint* sentContactRequestWidth;
    __unsafe_unretained IBOutlet NSButton* sentContactRequestButton;
    IBOutlet MessagesVC* messagesViewVC;

    IBOutlet NSLayoutConstraint *titleCenteredConstraint;
    IBOutlet NSLayoutConstraint* titleTopConstraint;

    std::string convUid_;
    const lrc::api::conversation::Info* cachedConv_;
    lrc::api::ConversationModel* convModel_;

    RingWindowController* delegate;

    // All those connections are needed to invalidate cached conversation as pointer
    // may not be referencing the same conversation anymore
    QMetaObject::Connection modelSortedConnection_, filterChangedConnection_, newConversationConnection_, conversationRemovedConnection_;

}


@end

@implementation ConversationVC

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil delegate:(RingWindowController*) mainWindow
{
    if (self = [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        delegate = mainWindow;
    }
    return self;
}

- (void)setMessage:(NSString *)newValue {
    _message = [newValue removeEmptyLinesAtBorders];
}

-(void) clearData {
    cachedConv_ = nil;
    convUid_ = "";
    convModel_ = nil;

    [messagesViewVC clearData];
    QObject::disconnect(modelSortedConnection_);
    QObject::disconnect(filterChangedConnection_);
    QObject::disconnect(newConversationConnection_);
    QObject::disconnect(conversationRemovedConnection_);
}

-(const lrc::api::conversation::Info*) getCurrentConversation
{
    if (convModel_ == nil || convUid_.empty())
        return nil;

    if (cachedConv_ != nil)
        return cachedConv_;

    auto convQueue = convModel_->allFilteredConversations();

    auto it = getConversationFromUid(convUid_, *convModel_);

    if (it != convQueue.end())
        cachedConv_ = &(*it);

    return cachedConv_;
}

-(void) setConversationUid:(const std::string)convUid model:(lrc::api::ConversationModel *)model {
    if (convUid_ == convUid && convModel_ == model)
        return;
    [self clearData];
    cachedConv_ = nil;
    convUid_ = convUid;
    convModel_ = model;

    [messagesViewVC setConversationUid:convUid_ model:convModel_];

    if (convUid_.empty() || convModel_ == nil)
        return;

    // Signals tracking changes in conversation list, we need them as cached conversation can be invalid
    // after a reordering.
    QObject::disconnect(modelSortedConnection_);
    QObject::disconnect(filterChangedConnection_);
    QObject::disconnect(newConversationConnection_);
    QObject::disconnect(conversationRemovedConnection_);
    modelSortedConnection_ = QObject::connect(convModel_, &lrc::api::ConversationModel::modelSorted,
                                          [self](){
                                              cachedConv_ = nil;
                                          });
    filterChangedConnection_ = QObject::connect(convModel_, &lrc::api::ConversationModel::filterChanged,
                                            [self](){
                                                cachedConv_ = nil;
                                            });
    newConversationConnection_ = QObject::connect(convModel_, &lrc::api::ConversationModel::newConversation,
                                                [self](){
                                                    cachedConv_ = nil;
                                                });
    conversationRemovedConnection_ = QObject::connect(convModel_, &lrc::api::ConversationModel::conversationRemoved,
                                                [self](){
                                                    cachedConv_ = nil;
                                                });

    auto* conv = [self getCurrentConversation];

    if (conv == nil)
        return;

    // Setup UI elements according to new conversation
    NSString* bestName = bestNameForConversation(*conv, *convModel_);
    NSString* bestId = bestIDForConversation(*conv, *convModel_);
    [conversationTitle setStringValue: bestName];
    [conversationID setStringValue: bestId];
    [sendFileButton setEnabled:(convModel_->owner.contactModel->getContact(conv->participants[0]).profileInfo.type != lrc::api::profile::Type::SIP)];

    BOOL hideBestId = [bestNameForConversation(*conv, *convModel_) isEqualTo:bestIDForConversation(*conv, *convModel_)];

    [conversationID setHidden:hideBestId];
    [titleCenteredConstraint setActive:hideBestId];
    [titleTopConstraint setActive:!hideBestId];
    auto accountType = convModel_->owner.profileInfo.type;
    [addContactButton setHidden:((convModel_->owner.contactModel->getContact(conv->participants[0]).profileInfo.type != lrc::api::profile::Type::TEMPORARY) || accountType == lrc::api::profile::Type::SIP)];
}

- (void)loadView {
    [super loadView];
    // Do view setup here.
   // [self.view setWantsLayer:YES];
  //  [self.view setLayer:[CALayer layer]];
   // [self.view.layer setBackgroundColor:[NSColor ringGreyHighlight].CGColor];
   // [self.view.layer setCornerRadius:5.0f];

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
        auto* conv = [self getCurrentConversation];
        bool isPending = convModel_->owner.contactModel->getContact(conv->participants[0]).profileInfo.type == lrc::api::profile::Type::PENDING;
        convModel_->sendMessage(convUid_, std::string([text UTF8String]));
        self.message = @"";
        if (isPending)
            [delegate currentConversationTrusted];
    }
}

- (IBAction)sendFile:(id)sender
{
    NSOpenPanel* filePicker = [NSOpenPanel openPanel];
    [filePicker setCanChooseFiles:YES];
    [filePicker setCanChooseDirectories:NO];
    [filePicker setAllowsMultipleSelection:NO];

    if ([filePicker runModal] == NSFileHandlingPanelOKButton) {
        if ([[filePicker URLs] count] == 1) {
            NSURL* url = [[filePicker URLs] objectAtIndex:0];
            const char* fullPath = [url fileSystemRepresentation];
            NSString* fileName = [url lastPathComponent];
            if (convModel_) {
                auto* conv = [self getCurrentConversation];
                bool isPending = convModel_->owner.contactModel->getContact(conv->participants[0]).profileInfo.type == lrc::api::profile::Type::PENDING;

                convModel_->sendFile(convUid_, std::string(fullPath), std::string([fileName UTF8String]));

                if (isPending)
                    [delegate currentConversationTrusted];
            }
        }
    }
}

- (IBAction)placeCall:(id)sender
{
    auto* conv = [self getCurrentConversation];
    convModel_->placeCall(conv->uid);
}

- (IBAction)placeAudioCall:(id)sender
{
    auto* conv = [self getCurrentConversation];
    convModel_->placeAudioOnlyCall(conv->uid);
}

- (IBAction)addContact:(id)sender
{
    auto* conv = [self getCurrentConversation];
    convModel_->makePermanent(conv->uid);
}

- (IBAction)backPressed:(id)sender {
    [delegate rightPanelClosed];
    [self hideWithAnimation:false];
}

# pragma mark private IN/OUT animations

-(void) showWithAnimation:(BOOL)animate
{
    if (!animate) {
        [self.view setHidden:NO];
        return;
    }

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

-(void) hideWithAnimation:(BOOL)animate
{
    if(self.view.frame.origin.x < 0) {
        return;
    }

    [self clearData];

    if (!animate) {
        [self.view setHidden:YES];
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


@end
