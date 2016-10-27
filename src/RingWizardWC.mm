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
#import "RingWizardWC.h"

//Cocoa
#import <AddressBook/AddressBook.h>
#import <Quartz/Quartz.h>


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
    BOOL isCancelable;
}

- (instancetype)initWithWindowNibName:(NSString *)windowNibName{
    self = [super initWithWindowNibName:windowNibName];

    chooseActiontWC = [[RingWizardChooseVC alloc] initWithNibName:@"RingWizardChoose" bundle:nil];
    linkAccountWC = [[RingWizardLinkAccountVC alloc] initWithNibName:@"RingWizardLinkAccount" bundle:nil];
    newAccountWC = [[RingWizardNewAccountVC alloc] initWithNibName:@"RingWizardChoose" bundle:nil];
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [chooseActiontWC setDelegate:self];
    [linkAccountWC setDelegate:self];
    [newAccountWC setDelegate:self];
    [self.window setBackgroundColor:[NSColor ringGreyHighlight]];
    [self showChooseWithCancelButton:isCancelable];
}

- (void)removeSubviews
{
    while ([self.container.subviews count] > 0)
    {
        [[self.container.subviews firstObject] removeFromSuperview];
    }
}

#define headerHeight 60
#define minHeight 141
#define defaultMargin 20
- (void)showView:(NSView*)view
{
    [self removeSubviews];
    NSRect frame = [self.container frame];
    float sizeFrame = MAX(minHeight, view.bounds.size.height);
    frame.size.height = sizeFrame;
    [view setFrame:frame];

    [self.container setFrame:frame];
    float size = headerHeight + sizeFrame + defaultMargin;
    NSRect frameWindows = self.window.frame;
    frameWindows.size.height = size;
    [self.window setFrame:frameWindows display:YES animate:YES];

    [self.container addSubview:view];
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
    if (action == WIZARD_ACTION_LINK){
        [self showLinkAccountVC];
    } else if (action == WIZARD_ACTION_NEW){
        [self showNewAccountVC];
    } else {
        [self.window close];
    }

}

#pragma - WizardCreateAccountDelegate methods

- (void)didCreateAccountWithSuccess:(BOOL)success
{
    if (success) {
        [self.window close];
        if (!isCancelable){
            AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
            [appDelegate showMainWindow];
        }
    } else {
        [self showChooseWithCancelButton:isCancelable];
    }
}

#pragma - WizardLinkAccountDelegate methods

- (void)didLinkAccountWithSuccess:(BOOL)success
{
    if (success) {
        [self.window close];
        if (!isCancelable){
            AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
            [appDelegate showMainWindow];
        }
    } else {
        [self showChooseWithCancelButton:isCancelable];
    }
}

@end
