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
#import "RingWindowController.h"
#import <QuartzCore/QuartzCore.h>
#include <qrencode.h>

//LRC
#import <api/lrc.h>
#import <api/account.h>
#import <api/newaccountmodel.h>
#import <api/newcallmodel.h>
#import <api/behaviorcontroller.h>
#import <api/conversation.h>
#import <api/contactmodel.h>
#import <api/contact.h>
#import <api/datatransfermodel.h>
#import <api/avmodel.h>

// Ring
#import "AppDelegate.h"
#import "Constants.h"
#import "CurrentCallVC.h"
#import "MigrateRingAccountsWC.h"
#import "ConversationVC.h"
#import "PreferencesWC.h"
#import "SmartViewVC.h"
#import "views/IconButton.h"
#import "views/NSColor+RingTheme.h"
#import "views/HoverButton.h"
#import "utils.h"
#import "RingWizardWC.h"
#import "AccountSettingsVC.h"

typedef NS_ENUM(NSInteger, ViewState) {
    SHOW_WELCOME_SCREEN = 0,
    SHOW_CONVERSATION_SCREEN,
    SHOW_CALL_SCREEN,
    SHOW_SETTINGS_SCREEN,
    HIDE_SETTINGS_SCREEN,
    LEAVE_MESSAGE,
};

@interface RingWindowController () <MigrateRingAccountsDelegate>

@property (retain) MigrateRingAccountsWC* migrateWC;
@property RingWizardWC* wizard;
@property QMetaObject::Connection callState;

@end

@implementation RingWindowController {

    __unsafe_unretained IBOutlet NSLayoutConstraint* centerYQRCodeConstraint;
    __unsafe_unretained IBOutlet NSLayoutConstraint* centerYWelcomeContainerConstraint;
    IBOutlet NSLayoutConstraint* ringLabelTrailingConstraint;
    __unsafe_unretained IBOutlet NSView* welcomeContainer;
    __unsafe_unretained IBOutlet NSView* callView;
    __unsafe_unretained IBOutlet NSTextField* ringIDLabel;
    __unsafe_unretained IBOutlet NSTextField* explanationLabel;
    __unsafe_unretained IBOutlet NSButton* shareButton;
    __unsafe_unretained IBOutlet NSImageView* qrcodeView;

    PreferencesWC* preferencesWC;
    IBOutlet SmartViewVC* smartViewVC;

    CurrentCallVC* currentCallVC;
    ConversationVC* conversationVC;
    AccountSettingsVC* settingsVC;

    IBOutlet ChooseAccountVC* chooseAccountVC;
}

@synthesize dataTransferModel, accountModel, behaviorController, avModel;
@synthesize wizard;

-(id) initWithWindowNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil accountModel:( lrc::api::NewAccountModel*)accountModel dataTransferModel:( lrc::api::DataTransferModel*)dataTransferModel behaviourController:( lrc::api::BehaviorController*) behaviorController avModel: (lrc::api::AVModel*)avModel
{
    if (self =  [self initWithWindowNibName:nibNameOrNil])
    {
        self.accountModel = accountModel;
        self.dataTransferModel = dataTransferModel;
        self.behaviorController = behaviorController;
        self.avModel = avModel;
        self.avModel->useAVFrame(YES);
        [NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(themeChanged:) name:@"AppleInterfaceThemeChangedNotification" object: nil];
    }
    return self;
}

-(void) deinit {
    [NSDistributedNotificationCenter.defaultCenter removeObserver:self];

}

- (NSApplicationPresentationOptions)window:(NSWindow *)window willUseFullScreenPresentationOptions:(NSApplicationPresentationOptions)proposedOptions
{
    return (NSApplicationPresentationFullScreen |
            NSApplicationPresentationAutoHideMenuBar |
            NSApplicationPresentationAutoHideToolbar);
}

