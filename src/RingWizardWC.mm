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

@end
@implementation RingWizardWC {
    IBOutlet RingWizardNewAccountVC* newAccountWC;
    IBOutlet RingWizardLinkAccountVC* linkAccountWC;
    IBOutlet RingWizardChooseVC* chooseActiontWC;
    IBOutlet AddSIPAccountVC* addSIPAccountVC;
    BOOL isCancelable;
    BOOL withAdvanced;
}

@synthesize accountModel;

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
   // [self.window setBackgroundColor:[NSColor ringGreyHighlight]];
    [self showChooseWithCancelButton:isCancelable andAdvanced: withAdvanced];
}

- (void)removeSubviews
{
    while ([self.container.subviews count] > 0)
    {
        [[self.container.subviews firstObject] removeFromSuperview];
    }
}

#define headerHeight 60
#define minHeight 150
#define defaultMargin 5
#define heightWithSIP 160
- (void)showView:(NSView*)view
{
    [self removeSubviews];
    NSRect frame = [self.container frame];
    CGFloat height = withAdvanced ? minHeight : minHeight - 10;
    float sizeFrame = MAX(height, view.frame.size.height);
    frame.size.height = sizeFrame;
    [view setFrame:frame];

    [self.container setFrame:frame];
    float size = headerHeight + sizeFrame + defaultMargin;
    NSRect frameWindows = self.window.frame;
    frameWindows.size.height = size;
    [self.window setFrame:frameWindows display:YES animate:YES];

    [self.container addSubview:view];
}

- (void) updateWindowHeight: (CGFloat) height {
    NSRect frame = [self.container frame];
    float sizeFrame = height;
    frame.size.height = sizeFrame;
    [self.container setFrame:frame];
    float size = headerHeight + sizeFrame + defaultMargin;
    NSRect frameWindows = self.window.frame;
    frameWindows.size.height = size;
    [self.window setFrame:frameWindows display:YES animate:YES];
}

- (void)showChooseWithCancelButton:(BOOL)showCancel andAdvanced:(BOOL)showAdvanced {
    [chooseActiontWC showCancelButton:showCancel];
    [chooseActiontWC showAdvancedButton:showAdvanced];
    isCancelable = showCancel;
    withAdvanced = showAdvanced;
    NSRect frame = CGRectMake(0, 0, chooseActiontWC.view.frame.size.width, 0);
    chooseActiontWC.view.frame = frame;
    [self showView:chooseActiontWC.view];

}

- (void)showChooseWithCancelButton:(BOOL)showCancel
{
    [chooseActiontWC showCancelButton:showCancel];
    isCancelable = showCancel;
    [self showView:chooseActiontWC.view];
}

- (void)showNewAccountVC
{
    [self showView: newAccountWC.view];
    [newAccountWC show];
}

- (void)showLinkAccountVC
{
    [self showView: linkAccountWC.view];
    [linkAccountWC show];
}

- (void)showSIPAccountVC
{
    [self showView: addSIPAccountVC.view];
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
        [self updateWindowHeight: heightWithSIP];
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

#pragma - AddSIPAccountDelegate methods

- (void)close {
    [self.window close];
    [NSApp endSheet:self.window];
    [[NSApplication sharedApplication] removeWindowsItem:self.window];
}

@end
