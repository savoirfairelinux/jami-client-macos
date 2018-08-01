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
#include <memory>

//Qt
#import <QItemSelectionModel>
#import <QItemSelection>

//LRC
#import <callmodel.h>
#import <account.h>
#import <call.h>
#import <recentmodel.h>
#import <AvailableAccountModel.h>
#import <api/lrc.h>
#import <api/account.h>
#import <api/newaccountmodel.h>
#import <api/newcallmodel.h>
#import <api/behaviorcontroller.h>
#import <api/conversation.h>
#import <api/contactmodel.h>
#import <api/contact.h>
#import <api/datatransfermodel.h>
#import <media/recordingmodel.h>

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
#import "views/BackgroundView.h"
#import "ChooseAccountVC.h"
#import "utils.h"

@interface RingWindowController () <MigrateRingAccountsDelegate, NSToolbarDelegate>

@property (retain) MigrateRingAccountsWC* migrateWC;

@end

@implementation RingWindowController {

    __unsafe_unretained IBOutlet NSLayoutConstraint* centerYQRCodeConstraint;
    __unsafe_unretained IBOutlet NSLayoutConstraint* centerYWelcomeContainerConstraint;
    IBOutlet NSLayoutConstraint* ringLabelTrailingConstraint;
    __unsafe_unretained IBOutlet NSView* welcomeContainer;
    __unsafe_unretained IBOutlet NSView* callView;
    __unsafe_unretained IBOutlet NSTextField* ringIDLabel;
    __unsafe_unretained IBOutlet NSButton* shareButton;
    __unsafe_unretained IBOutlet NSImageView* qrcodeView;

    std::unique_ptr<lrc::api::Lrc> lrc_;

    PreferencesWC* preferencesWC;
    IBOutlet SmartViewVC* smartViewVC;

    CurrentCallVC* currentCallVC;
    ConversationVC* conversationVC;

    // toolbar menu items
    ChooseAccountVC* chooseAccountVC;
}

static NSString* const kPreferencesIdentifier        = @"PreferencesIdentifier";
NSString* const kChangeAccountToolBarItemIdentifier  = @"ChangeAccountToolBarItemIdentifier";

