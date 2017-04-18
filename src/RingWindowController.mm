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

//Qt
#import <QItemSelectionModel>
#import <QItemSelection>

//LRC
#import <accountmodel.h>
#import <callmodel.h>
#import <account.h>
#import <call.h>
#import <recentmodel.h>
#import <AvailableAccountModel.h>


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

@interface RingWindowController () <MigrateRingAccountsDelegate, NSToolbarDelegate>

@property (retain) MigrateRingAccountsWC* migrateWC;

@end

@implementation RingWindowController {

    __unsafe_unretained IBOutlet NSLayoutConstraint* centerYQRCodeConstraint;
    __unsafe_unretained IBOutlet NSLayoutConstraint* centerYWelcomeContainerConstraint;
    __unsafe_unretained IBOutlet NSView* welcomeContainer;
    __unsafe_unretained IBOutlet NSView* callView;
    __unsafe_unretained IBOutlet NSTextField* ringIDLabel;
    __unsafe_unretained IBOutlet NSButton* shareButton;
    __unsafe_unretained IBOutlet NSImageView* qrcodeView;

    PreferencesWC* preferencesWC;
    IBOutlet SmartViewVC* smartViewVC;

    CurrentCallVC* currentCallVC;
    ConversationVC* offlineVC;

    ChooseAccountVC* chooseAccountVC;
}

static NSString* const kPreferencesIdentifier = @"PreferencesIdentifier";
NSString* const kChangeAccountToolBarItemIdentifier = @"ChangeAccountToolBarItemIdentifier";

- (void)windowDidLoad {
    [super windowDidLoad];
    [self.window setMovableByWindowBackground:YES];

    [self.window setBackgroundColor:[NSColor colorWithRed:242.0/255 green:242.0/255 blue:242.0/255 alpha:1.0]];
    self.window.titleVisibility = NSWindowTitleHidden;

    currentCallVC = [[CurrentCallVC alloc] initWithNibName:@"CurrentCall" bundle:nil];
    offlineVC = [[ConversationVC alloc] initWithNibName:@"Conversation" bundle:nil];
    chooseAccountVC = [[ChooseAccountVC alloc] initWithNibName:@"ChooseAccount" bundle:nil];
    [callView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [[currentCallVC view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [[offlineVC view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

    [callView addSubview:[currentCallVC view] positioned:NSWindowAbove relativeTo:nil];
    [callView addSubview:[offlineVC view] positioned:NSWindowAbove relativeTo:nil];

    [currentCallVC initFrame];
    [offlineVC initFrame];

    [self checkAccountsToMigrate];
}

- (void) connect
{
    // Update Ring ID label based on account model changes
    QObject::connect(RecentModel::instance().selectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {
                         auto call = RecentModel::instance().getActiveCall(current);

                         if(!current.isValid()) {
                             [offlineVC animateOut];
                             [currentCallVC animateOut];
                             return;
                         }

                         if (!call) {
                             [currentCallVC animateOut];
                             [offlineVC animateIn];
                         } else {
                             [currentCallVC animateIn];
                             [offlineVC animateOut];
                         }
                     });

    QObject::connect(CallModel::instance().selectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {
                         if(!current.isValid()) {
                             return;
                         }

                         if (previous.isValid()) {
                             // We were already on a call
                             [currentCallVC animateOut];
                         } else {
                             // Make sure Conversation view hides when selecting a valid call
                             [currentCallVC animateIn];
                             [offlineVC animateOut];
                         }
                     });
    QObject::connect(AvailableAccountModel::instance().selectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [self](const QModelIndex& idx){
                         [self updateRingID];
                     });
}

/**
 * Implement the necessary logic to choose which Ring ID to display.
 * This tries to choose the "best" ID to show
 */
- (void) updateRingID
{
    Account* finalChoice = nullptr;

    [ringIDLabel setStringValue:@""];
    QModelIndex index = AvailableAccountModel::instance().selectionModel()->currentIndex();
    finalChoice = index.data(static_cast<int>(Account::Role::Object)).value<Account*>();
    if(finalChoice == nil || (finalChoice->protocol() != Account::Protocol::RING)) {
        self.hideRingID = YES;
        return;
    }
    self.hideRingID = NO;
    auto name = finalChoice->registeredName();
    NSString* uriToDisplay = nullptr;
    if (!name.isNull() && !name.isEmpty()) {
        uriToDisplay = name.toNSString();
    } else {
        uriToDisplay = finalChoice->username().toNSString();
    }
    [ringIDLabel setStringValue:uriToDisplay];
    [self drawQRCode:finalChoice->username().toNSString()];
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
    preferencesWC = [[PreferencesWC alloc] initWithWindowNibName:@"PreferencesWindow"];
    [preferencesWC.window makeKeyAndOrderFront:preferencesWC.window];
}

- (IBAction)showHistory:(NSButton*)sender
{
    [smartViewVC showHistory];
}

- (IBAction)showContacts:(NSButton*)sender
{
    [smartViewVC showContacts];
}

- (IBAction)showSmartlist:(NSButton*)sender
{
    [smartViewVC showSmartlist];
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

#pragma mark - NSToolbarDelegate
- (nullable NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag{
    if(!(itemIdentifier == kChangeAccountToolBarItemIdentifier)) {
        return nil;
    }
    NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:kChangeAccountToolBarItemIdentifier];
    CGRect frame = chooseAccountVC.view.frame;
    toolbarItem.view = chooseAccountVC.view;
    return toolbarItem;
}

@end
