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

#import "PreferencesWC.h"
#import "views/NSColor+RingTheme.h"

@interface RingWindowController ()

@property CurrentCallVC* currentVC;
@property (unsafe_unretained) IBOutlet NSView *callView;
@property (unsafe_unretained) IBOutlet NSTextField *ringIDLabel;
@property (nonatomic, strong) PreferencesWC *preferencesWC;

@end

@implementation RingWindowController
@synthesize currentVC;
@synthesize callView, ringIDLabel;

static NSString* const kPreferencesIdentifier = @"PreferencesIdentifier";

- (void)windowDidLoad {
    [super windowDidLoad];
    [self.window setMovableByWindowBackground:YES];

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
    self.preferencesWC = [[PreferencesWC alloc] initWithWindowNibName:@"PreferencesWindow"];
    [self.preferencesWC.window makeKeyAndOrderFront:self.preferencesWC.window];
}

@end
