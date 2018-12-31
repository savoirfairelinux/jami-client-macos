/*
 *  Copyright (C) 2015-2018 Savoir-faire Linux Inc.
 *  Author: Alexandre Lision <alexandre.lision@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

//Cocoa
#import <Quartz/Quartz.h>

#import "RingWizardWC.h"
#import "AppDelegate.h"
#import "Constants.h"
#import "views/NSImage+Extensions.h"
#import "views/NSColor+RingTheme.h"
#import "RingWizardNewAccountVC.h"
#import "RingWizardLinkAccountVC.h"
#import "RingWizardChooseVC.h"

@interface RingWizardWC ()

@property (retain, nonatomic)IBOutlet NSView* container;
@property (retain, nonatomic)IBOutlet NSTextField* windowHeader;
@property (retain, nonatomic)IBOutlet NSImageView* ringImage;
@property (retain, nonatomic)IBOutlet NSLayoutConstraint* titleConstraint;

@end
@implementation RingWizardWC {
    IBOutlet RingWizardNewAccountVC* newAccountWC;
    IBOutlet RingWizardLinkAccountVC* linkAccountWC;
    IBOutlet RingWizardChooseVC* chooseActiontWC;
    IBOutlet AddSIPAccountVC* addSIPAccountVC;
    BOOL isCancelable;
    BOOL withAdvanced;
}

@synthesize accountModel, ringImage, titleConstraint;

-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil accountmodel:(lrc::api::NewAccountModel*) accountModel;
{
    if (self =  [self initWithWindowNibName:nibNameOrNil])
    {
        self.accountModel = accountModel;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    newAccountWC = [[RingWizardNewAccountVC alloc] initWithNibName:@"RingWizardNewAccount" bundle:nil accountmodel:self.accountModel];

    chooseActiontWC = [[RingWizardChooseVC alloc] initWithNibName:@"RingWizardChoose" bundle:nil];
    linkAccountWC = [[RingWizardLinkAccountVC alloc] initWithNibName:@"RingWizardLinkAccount" bundle:nil accountmodel:self.accountModel];
    addSIPAccountVC = [[AddSIPAccountVC alloc] initWithNibName:@"AddSIPAccountVC" bundle:nil accountmodel:self.accountModel];
    [addSIPAccountVC setDelegate:self];
    [chooseActiontWC setDelegate:self];
    [linkAccountWC setDelegate:self];
    [newAccountWC setDelegate:self];
    [self showChooseWithCancelButton:isCancelable andAdvanced: withAdvanced];
}

- (void)removeSubviews
{
    while ([self.container.subviews count] > 0)
    {
        [[self.container.subviews firstObject] removeFromSuperview];
    }
}

#define headerHeight 70
#define minHeight 140
#define defaultMargin 5
- (void)showView:(NSView*)view
{
    [self removeSubviews];
    NSRect frame = [self.container frame];
    CGFloat height = minHeight;
    float sizeFrame = MAX(height, view.frame.size.height);
    frame.size.height = sizeFrame;
    [view setFrame: frame];
    [self.container setFrame:frame];
    float titleBarHeight = self.window.frame.size.height -
    [NSWindow contentRectForFrameRect: self.window.frame styleMask:self.window.styleMask].size.height;
    titleBarHeight = self.window.isSheet ? 0 : titleBarHeight;
    float size = headerHeight + sizeFrame + titleBarHeight;
    NSRect frameWindows = self.window.frame;
    frameWindows.size.height = size;
    [self.window setFrame:frameWindows display:YES animate:YES];
    [self.container addSubview:view];
}

- (void) updateFrame:(float) height {
    float titleBarHeight = self.window.frame.size.height -
    [NSWindow contentRectForFrameRect: self.window.frame styleMask:self.window.styleMask].size.height;
    titleBarHeight = self.window.isSheet ? 0 : titleBarHeight;
    float size = headerHeight + height + titleBarHeight;
    NSRect frameWindows = self.window.frame;
    frameWindows.size.height = size;
    [self.window setFrame:frameWindows display:YES animate:YES];
}

- (void)showChooseWithCancelButton:(BOOL)showCancel andAdvanced:(BOOL)showAdvanced {
    [self.windowHeader setStringValue: NSLocalizedString(@"Welcome to Jami",
                                                        @"Welcome title")];
    [ringImage setHidden: NO];
    titleConstraint.constant = -26.5;
    [self showView:chooseActiontWC.view];
    [chooseActiontWC showCancelButton:showCancel];
    [chooseActiontWC showAdvancedButton:showAdvanced];
    isCancelable = showCancel;
    withAdvanced = showAdvanced;
    [chooseActiontWC updateFrame];
    [self showView:chooseActiontWC.view];
}

- (void)showChooseWithCancelButton:(BOOL)showCancel
{
    [self.windowHeader setStringValue: NSLocalizedString(@"Welcome to Jami",
                                                         @"Welcome title")];
    [ringImage setHidden: NO];
    titleConstraint.constant = -26.5;
    [self showView:chooseActiontWC.view];
    [chooseActiontWC showCancelButton:showCancel];
    isCancelable = showCancel;
}

- (void)showNewAccountVC
{
    [self.windowHeader setStringValue: NSLocalizedString(@"Create a new account",
                                                         @"Welcome title")];
    [chooseActiontWC showCancelButton: isCancelable];
    [ringImage setHidden: YES];
    titleConstraint.constant = 0;
    [self showView: newAccountWC.view];
    [newAccountWC show];
}

- (void)showLinkAccountVC
{
    [self.windowHeader setStringValue: NSLocalizedString(@"Link to an account",
                                                         @"link account title")];
    [ringImage setHidden: YES];
    titleConstraint.constant = 0;
    [chooseActiontWC showCancelButton: isCancelable];
    [self showView: linkAccountWC.view];
    [linkAccountWC show];
}

- (void)showSIPAccountVC
{
    [self.windowHeader setStringValue: NSLocalizedString(@"Add a SIP account",
                                                         @"Welcome title")];
    [ringImage setHidden: YES];
    titleConstraint.constant = 0;
    [self showView: addSIPAccountVC.view];
    [chooseActiontWC showAdvancedButton: NO];
    [addSIPAccountVC show];
}

# pragma NSWindowDelegate methods

- (void)windowWillClose:(NSNotification *)notification
{
    if (!isCancelable){
        AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
        if ([appDelegate checkForRingAccount]) {
            [appDelegate showMainWindow];
        }
    }
}

#pragma - WizardChooseDelegate methods

- (void)didCompleteWithAction:(WizardAction)action
{
    if (action == WIZARD_ACTION_LINK) {
        [self showLinkAccountVC];
    } else if (action == WIZARD_ACTION_NEW) {
        [self showNewAccountVC];
    } else if (action == WIZARD_ACTION_ADVANCED) {
        [self showView:chooseActiontWC.view];
    } else if (action == WIZARD_ACTION_SIP_ACCOUNT) {
        [self showSIPAccountVC];
    } else {
        [self.window close];
        [NSApp endSheet:self.window];
        [[NSApplication sharedApplication] removeWindowsItem:self.window];
    }
}

#pragma - WizardCreateAccountDelegate methods

- (void)didCreateAccountWithSuccess:(BOOL)success
{
    if (success) {
        [self.window close];
        [NSApp endSheet:self.window];
        [[NSApplication sharedApplication] removeWindowsItem:self.window];
        if (!isCancelable){
            AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
            [appDelegate showMainWindow];
        }
    } else {
        [self showChooseWithCancelButton: isCancelable andAdvanced: withAdvanced];
    }
}

#pragma - WizardLinkAccountDelegate methods

- (void)didLinkAccountWithSuccess:(BOOL)success
{
    if (success) {
        [self.window close];
        [NSApp endSheet:self.window];
        [[NSApplication sharedApplication] removeWindowsItem:self.window];
        if (!isCancelable){
            AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
            [appDelegate showMainWindow];
        }
    } else {
        [self showChooseWithCancelButton: isCancelable andAdvanced: withAdvanced];
    }
}

@end