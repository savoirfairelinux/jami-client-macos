/*
 *  Copyright (C) 2015 Savoir-faire Linux Inc.
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

//LRC
#import <accountmodel.h>
#import <callmodel.h>
#import <account.h>
#import <call.h>

#import "AppDelegate.h"
#import "Constants.h"
#import "CurrentCallVC.h"


static NSString* const kPreferencesIdentifier = @"PreferencesIdentifier";

@interface RingWindowController ()

@property CurrentCallVC* currentVC;
@property (unsafe_unretained) IBOutlet NSView *callView;
@property (unsafe_unretained) IBOutlet NSTextField *ringIDLabel;


@end

@implementation RingWindowController
@synthesize currentVC;
@synthesize callView, ringIDLabel;

- (void)windowDidLoad {
    [super windowDidLoad];
    [self.window setMovableByWindowBackground:YES];
    [self displayMainToolBar];

    currentVC = [[CurrentCallVC alloc] initWithNibName:@"CurrentCall" bundle:nil];
    [callView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [[currentVC view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

    [callView addSubview:[self.currentVC view] positioned:NSWindowAbove relativeTo:nil];

    [currentVC initFrame];

    // Update Ring ID label based on account model changes
    QObject::connect(AccountModel::instance(),
                     &AccountModel::dataChanged,
                     [=] {
                         [self updateRingID];
                     });

}

-(void) displayMainToolBar
{
    NSToolbar* tb = [[NSToolbar alloc] initWithIdentifier: @"MainToolbar"];
    [tb setDisplayMode:NSToolbarDisplayModeIconAndLabel];
    [tb setDelegate: self];
    [self.window setToolbar: tb];
}

/**
 * Implement the necessary logic to choose which Ring ID to display.
 * This tries to choose the "best" ID to show
 */
- (void) updateRingID
{
    Account* registered = nullptr;
    Account* enabled = nullptr;
    Account* finalChoice = nullptr;

    [ringIDLabel setStringValue:@""];
    auto ringList = AccountModel::instance()->getAccountsByProtocol(Account::Protocol::RING);
    for (int i = 0 ; i < ringList.size() && !registered ; ++i) {
        Account* acc = ringList.value(i);
        if (acc->isEnabled()) {
            if(!enabled)
                enabled = finalChoice = acc;
            if (acc->registrationState() == Account::RegistrationState::READY) {
                registered = enabled = finalChoice = acc;
            }
        } else {
            if (!finalChoice)
                finalChoice = acc;
        }
    }

    [ringIDLabel setStringValue:[[NSString alloc] initWithFormat:@"%@", finalChoice->username().toNSString()]];
}

- (IBAction)openPreferences:(id)sender
{
    if(self.preferencesViewController != nil) {
        [self closePreferences:nil];
        return;
    }
    NSToolbar* tb = [[NSToolbar alloc] initWithIdentifier: @"PreferencesToolbar"];

    self.preferencesViewController = [[PreferencesVC alloc] initWithNibName:@"PreferencesScreen" bundle:nil];
    self.myCurrentViewController = self.preferencesViewController;

    NSLayoutConstraint* test = [NSLayoutConstraint constraintWithItem:self.preferencesViewController.view
                                                            attribute:NSLayoutAttributeWidth
                                                            relatedBy:NSLayoutRelationEqual
                                                               toItem:currentView
                                                            attribute:NSLayoutAttributeWidth
                                                           multiplier:1.0f
                                                             constant:0.0f];

    NSLayoutConstraint* test2 = [NSLayoutConstraint constraintWithItem:self.preferencesViewController.view
                                                             attribute:NSLayoutAttributeHeight
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:currentView
                                                             attribute:NSLayoutAttributeHeight
                                                            multiplier:1.0f
                                                              constant:0.0f];

    NSLayoutConstraint* test3 = [NSLayoutConstraint constraintWithItem:self.preferencesViewController.view
                                                             attribute:NSLayoutAttributeCenterX
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:currentView
                                                             attribute:NSLayoutAttributeCenterX
                                                            multiplier:1.0f
                                                              constant:0.0f];


    [currentView addSubview:[self.preferencesViewController view]];

    [tb setDelegate: self.preferencesViewController];
    [self.window setToolbar: tb];

    [self.window.toolbar setSelectedItemIdentifier:@"GeneralPrefsIdentifier"];

    [currentView addConstraint:test];
    [currentView addConstraint:test2];
    [currentView addConstraint:test3];
    // make sure we automatically resize the controller's view to the current window size
    [[self.myCurrentViewController view] setFrame:[currentView bounds]];

    // set the view controller's represented object to the number of subviews in that controller
    // (our NSTextField's value binding will reflect this value)
    [self.myCurrentViewController setRepresentedObject:[NSNumber numberWithUnsignedInteger:[[[self.myCurrentViewController view] subviews] count]]];
    
}

- (IBAction) closePreferences:(NSToolbarItem *)sender {
    if(self.myCurrentViewController != nil)
    {
        [self.preferencesViewController close];
        [self displayMainToolBar];
        self.preferencesViewController = nil;
    }
}

#pragma NSToolbar Delegate

-(NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem* item = nil;

    if ([itemIdentifier isEqualToString: kPreferencesIdentifier]) {
        item = [[NSToolbarItem alloc] initWithItemIdentifier: kPreferencesIdentifier];
        [item setImage: [NSImage imageNamed: @"NSAdvanced"]];
        [item setLabel: @"Settings"];
        [item setAction:@selector(openPreferences:)];
    }

    return item;
}


-(NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
    return [NSArray arrayWithObjects:
            NSToolbarSpaceItemIdentifier,
            NSToolbarFlexibleSpaceItemIdentifier,
            NSToolbarSpaceItemIdentifier,
            NSToolbarSpaceItemIdentifier,
            NSToolbarFlexibleSpaceItemIdentifier,
            kPreferencesIdentifier,
            nil];
}

-(NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:
                 kPreferencesIdentifier,
                 nil];
}

-(NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
    return nil;
}


// FIXME: This is sick, NSWindowController is catching my selectors
- (void)displayGeneral:(NSToolbarItem *)sender {
    [self.preferencesViewController displayGeneral:sender];
}

- (void)displayAudio:(NSToolbarItem *)sender {
    [self.preferencesViewController displayAudio:sender];
}

- (void)displayAncrage:(NSToolbarItem *)sender {
    [self.preferencesViewController displayAncrage:sender];
}

- (void)displayVideo:(NSToolbarItem *)sender {
    [self.preferencesViewController displayVideo:sender];
}

- (void)displayAccounts:(NSToolbarItem *)sender {
    [self.preferencesViewController displayAccounts:sender];
}

- (void)togglePowerSettings:(id)sender
{
    BOOL advanced = [[NSUserDefaults standardUserDefaults] boolForKey:Preferences::ShowAdvanced];
    [[NSUserDefaults standardUserDefaults] setBool:!advanced forKey:Preferences::ShowAdvanced];
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSToolbar* tb = [[NSToolbar alloc] initWithIdentifier: @"PreferencesToolbar"];
    [tb setDelegate: self.preferencesViewController];
    [self.preferencesViewController displayGeneral:nil];
    [self.window setToolbar:tb];
}



- (void)controlTextDidChange:(NSNotification *)obj
{

}


@end