- (void)windowDidLoad {
    [super windowDidLoad];
    [self.window setMovableByWindowBackground:YES];

    [self.window setBackgroundColor:[NSColor colorWithRed:242.0/255 green:242.0/255 blue:242.0/255 alpha:1.0]];
    self.window.titleVisibility = NSWindowTitleHidden;

    lrc_ = std::make_unique<lrc::api::Lrc>();

    currentCallVC = [[CurrentCallVC alloc] initWithNibName:@"CurrentCall" bundle:nil];
    conversationVC = [[ConversationVC alloc] initWithNibName:@"Conversation" bundle:nil delegate:self];
    // toolbar items
    chooseAccountVC = [[ChooseAccountVC alloc] initWithNibName:@"ChooseAccount" bundle:nil model:&(lrc_->getAccountModel()) delegate:self];
    [callView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [[currentCallVC view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [[conversationVC view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

    [callView addSubview:[currentCallVC view] positioned:NSWindowAbove relativeTo:nil];
    [callView addSubview:[conversationVC view] positioned:NSWindowAbove relativeTo:nil];

    [currentCallVC initFrame];
    [conversationVC initFrame];
    @try {
        [smartViewVC setConversationModel: [chooseAccountVC selectedAccount].conversationModel.get()];
    }
    @catch (NSException *ex) {
        NSLog(@"Caught exception %@: %@", [ex name], [ex reason]);
    }

    // Fresh run, we need to make sure RingID appears
    [shareButton sendActionOn:NSLeftMouseDownMask];

    [self connect];
    [self updateRingID];
    // display accounts to select
    NSToolbar *toolbar = self.window.toolbar;
    toolbar.delegate = self;
    [toolbar insertItemWithItemIdentifier:kChangeAccountToolBarItemIdentifier atIndex:1];
    // set download folder (default - 'Documents')
    NSString* path = [[NSUserDefaults standardUserDefaults] stringForKey:Preferences::DownloadFolder];
    if (!path || path.length == 0) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        path = [[paths objectAtIndex:0] stringByAppendingString:@"/"];
    }
    lrc_->getDataTransferModel().downloadDirectory = std::string([path UTF8String]);
    if(appSandboxed()) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        media::RecordingModel::instance().setRecordPath(QString::fromNSString([paths objectAtIndex:0]));
    }
}

- (void) connect
{
    QObject::connect(&lrc_->getBehaviorController(),
                     &lrc::api::BehaviorController::showCallView,
                     [self](const std::string accountId,
                            const lrc::api::conversation::Info convInfo){
                         auto* accInfo = &lrc_->getAccountModel().getAccountInfo(accountId);
                         if (accInfo->contactModel->getContact(convInfo.participants[0]).profileInfo.type == lrc::api::profile::Type::PENDING)
                             [smartViewVC selectPendingList];
                         else
                             [smartViewVC selectConversationList];

                         [currentCallVC setCurrentCall:convInfo.callId
                                          conversation:convInfo.uid
                                               account:accInfo];
                         [smartViewVC selectConversation: convInfo model:accInfo->conversationModel.get()];
                         [currentCallVC showWithAnimation:false];
                         [conversationVC hideWithAnimation:false];
                     });

    QObject::connect(&lrc_->getBehaviorController(),
                     &lrc::api::BehaviorController::showIncomingCallView,
                     [self](const std::string accountId,
                            const lrc::api::conversation::Info convInfo){
                         auto* accInfo = &lrc_->getAccountModel().getAccountInfo(accountId);
                         if (accInfo->contactModel->getContact(convInfo.participants[0]).profileInfo.type == lrc::api::profile::Type::PENDING)
                             [smartViewVC selectPendingList];
                         else
                             [smartViewVC selectConversationList];

                         [currentCallVC setCurrentCall:convInfo.callId
                                          conversation:convInfo.uid
                                               account:accInfo];
                         [smartViewVC selectConversation: convInfo model:accInfo->conversationModel.get()];
                         [currentCallVC showWithAnimation:false];
                         [conversationVC hideWithAnimation:false];
                     });

    QObject::connect(&lrc_->getBehaviorController(),
                     &lrc::api::BehaviorController::showChatView,
                     [self](const std::string& accountId,
                            const lrc::api::conversation::Info& convInfo){
                         auto& accInfo = lrc_->getAccountModel().getAccountInfo(accountId);
                         [conversationVC setConversationUid:convInfo.uid model:accInfo.conversationModel.get()];
                         [smartViewVC selectConversation: convInfo model:accInfo.conversationModel.get()];
                         [conversationVC showWithAnimation:false];
                         [currentCallVC hideWithAnimation:false];
                     });
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
        if (!registeredName.empty()) {
            uriToDisplay = @(registeredName.c_str());
        } else {
            uriToDisplay = @(ringID.c_str());
        }
        [ringIDLabel setStringValue:uriToDisplay];
        [self drawQRCode:@(ringID.c_str())];
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
    [sender setPressed:![sender isPressed]];
    [self showQRCode:[sender isPressed]];
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
                CGContextSetFillColorWithColor(ctx, [NSColor ringDarkGrey].CGColor);
                rectDraw.origin = CGPointMake((j + qr_margin) * zoom,(i + qr_margin) * zoom);
                CGContextAddRect(ctx, rectDraw);
                CGContextFillPath(ctx);
            } else {
                CGContextSetFillColorWithColor(ctx, [NSColor windowBackgroundColor].CGColor);
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
    static const NSInteger offset = 110;
    [NSAnimationContext beginGrouping];
    NSAnimationContext.currentContext.duration = 0.5;
    [[NSAnimationContext currentContext] setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault]];
    qrcodeView.animator.alphaValue = show ? 1.0 : 0.0;
    [centerYQRCodeConstraint.animator setConstant: show ? offset : 0];
    [centerYWelcomeContainerConstraint.animator setConstant:show ? -offset : 0];
    [NSAnimationContext endGrouping];
}

- (IBAction)openPreferences:(id)sender
{
    if (preferencesWC) {
        [preferencesWC.window orderFront:preferencesWC.window];
        return;
    }
    preferencesWC = [[PreferencesWC alloc] initWithNibName:@"PreferencesWindow" bundle: nil model:&(lrc_->getDataTransferModel())];
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

#pragma mark - Ring account migration

- (void) migrateRingAccount:(Account*) acc
{
    self.migrateWC = [[MigrateRingAccountsWC alloc] initWithDelegate:self actionCode:1];
    self.migrateWC.account = acc;
#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_9
    [self.window beginSheet:self.migrateWC.window completionHandler:nil];
#else
    [NSApp beginSheet: self.migrateWC.window
       modalForWindow: self.window
        modalDelegate: self
       didEndSelector: nil
          contextInfo: nil];
#endif
}

// TODO: Reimplement as a blocking loop when new LRC models handle migration
- (void)checkAccountsToMigrate
{
    auto ringList = AccountModel::instance().accountsToMigrate();
    if (ringList.length() > 0){
        Account* acc = ringList.value(0);
        [self migrateRingAccount:acc];
    } else {
        // Fresh run, we need to make sure RingID appears
        [shareButton sendActionOn:NSLeftMouseDownMask];

        [self connect];
        [self updateRingID];
        // display accounts to select
        NSToolbar *toolbar = self.window.toolbar;
        toolbar.delegate = self;
        [toolbar insertItemWithItemIdentifier:kChangeAccountToolBarItemIdentifier atIndex:1];
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

-(void)selectAccount:(const lrc::api::account::Info&)accInfo
{
    // If the selected account has been changed, we close any open panel
    if ([smartViewVC setConversationModel:accInfo.conversationModel.get()]) {
        [currentCallVC hideWithAnimation:false];
        [conversationVC hideWithAnimation:false];
    }

    // Welcome view informations are also updated
    [self updateRingID];
}

-(void)allAccountsDeleted
{
    [smartViewVC clearConversationModel];
    [currentCallVC hideWithAnimation:false];
    [conversationVC hideWithAnimation:false];
    [self updateRingID];
}

-(void)rightPanelClosed
{
    [smartViewVC deselect];
}

-(void)currentConversationTrusted
{
    [smartViewVC selectConversationList];
}

-(void) listTypeChanged {
    [conversationVC hideWithAnimation:false];
    [currentCallVC hideWithAnimation:false];
}

#pragma mark - NSToolbarDelegate
- (nullable NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    if(itemIdentifier == kChangeAccountToolBarItemIdentifier) {
        NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:kChangeAccountToolBarItemIdentifier];
        toolbarItem.view = chooseAccountVC.view;
        return toolbarItem;
    }
    return nil;
}

@end
