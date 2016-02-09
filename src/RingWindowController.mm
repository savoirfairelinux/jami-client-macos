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


//Qt
#import <QItemSelectionModel>
#import <QItemSelection>

//LRC
#import <accountmodel.h>
#import <callmodel.h>
#import <account.h>
#import <call.h>
#import <recentmodel.h>

#import "AppDelegate.h"
#import "Constants.h"
#import "CurrentCallVC.h"
#import "ConversationVC.h"

#import "PreferencesWC.h"
#import "views/NSColor+RingTheme.h"

@implementation RingWindowController {

    __unsafe_unretained IBOutlet NSView* callView;
    __unsafe_unretained IBOutlet NSTextField* ringIDLabel;
    __unsafe_unretained IBOutlet NSButton* shareButton;

    PreferencesWC *preferencesWC;
    CurrentCallVC* currentCallVC;
    ConversationVC* offlineVC;
}

static NSString* const kPreferencesIdentifier = @"PreferencesIdentifier";

- (void)windowDidLoad {
    [super windowDidLoad];
    [self.window setMovableByWindowBackground:YES];

    currentCallVC = [[CurrentCallVC alloc] initWithNibName:@"CurrentCall" bundle:nil];
    offlineVC = [[ConversationVC alloc] initWithNibName:@"Conversation" bundle:nil];

    [callView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [[currentCallVC view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [[offlineVC view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

    [callView addSubview:[currentCallVC view] positioned:NSWindowAbove relativeTo:nil];
    [callView addSubview:[offlineVC view] positioned:NSWindowAbove relativeTo:nil];

    [currentCallVC initFrame];
    [offlineVC initFrame];

    // Fresh run, we need to make sure RingID appears
    [self updateRingID];
    [shareButton sendActionOn:NSLeftMouseDownMask];

    [self connect];
}

- (void) connect
{
    // Update Ring ID label based on account model changes
    QObject::connect(&AccountModel::instance(),
                     &AccountModel::dataChanged,
                     [=] {
                         [self updateRingID];
                     });

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
    auto ringList = AccountModel::instance().getAccountsByProtocol(Account::Protocol::RING);
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

- (IBAction)shareRingID:(id)sender {
    NSSharingServicePicker* sharingServicePicker = [[NSSharingServicePicker alloc] initWithItems:[NSArray arrayWithObject:[ringIDLabel stringValue]]];
    [sharingServicePicker showRelativeToRect:[sender bounds]
                                      ofView:sender
                               preferredEdge:NSMinYEdge];
}

- (IBAction)openPreferences:(id)sender
{
    preferencesWC = [[PreferencesWC alloc] initWithWindowNibName:@"PreferencesWindow"];
    [preferencesWC.window makeKeyAndOrderFront:preferencesWC.window];
}

@end
