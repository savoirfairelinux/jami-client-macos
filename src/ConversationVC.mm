/*
 *  Copyright (C) 2016-2019 Savoir-faire Linux Inc.
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
#import "delegates/ImageManipulationDelegate.h"

#import <qstring.h>
#import <QPixmap>
#import <QtMacExtras/qmacfunctions.h>
#import <QuartzCore/QuartzCore.h>
#import <QuickLook/QuickLook.h>
#import <Quartz/Quartz.h>

#import <globalinstances.h>

#import "views/IconButton.h"
#import "views/HoverButton.h"
#import "views/IMTableCellView.h"
#import "views/NSColor+RingTheme.h"
#import "delegates/ImageManipulationDelegate.h"
#import "MessagesVC.h"
#import "utils.h"
#import "RingWindowController.h"
#import "NSString+Extensions.h"
#import "LeaveMessageVC.h"

@interface ConversationVC () <QLPreviewPanelDataSource, QLPreviewPanelDelegate>{

    __unsafe_unretained IBOutlet NSTextField* conversationTitle;
    __unsafe_unretained IBOutlet NSTextField *conversationID;
    __unsafe_unretained IBOutlet HoverButton *addContactButton;
    __unsafe_unretained IBOutlet NSLayoutConstraint* sentContactRequestWidth;
    // invitation view
    __unsafe_unretained IBOutlet NSView* invitationView;
    __unsafe_unretained IBOutlet NSImageView* invitationAvatar;
    __unsafe_unretained IBOutlet NSTextField *invitationTitle;
    __unsafe_unretained IBOutlet NSTextField *invitationMessage;
    __unsafe_unretained IBOutlet NSTextField *invitationLabel;
    __unsafe_unretained IBOutlet NSView *invitationBox;
    __unsafe_unretained IBOutlet NSButton *invitationBlock;
    __unsafe_unretained IBOutlet NSButton *invitationRefuse;
    __unsafe_unretained IBOutlet NSButton *invitationAccept;
    __unsafe_unretained IBOutlet NSStackView* invitationControls;

    __unsafe_unretained IBOutlet NSButton* sentContactRequestButton;
    IBOutlet MessagesVC* messagesViewVC;
    LeaveMessageVC* leaveMessageVC;

    IBOutlet NSLayoutConstraint *titleCenteredConstraint;
    IBOutlet NSLayoutConstraint* titleTopConstraint;

    QString convUid_;
    const lrc::api::conversation::Info* cachedConv_;
    lrc::api::ConversationModel* convModel_;

    RingWindowController* delegate;
    NSMutableArray* leaveMessageConversations;

    // All those connections are needed to invalidate cached conversation as pointer
    // may not be referencing the same conversation anymore
    QMetaObject::Connection modelSortedConnection_, filterChangedConnection_, newConversationConnection_, conversationRemovedConnection_, creatingConversationEventConnection_;
}

@end

NSInteger const MEESAGE_MARGIN = 21;
NSInteger const SEND_PANEL_DEFAULT_HEIGHT = 60;
NSInteger const SEND_PANEL_MAX_HEIGHT = 120;

@implementation ConversationVC

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil delegate:(RingWindowController*) mainWindow aVModel:(lrc::api::AVModel*) avModel
{
    if (self = [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        delegate = mainWindow;
        leaveMessageVC = [[LeaveMessageVC alloc] initWithNibName:@"LeaveMessageVC" bundle:nil];
        [[leaveMessageVC view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [self.view addSubview:[leaveMessageVC view] positioned:NSWindowAbove relativeTo:nil];
        [leaveMessageVC initFrame];
        [leaveMessageVC setAVModel: avModel];
        leaveMessageConversations = [[NSMutableArray alloc] init];
        leaveMessageVC.delegate = self;
        [messagesViewVC setAVModel: avModel];
        //setup the invitation view
        invitationView.wantsLayer = true;
        invitationView.layer.backgroundColor = [[NSColor windowBackgroundColor] CGColor];
        NSString *invitationText = NSLocalizedString(@"Hello, \nWould you like to join the conversation?", @"Incoming conversation request title");
        [self setInvitationText: invitationText];
        invitationBox.wantsLayer = true;
        invitationBox.layer.cornerRadius = 20.0;
        invitationBox.layer.backgroundColor = [[[NSColor controlColor] colorWithAlphaComponent: 0.7] CGColor];
        invitationBox.shadow = [[NSShadow alloc] init];
        invitationBox.layer.shadowOpacity = 0.2;
        invitationBox.layer.shadowColor = [[NSColor colorWithRed:0 green:0 blue:0 alpha:0.3] CGColor];
        invitationBox.layer.shadowOffset = NSMakeSize(0, -3);
        invitationBox.layer.shadowRadius = 10;
    }
    return self;
}

- (void)setInvitationText:(NSString*)text
{
    NSFont *font = [NSFont systemFontOfSize: 18 weight: NSFontWeightMedium];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setLineSpacing: 4.0];
    paragraphStyle.alignment = NSTextAlignmentCenter;

    NSDictionary *attrDic = [NSDictionary dictionaryWithObjectsAndKeys: font, NSFontAttributeName, paragraphStyle, NSParagraphStyleAttributeName, [NSColor controlTextColor], NSForegroundColorAttributeName, nil];
    NSAttributedString *attrString = [[NSAttributedString alloc] initWithString: text attributes:attrDic];
    [invitationTitle setAttributedStringValue: attrString];
}

-(NSViewController*) getMessagesView {
    return messagesViewVC;
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
    QObject::disconnect(creatingConversationEventConnection_);
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

-(void) setConversationUid:(const QString&)convUid model:(lrc::api::ConversationModel *)model {
    if (convUid_ == convUid && convModel_ == model)
        return;
    [self clearData];
    cachedConv_ = nil;
    convUid_ = convUid;
    convModel_ = model;

    [messagesViewVC setConversationUid:convUid_ model:convModel_];

    if (convUid_.isEmpty() || convModel_ == nil)
        return;
    if([leaveMessageConversations containsObject:convUid_.toNSString()]) {
        [leaveMessageVC setConversationUID: convUid_ conversationModel: convModel_];
    } else {
        [leaveMessageVC hide];
    }

    // Signals tracking changes in conversation list, we need them as cached conversation can be invalid
    // after a reordering.
    QObject::disconnect(modelSortedConnection_);
    QObject::disconnect(filterChangedConnection_);
    QObject::disconnect(newConversationConnection_);
    QObject::disconnect(conversationRemovedConnection_);
    QObject::disconnect(creatingConversationEventConnection_);
    modelSortedConnection_ = QObject::connect(convModel_, &lrc::api::ConversationModel::modelChanged,
                                          [self](){
                                              cachedConv_ = nil;
        auto* conv = [self getCurrentConversation];

        if (conv == nil)
            return;
        [self updateInvitationView: conv];
                                          });
    filterChangedConnection_ = QObject::connect(convModel_, &lrc::api::ConversationModel::filterChanged,
                                            [self](){
                                                cachedConv_ = nil;
                                            });
    newConversationConnection_ = QObject::connect(convModel_, &lrc::api::ConversationModel::newConversation,
                                                [self](){
                                                    cachedConv_ = nil;
        auto* conv = [self getCurrentConversation];

        if (conv == nil)
            return;
        [self updateInvitationView: conv];
                                                });
    conversationRemovedConnection_ = QObject::connect(convModel_, &lrc::api::ConversationModel::conversationRemoved,
                                                [self](){
                                                    cachedConv_ = nil;
                                                });
    creatingConversationEventConnection_ =  QObject::connect(convModel_, &lrc::api::ConversationModel::creatingConversationEvent,
                                                             [self](const QString& accountId, const QString& conversationId, const QString& participantURI, int status) {

    });

    auto* conv = [self getCurrentConversation];

    if (conv == nil)
        return;

    // Setup UI elements according to new conversation
    NSString* bestName = bestNameForConversation(*conv, *convModel_);
    NSString* bestId = bestIDForConversation(*conv, *convModel_);
    [conversationTitle setStringValue: bestName];
    [conversationID setStringValue: bestId];

    BOOL hideBestId = [bestNameForConversation(*conv, *convModel_) isEqualTo:bestIDForConversation(*conv, *convModel_)];

    [conversationID setHidden:hideBestId];
    [titleCenteredConstraint setActive:hideBestId];
    [titleTopConstraint setActive:!hideBestId];
    auto accountType = convModel_->owner.profileInfo.type;
    try {
        [addContactButton setHidden:((convModel_->owner.contactModel->getContact(conv->participants[0]).profileInfo.type != lrc::api::profile::Type::TEMPORARY) || accountType == lrc::api::profile::Type::SIP)];
    } catch (std::out_of_range& e) {
        [addContactButton setHidden: true];
        NSLog(@"contact out of range");
    }
    if (!conv->allMessagesLoaded) {
        convModel_->loadConversationMessages(convUid_, 0);
    }
    @autoreleasepool {
        auto& imageManip = reinterpret_cast<Interfaces::ImageManipulationDelegate&>(GlobalInstances::pixmapManipulator());
        auto image = QtMac::toNSImage(qvariant_cast<QPixmap>(imageManip.conversationPhoto(*conv, convModel_->owner, QSize(110, 110))));
        [invitationAvatar setImage:image];
    }
    [self updateInvitationView: conv];
}

- (void)updateInvitationView:(const lrc::api::conversation::Info*) conversation {
    self.isRequest = conversation->isRequest;
    NSString* bestName = bestNameForConversation(*conversation, *convModel_);
    bool showInvitationView = conversation->isRequest || (convModel_->owner.profileInfo.type == lrc::api::profile::Type::JAMI && conversation->interactions.size() == 0);
    invitationView.hidden = !showInvitationView;
    invitationBlock.enabled = !conversation->needsSyncing && conversation->isRequest;
    invitationRefuse.enabled = !conversation->needsSyncing && conversation->isRequest;
    invitationAccept.enabled = !conversation->needsSyncing && conversation->isRequest;
    invitationControls.hidden = conversation->needsSyncing || !conversation->isRequest;
    invitationLabel.hidden = conversation->needsSyncing || !conversation->isRequest;
    invitationMessage.hidden = !(conversation->isRequest && conversation->needsSyncing);
    if (!showInvitationView) {
        return;
    }
    if (conversation->isRequest && conversation->needsSyncing) {
        NSString *syncTitle = [NSString stringWithFormat:
                               NSLocalizedString(@"We are waiting for %@ connects to synchronize the conversation.",@"Synchronization label for conversation {Name}"),
                               bestName];
        invitationMessage.stringValue = syncTitle;
        NSString *waitSync = NSLocalizedString(@"You have accepted the conversation request.", @"Synchronization explanation label");
        [self setInvitationText: waitSync];
    } else if (conversation->isRequest) {
        NSString *invitationReceived = NSLocalizedString(@"Hello, \nWould you like to join the conversation?", @"Incoming conversation request title");
        [self setInvitationText: invitationReceived];
    } else {
        NSString *sendInvitationText1 = NSLocalizedString(@"Send him/her a contact request to be able to exchange together.", @"Send request explanation");
        invitationMessage.stringValue = sendInvitationText1;
        NSString *sendInvitationText = [NSString stringWithFormat:
                               NSLocalizedString(@"%@ is not in your contacts.", @"Send request to {Name}"),
                               bestName];
        [self setInvitationText: sendInvitationText];
    }
}

- (void) initFrame
{
    [self.view setFrame:self.view.superview.bounds];
    [self.view setHidden:YES];
    self.view.layer.position = self.view.frame.origin;
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
    [messagesViewVC clearData];
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

- (void) presentLeaveMessageView {
    [leaveMessageVC setConversationUID: convUid_ conversationModel: convModel_];
    [leaveMessageConversations addObject:convUid_.toNSString()];
}

-(void) messageCompleted {
    [leaveMessageConversations removeObject:convUid_.toNSString()];
}

- (IBAction) acceptInvitation:(id)sender {
    convModel_->makePermanent(convUid_);
}

- (IBAction) refuseInvitation:(id)sender {
    convModel_->removeConversation(convUid_);
}

- (IBAction) blockInvitation:(id)sender {
    convModel_->removeConversation(convUid_, true);
}

@end
