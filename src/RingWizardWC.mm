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
    float initialHeight;
    float currentHeight;
}


- (void)windowDidLoad
{
    [super windowDidLoad];

    [self.window setBackgroundColor:[NSColor ringGreyHighlight]];
    chooseActiontWC = [[RingWizardChooseVC alloc] initWithNibName:@"RingWizardChoose" bundle:nil];
    [chooseActiontWC setDelegate:self];
    linkAccountWC = [[RingWizardLinkAccountVC alloc] initWithNibName:@"RingWizardLinkAccount" bundle:nil];
    [linkAccountWC setDelegate:self];
    newAccountWC = [[RingWizardNewAccountVC alloc] initWithNibName:@"RingWizardNewAccount" bundle:nil];
    [newAccountWC setDelegate:self];
    initialHeight = self.window.frame.size.height;
    currentHeight = self.window.frame.size.height;
    [self showView:chooseActiontWC.view];
}

- (void)removeSubviews
{
    while ([self.container.subviews count]>0)
    {
        [[self.container.subviews firstObject] removeFromSuperview];
    }
}

#define minHeight 135
- (void)showView: (NSView*) view
{
    [self removeSubviews];
    NSRect frame = [self.container frame];
    frame.size.height = MAX(minHeight, view.bounds.size.height);
    [view setFrame:frame];
    [self.container setFrame:frame];
    float size = 0;
    for (NSView *child in self.window.contentView.subviews){
        size += child.frame.size.height;
    }
    if (currentHeight != size){
        currentHeight = size;
        NSRect frameWindows = self.window.frame;
        frameWindows.size.height = currentHeight;
        [self.window setFrame:frameWindows display:YES animate:YES];
    }
    [self.container addSubview:view];
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

- (void)showChooseVC
{
    [self showView: chooseActiontWC.view];
}

# pragma NSWindowDelegate methods

- (void)windowWillClose:(NSNotification *)notification
{
    AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
    if ([appDelegate checkForRingAccount]) {
        [appDelegate showMainWindow];
    }
}

#pragma - WizardChooseDelegate methods
- (void)didCompleteWithAction:(WizardAction)action
{
    if (action == WIZARD_ACTION_LINK){
        [self showLinkAccountVC];
    } else {
        [self showNewAccountVC];
    }

}

#pragma - WizardCreateAccountDelegate methods
- (void)didCreateAccountWithSuccess:(BOOL)success
{
    if (success) {
        [self.window close];
        AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
        [appDelegate showMainWindow];
    } else {
        [self showChooseVC];
    }
}

#pragma - WizardLinkccountDelegate methods
- (void)didLinkAccountWithSuccess:(BOOL)success
{
    if (success) {
        [self.window close];
        AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
        [appDelegate showMainWindow];
    } else {
        [self showChooseVC];
    }
}

@end
