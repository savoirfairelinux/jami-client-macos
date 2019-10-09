/*
 *  Copyright (C) 2015-2019 Savoir-faire Linux Inc.
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
#import "ConnectToAccManagerVC.h"

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
    IBOutlet ConnectToAccManagerVC* connectToAccManagerVC;
    BOOL isCancelable;
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
    connectToAccManagerVC = [[ConnectToAccManagerVC alloc] initWithNibName:@"ConnectToAccManagerVC" bundle:nil accountmodel:self.accountModel];
    [addSIPAccountVC setDelegate:self];
    [chooseActiontWC setDelegate:self];
    [linkAccountWC setDelegate:self];
    [newAccountWC setDelegate:self];
    [connectToAccManagerVC setDelegate:self];
    [self showChooseWithCancelButton:isCancelable];
}

- (void)removeSubviews
{
    while ([self.container.subviews count] > 0)
    {
        [[self.container.subviews firstObject] removeFromSuperview];
    }
}

- (void)showView:(NSView*)view
{
    [self removeSubviews];
    [self.container setFrameSize:view.frame.size];
    [self.container addSubview:view];
}

- (void)showChooseWithCancelButton:(BOOL)showCancel
{
    [self.windowHeader setStringValue: NSLocalizedString(@"Welcome to Jami",
                                                         @"Welcome title")];
    [ringImage setHidden: NO];
    [chooseActiontWC showInitialwithCancell:showCancel];
    isCancelable = showCancel;
    [self showView:chooseActiontWC.view];
}

- (void)showNewAccountVC
{
    [self.windowHeader setStringValue: NSLocalizedString(@"Create a new account",
                                                         @"Welcome title")];
    [ringImage setHidden: YES];
    titleConstraint.constant = 0;
    [newAccountWC prepareViewToShow];
    [self showView: newAccountWC.view];
    [newAccountWC show];
}

- (void)showImportWithType:(IMPORT_TYPE)type
{
    auto header = type == IMPORT_FROM_DEVICE ?
    NSLocalizedString(@"Import from other device",
                      @"link account title") :
    NSLocalizedString(@"Import from backup",
                      @"link account title");

    [self.windowHeader setStringValue: header];
    [ringImage setHidden: YES];
    titleConstraint.constant = 0;
    [self showView: linkAccountWC.view];
    [linkAccountWC showImportViewOfType: type];
}

- (void)showSIPAccountVC
{
    [self.windowHeader setStringValue: NSLocalizedString(@"Add a SIP account",
                                                         @"Welcome title")];
    [ringImage setHidden: YES];
    titleConstraint.constant = 0;
    [self showView: addSIPAccountVC.view];
    [addSIPAccountVC show];
}

- (void)showConnectToAccountManager
{
    [self.windowHeader setStringValue: NSLocalizedString(@"Sign In",
                                                         @"Sign In")];
    [ringImage setHidden: YES];
    titleConstraint.constant = 0;
    [self showView: connectToAccManagerVC.view];
    [connectToAccManagerVC show];
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
    switch (action) {
        case WIZARD_ACTION_IMPORT_FROM_DEVICE:
            [self showImportWithType: IMPORT_FROM_DEVICE];
            break;
        case WIZARD_ACTION_IMPORT_FROM_ADCHIVE:
            [self showImportWithType: IMPORT_FROM_BACKUP];
            break;
        case WIZARD_ACTION_NEW:
            [self showNewAccountVC];
            break;
        case WIZARD_ACTION_ADVANCED:
            [self showView:chooseActiontWC.view];
            break;
        case WIZARD_ACTION_SIP_ACCOUNT:
            [self showSIPAccountVC];
            break;
        case WIZARD_ACTION_ACCOUNT_MANAGER:
            [self showConnectToAccountManager];
            break;
        default:
            [self.window close];
            [NSApp endSheet:self.window];
            [[NSApplication sharedApplication] removeWindowsItem:self.window];
            break;
    }
}

#pragma - WizardCreateAccountDelegate methods

- (void)didCreateAccountWithSuccess:(BOOL)success
{
    [self completedWithSuccess:success];
}

#pragma - WizardLinkAccountDelegate methods

- (void)didLinkAccountWithSuccess:(BOOL)success
{
    [self completedWithSuccess:success];
}

#pragma - RingWizardAccManagerDelegate

- (void)didSignInSuccess:(BOOL)success {
    [self completedWithSuccess:success];
}

-(void) completedWithSuccess:(BOOL) success {
    if (success) {
        [self.window close];
        [NSApp endSheet:self.window];
        [[NSApplication sharedApplication] removeWindowsItem:self.window];
        if (!isCancelable){
            AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
            [appDelegate showMainWindow];
        }
    } else {
        [self showChooseWithCancelButton: isCancelable];
    }
}

@end