-(void)changeViewTo:(ViewState) state  {
    switch (state) {
        case SHOW_WELCOME_SCREEN:
            [self accountSettingsShouldOpen: NO];
            [conversationVC hideWithAnimation:false];
            [currentCallVC hideWithAnimation:false];
            [currentCallVC cleanUp];
            [currentCallVC.view removeFromSuperview];
            [welcomeContainer setHidden: NO];
            [smartViewVC.view setHidden: NO];
            [settingsVC hide];
            break;
        case SHOW_CONVERSATION_SCREEN:
            [self accountSettingsShouldOpen: NO];
            [conversationVC showWithAnimation:false];
            [currentCallVC hideWithAnimation:false];
            [currentCallVC cleanUp];
            [currentCallVC.view removeFromSuperview];
            [welcomeContainer setHidden: YES];
            [smartViewVC.view setHidden: NO];
            [settingsVC hide];
            break;
        case SHOW_CALL_SCREEN:
            self.avModel->useAVFrame(YES);
            [self accountSettingsShouldOpen: NO];
            if (![currentCallVC.view superview]) {
            [callView addSubview:[currentCallVC view] positioned:NSWindowAbove relativeTo:nil];
            [currentCallVC initFrame];
            [currentCallVC showWithAnimation:false];
            [conversationVC hideWithAnimation:false];
            [welcomeContainer setHidden: YES];
            [smartViewVC.view setHidden: NO];
            [settingsVC hide];
            }
            [currentCallVC showWithAnimation:false];
            break;
        case SHOW_SETTINGS_SCREEN:
            @try {
                [self accountSettingsShouldOpen: YES];
            }
            @catch (NSException *ex) {
                return;
            }
            [smartViewVC.view setHidden: YES];
            [settingsVC show];
            break;
        case LEAVE_MESSAGE:
            [conversationVC showWithAnimation: false];
            [currentCallVC hideWithAnimation: false];
            [conversationVC presentLeaveMessageView];
        case HIDE_SETTINGS_SCREEN:
            [self accountSettingsShouldOpen: NO];
            [smartViewVC.view setHidden: NO];
            [settingsVC hide];
        default:
            break;
    }
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [self.window setMovableByWindowBackground:YES];
    [qrcodeView setWantsLayer: YES];

    self.window.titleVisibility = NSWindowTitleHidden;
    self.window.titlebarAppearsTransparent = true;

    currentCallVC = [[CurrentCallVC alloc] initWithNibName:@"CurrentCall" bundle:nil];
    currentCallVC.delegate = self;
    conversationVC = [[ConversationVC alloc] initWithNibName:@"Conversation" bundle:nil delegate:self aVModel:self.avModel];
    [chooseAccountVC updateWithDelegate: self andModel:self.accountModel];
    settingsVC = [[AccountSettingsVC alloc] initWithNibName:@"AccountSettings" bundle:nil accountmodel:self.accountModel];
    [callView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [[currentCallVC view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [[conversationVC view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [[settingsVC view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

    [callView addSubview:[conversationVC view] positioned:NSWindowAbove relativeTo:nil];
    [self.window.contentView addSubview:[settingsVC view] positioned:NSWindowAbove relativeTo:nil];

    [conversationVC initFrame];
    [settingsVC initFrame];

    [self checkAccountsToMigrate];

    // set download folder (default - 'Documents')
    NSString* path = [[NSUserDefaults standardUserDefaults] stringForKey:Preferences::DownloadFolder];
    if (!path || path.length == 0) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        path = [[paths objectAtIndex:0] stringByAppendingString:@"/"];
    }
    self.dataTransferModel->downloadDirectory = QString::fromNSString(path);
    if(appSandboxed()) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        avModel->setRecordPath(QString::fromNSString([paths objectAtIndex:0]));
    } else if (avModel->getRecordPath().isEmpty()) {
        avModel->setRecordPath(QString::fromNSString(NSHomeDirectory()));
    }
    NSToolbar *tb = [[self window] toolbar];
    [tb setAllowsUserCustomization:NO];

    //add messages view controller to responders chain
    NSResponder * viewNextResponder = [self nextResponder];
    [self setNextResponder: [conversationVC getMessagesView]];
    [[conversationVC getMessagesView] setNextResponder: viewNextResponder];
}

- (void) connect
{
    QObject::connect(self.behaviorController,
                     &lrc::api::BehaviorController::showCallView,
                     [self](const QString& accountId,
                            const lrc::api::conversation::Info convInfo){
        auto* accInfo = &self.accountModel->getAccountInfo(accountId);
        try {
            if (accInfo->contactModel->getContact(convInfo.participants[0]).profileInfo.type == lrc::api::profile::Type::PENDING)
                [smartViewVC selectPendingList];
            else
                [smartViewVC selectConversationList];

            [currentCallVC setCurrentCall:convInfo.callId
                             conversation:convInfo.uid
                                  account:accInfo
                                  avModel: avModel];
            [self changeViewTo:SHOW_CALL_SCREEN];
            [conversationVC setConversationUid:convInfo.uid model:accInfo->conversationModel.get()];
        } catch (std::out_of_range& e) {
            NSLog(@"contact out of range");
        }
    });

    QObject::connect(self.behaviorController,
                     &lrc::api::BehaviorController::showIncomingCallView,
                     [self](const QString& accountId,
                            const lrc::api::conversation::Info convInfo){
        auto* accInfo = &self.accountModel->getAccountInfo(accountId);
        try {
            if (accInfo->contactModel->getContact(convInfo.participants[0]).profileInfo.type == lrc::api::profile::Type::PENDING)
                [smartViewVC selectPendingList];
            else
                [smartViewVC selectConversationList];
            [currentCallVC setCurrentCall:convInfo.callId
                             conversation:convInfo.uid
                                  account:accInfo
                                  avModel: avModel];
            [smartViewVC selectConversation: convInfo model:accInfo->conversationModel.get()];
            [self changeViewTo:SHOW_CALL_SCREEN];
            [conversationVC setConversationUid:convInfo.uid model:accInfo->conversationModel.get()];
        } catch (std::out_of_range& e) {
            NSLog(@"contact out of range");
        }
    });

    QObject::connect(self.behaviorController,
                     &lrc::api::BehaviorController::showChatView,
                     [self](const QString& accountId,
                            const lrc::api::conversation::Info& convInfo){
                         auto& accInfo = self.accountModel->getAccountInfo(accountId);
                         [conversationVC setConversationUid:convInfo.uid model:accInfo.conversationModel.get()];
                         [smartViewVC selectConversation: convInfo model:accInfo.conversationModel.get()];
                         [self changeViewTo:SHOW_CONVERSATION_SCREEN];
                     });
    QObject::connect(self.behaviorController,
                     &lrc::api::BehaviorController::showLeaveMessageView,
                     [self](const QString& accountId,
                            const lrc::api::conversation::Info& convInfo){
                         auto& accInfo = self.accountModel->getAccountInfo(accountId);
                         [conversationVC setConversationUid:convInfo.uid model:accInfo.conversationModel.get()];
                         [smartViewVC selectConversation: convInfo model:accInfo.conversationModel.get()];
                         [self changeViewTo:LEAVE_MESSAGE];
                     });
}

#pragma mark - Ring account migration

- (void) migrateRingAccount:(const QString&) acc
{
    self.migrateWC = [[MigrateRingAccountsWC alloc] initWithDelegate:self actionCode:1];
    self.migrateWC.accountModel = self.accountModel;
    self.migrateWC.accountToMigrate = acc;
    [self.window beginSheet:self.migrateWC.window completionHandler:nil];
}

- (void)checkAccountsToMigrate
{
    auto accounts = self.accountModel->getAccountList();
    for (auto accountId: accounts) {
        const lrc::api::account::Info& accountInfo = self.accountModel->getAccountInfo(accountId);
        if (accountInfo.status == lrc::api::account::Status::ERROR_NEED_MIGRATION) {
            [self migrateRingAccount:accountInfo.id];
            return;
        }
    }
    @try {
        [smartViewVC setConversationModel: [chooseAccountVC selectedAccount].conversationModel.get()];
    }
    @catch (NSException *ex) {
        NSLog(@"Caught exception %@: %@", [ex name], [ex reason]);
    }
    [shareButton sendActionOn:NSLeftMouseDownMask];
    [self connect];
    [self updateRingID];
    [self connectCallSignalsForAccount];
}

- (void)connectCallSignalsForAccount
{
    @try {
        auto& account = [chooseAccountVC selectedAccount];
        QObject::disconnect(self.callState);
        auto *callModel = account.callModel.get();
        self.callState = QObject::connect(callModel,
                                          &lrc::api::NewCallModel::callStatusChanged,
                                          [self, callModel](const QString& callId) {
                                              if (callModel->hasCall(callId)) {
                                                  auto call = callModel->getCall(callId);
                                                  [smartViewVC reloadConversationWithURI: call.peerUri.toNSString()];
                                              }
                                          });
    } @catch (NSException *ex) {
    }
}

- (void)migrationDidComplete
{
    [self checkAccountsToMigrate];
}

- (void)migrationDidCompleteWithError
{
    [self checkAccountsToMigrate];
}

/**
 * Implement the necessary logic to choose which Ring ID to display.
 * This tries to choose the "best" ID to show
 */
- (void) updateRingID
{
    @try {
        auto& account = [chooseAccountVC selectedAccount];

        [ringIDLabel setStringValue:@""];

        if(account.profileInfo.type != lrc::api::profile::Type::RING) {
            self.notRingAccount = YES;
            self.isSIPAccount = YES;
            return;
        }
        self.isSIPAccount = NO;
        self.notRingAccount = NO;
        [ringLabelTrailingConstraint setActive:YES];
        auto& registeredName = account.registeredName;
        auto& ringID = account.profileInfo.uri;
        NSString* uriToDisplay = nullptr;
        if (!registeredName.isEmpty()) {
            uriToDisplay = registeredName.toNSString();
            [explanationLabel setStringValue: NSLocalizedString(@"This is your Jami username. \nCopy and share it with your friends!", @"Explanation label when user have Jami username")];
        } else {
            uriToDisplay = ringID.toNSString();
            [explanationLabel setStringValue: NSLocalizedString(@"This is your ID. \nCopy and share it with your friends!", @"Explanation label when user have just ID")];
        }
        [ringIDLabel setStringValue:uriToDisplay];
        [self drawQRCode: ringID.toNSString()];
    }
    @catch (NSException *ex) {
        NSLog(@"Caught exception %@: %@", [ex name], [ex reason]);
        self.notRingAccount = YES;
        self.isSIPAccount = NO;
        [ringLabelTrailingConstraint setActive:NO];
        [ringIDLabel setStringValue:NSLocalizedString(@"No account available", @"Displayed as RingID when no accounts are available for selection")];
    }
}

- (IBAction)shareRingID:(id)sender {
    NSSharingServicePicker* sharingServicePicker = [[NSSharingServicePicker alloc] initWithItems:[NSArray arrayWithObject:[ringIDLabel stringValue]]];
    [sharingServicePicker setDelegate:self];
    [sharingServicePicker showRelativeToRect:[sender bounds]
                                      ofView:sender
                               preferredEdge:NSMinYEdge];
}

- (IBAction)toggleQRCode:(id)sender {
    // Toggle pressed state of QRCode button
  //  [sender setPressed:![sender isPressed]];
    bool show = qrcodeView.animator.alphaValue == 0.0f ? YES: NO;
    [self showQRCode: show];
}

/**
 * Draw the QRCode in the qrCodeView
 */
- (void)drawQRCode:(NSString*) uriToDraw
{
    auto qrCode = QRcode_encodeString(uriToDraw.UTF8String,
                                      0,
                                      QR_ECLEVEL_L, // Lowest level of error correction
                                      QR_MODE_8, // 8-bit data mode
                                      1);
    if (!qrCode) {
        return;
    }

    unsigned char *data = 0;
    int width;
    data = qrCode->data;
    width = qrCode->width;
    int qr_margin = 3;

    CGFloat size = qrcodeView.frame.size.width;

    // create context
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(0, size, size, 8, size * 4, colorSpace, kCGImageAlphaPremultipliedLast);

    CGAffineTransform translateTransform = CGAffineTransformMakeTranslation(0, -size);
    CGAffineTransform scaleTransform = CGAffineTransformMakeScale(1, -1);
    CGContextConcatCTM(ctx, CGAffineTransformConcat(translateTransform, scaleTransform));

    float zoom = ceil((double)size / (qrCode->width + 2.0 * qr_margin));
    CGRect rectDraw = CGRectMake(0, 0, zoom, zoom);

    int ran;
    for(int i = 0; i < width; ++i) {
        for(int j = 0; j < width; ++j) {
            if(*data & 1) {
                CGContextSetFillColorWithColor(ctx, [NSColor blackColor].CGColor);
                rectDraw.origin = CGPointMake((j + qr_margin) * zoom,(i + qr_margin) * zoom);
                CGContextAddRect(ctx, rectDraw);
                CGContextFillPath(ctx);
            } else {
                CGContextSetFillColorWithColor(ctx, [NSColor clearColor].CGColor);
                rectDraw.origin = CGPointMake((j + qr_margin) * zoom,(i + qr_margin) * zoom);
                CGContextAddRect(ctx, rectDraw);
                CGContextFillPath(ctx);
            }
            ++data;
        }
    }

    // get image
    auto qrCGImage = CGBitmapContextCreateImage(ctx);
    auto qrImage = [[NSImage alloc] initWithCGImage:qrCGImage size:qrcodeView.frame.size];

    // some releases
    CGContextRelease(ctx);
    CGImageRelease(qrCGImage);
    CGColorSpaceRelease(colorSpace);
    QRcode_free(qrCode);

    [qrcodeView setImage:qrImage];
}

/**
 * Start the in/out animation displaying the QRCode
 * @param show should the QRCode be animated in or out
 */
- (void) showQRCode:(BOOL) show
{
    [self updateQRCodeBackground];
    static const NSInteger offset = 110;
    [NSAnimationContext beginGrouping];
    NSAnimationContext.currentContext.duration = 0.5;
    [[NSAnimationContext currentContext] setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault]];
    qrcodeView.animator.alphaValue = show ? 1.0 : 0.0;
    [centerYQRCodeConstraint.animator setConstant: show ? offset : 0];
    [centerYWelcomeContainerConstraint.animator setConstant:show ? -offset : 0];
    [NSAnimationContext endGrouping];
}

-(void)themeChanged:(NSNotification *) notification {
    if (qrcodeView.animator.alphaValue == 1) {
        [self updateQRCodeBackground];
    }
}

-(void)updateQRCodeBackground {
    if (@available(*, macOS 10.14)) {
        NSString *interfaceStyle = [NSUserDefaults.standardUserDefaults valueForKey:@"AppleInterfaceStyle"];
        if ([interfaceStyle isEqualToString:@"Dark"]) {
            qrcodeView.layer.backgroundColor = [[NSColor whiteColor] CGColor];
        } else {
            qrcodeView.layer.backgroundColor = [[NSColor clearColor] CGColor];
        }
    }
}

- (IBAction)openPreferences:(id)sender
{
    if (preferencesWC) {
        [preferencesWC.window orderFront:preferencesWC.window];
        return;
    }

    preferencesWC = [[PreferencesWC alloc] initWithWindowNibName: @"PreferencesWindow" bundle: nil accountModel:self.accountModel dataTransferModel:self.dataTransferModel behaviourController:self.behaviorController avModel: self.avModel];
    [preferencesWC.window makeKeyAndOrderFront:preferencesWC.window];
}

- (IBAction)callClickedAtRow:(id)sender
{
    NSTabViewItem *selectedTab = [smartViewVC.tabbar selectedTabViewItem];
    int index = [smartViewVC.tabbar indexOfTabViewItem:selectedTab];
    switch (index) {
        case 0:
            [smartViewVC startCallForRow:sender];
            break;
        default:
            break;
    }
}

- (void) selectAccount:(const lrc::api::account::Info&)accInfo currentRemoved:(BOOL) removed
{
    // If the selected account has been changed, we close any open panel
    [smartViewVC setConversationModel:accInfo.conversationModel.get()];
    // Welcome view informations are also updated
    [self updateRingID];
    [settingsVC setSelectedAccount:accInfo.id];
    [self changeViewTo: ([settingsVC.view isHidden] || removed) ? SHOW_WELCOME_SCREEN : SHOW_SETTINGS_SCREEN];
    [self connectCallSignalsForAccount];
}

-(void)allAccountsDeleted
{
    [smartViewVC clearConversationModel];
    [self changeViewTo:SHOW_WELCOME_SCREEN];
    [self updateRingID];
    qrcodeView.animator.alphaValue = 0.0;
    [centerYQRCodeConstraint.animator setConstant: 0];
    [centerYWelcomeContainerConstraint.animator setConstant: 0];
    QObject::disconnect(self.callState);
    [self close];
    AppDelegate* delegate = (AppDelegate*)[[NSApplication sharedApplication] delegate];
    [delegate showWizard];
}

-(void)rightPanelClosed
{
    [smartViewVC deselect];
    [welcomeContainer setHidden:NO];
}

-(void)currentConversationTrusted
{
    [smartViewVC selectConversationList];
}

-(void) listTypeChanged {
    [self changeViewTo:SHOW_WELCOME_SCREEN];
}

- (IBAction)openAccountSettings:(NSButton *)sender
{
    [self changeViewTo: [settingsVC.view isHidden] ? SHOW_SETTINGS_SCREEN : HIDE_SETTINGS_SCREEN];
}

- (void) createNewAccount {
    [self changeViewTo:SHOW_WELCOME_SCREEN];
    wizard = [[RingWizardWC alloc] initWithNibName:@"RingWizard" bundle: nil accountmodel: self.accountModel];
    [wizard showChooseWithCancelButton: YES];
    [self.window beginSheet:wizard.window completionHandler:nil];
}

- (NSRect)window:(NSWindow *)window willPositionSheet:(NSWindow *)sheet
       usingRect:(NSRect)rect
{
    float titleBarHeight = self.window.frame.size.height - [NSWindow contentRectForFrameRect:self.window.frame styleMask:self.window.styleMask].size.height;
    rect.origin.y = self.window.frame.size.height;
    return rect;
}

-(void) accountSettingsShouldOpen: (BOOL) open {
    if (open) {
        [settingsVC setSelectedAccount: [chooseAccountVC selectedAccount].id];
    }
}

#pragma mark - CallViewControllerDelegate

-(void) conversationInfoUpdatedFor:(const QString&) conversationID {
    [smartViewVC reloadConversationWithUid:conversationID.toNSString()];
}

-(void) callFinished {
    [self changeViewTo:SHOW_CONVERSATION_SCREEN];
}

-(void) showConversation:(NSString* )conversationId forAccount:(NSString*)accountId {
    auto& accInfo = self.accountModel->getAccountInfo(QString::fromNSString(accountId));
    [chooseAccountVC selectAccount: accountId];
    [settingsVC setSelectedAccount: QString::fromNSString(accountId)];
    [smartViewVC setConversationModel:accInfo.conversationModel.get()];
    [smartViewVC selectConversationList];
    [self updateRingID];
    auto convInfo = getConversationFromUid(QString::fromNSString(conversationId), *accInfo.conversationModel.get(), true);
    if (conversationExists(convInfo, *accInfo.conversationModel.get(), true)) {
        [conversationVC setConversationUid:convInfo->uid model:accInfo.conversationModel.get()];
        [smartViewVC selectConversation: *convInfo model:accInfo.conversationModel.get()];
        accInfo.conversationModel.get()->clearUnreadInteractions(QString::fromNSString(conversationId));
    }
    [self changeViewTo:SHOW_CONVERSATION_SCREEN];
}

-(void) showCall:(NSString* )callId forAccount:(NSString*)accountId forConversation:(NSString*)conversationId {
    auto& accInfo = self.accountModel->getAccountInfo(QString::fromNSString(accountId));
    [chooseAccountVC selectAccount: accountId];
    [settingsVC setSelectedAccount:accInfo.id];
    [smartViewVC setConversationModel:accInfo.conversationModel.get()];
    [self updateRingID];
    auto convInfo = getConversationFromUid(QString::fromNSString(conversationId), *accInfo.conversationModel.get(), true);
    if (conversationExists(convInfo, *accInfo.conversationModel.get(), true)) {
        if (accInfo.contactModel->getContact(convInfo->participants[0]).profileInfo.type == lrc::api::profile::Type::PENDING)
            [smartViewVC selectPendingList];
        else
            [smartViewVC selectConversationList];
        [smartViewVC selectConversation: *convInfo model:accInfo.conversationModel.get()];
    }
    [currentCallVC setCurrentCall:QString::fromNSString(callId)
                     conversation:QString::fromNSString(conversationId)
                          account:&accInfo
                          avModel:avModel];
    [self changeViewTo:SHOW_CALL_SCREEN];
}

-(void) showContactRequestFor:(NSString* )accountId contactUri:(NSString*)uri {
    auto& accInfo = self.accountModel->getAccountInfo(QString::fromNSString(accountId));
    [chooseAccountVC selectAccount: accountId];
    [settingsVC setSelectedAccount:accInfo.id];
    [smartViewVC setConversationModel:accInfo.conversationModel.get()];
    [self updateRingID];
    [smartViewVC selectPendingList];
    auto convInfo = getConversationFromURI(QString::fromNSString(uri), *accInfo.conversationModel.get());
    auto convQueue = accInfo.conversationModel.get()->allFilteredConversations();
    if (convInfo != convQueue.end()) {
        [conversationVC setConversationUid:convInfo->uid model:accInfo.conversationModel.get()];
        [smartViewVC selectConversation: *convInfo model:accInfo.conversationModel.get()];
    }
    [self changeViewTo:SHOW_CONVERSATION_SCREEN];
}

@end
