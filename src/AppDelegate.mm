/*
 *  Copyright (C) 2004-2015 Savoir-Faire Linux Inc.
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
 *
 *  Additional permission under GNU GPL version 3 section 7:
 *
 *  If you modify this program, or any covered work, by linking or
 *  combining it with the OpenSSL project's OpenSSL library (or a
 *  modified version of that library), containing parts covered by the
 *  terms of the OpenSSL or SSLeay licenses, Savoir-Faire Linux Inc.
 *  grants you additional permission to convey the resulting work.
 *  Corresponding Source for a non-source form of such a combination
 *  shall include the source code for the parts of OpenSSL used as well
 *  as that of the covered work.
 */
#import "AppDelegate.h"

#import <callmodel.h>
#import <qapplication.h>
#import <accountmodel.h>
#import <protocolmodel.h>
#import <QItemSelectionModel>
#import <account.h>

#import "Constants.h"
#import "RingWizardWC.h"

@interface AppDelegate()

@property RingWindowController* ringWindowController;
@property RingWizardWC* wizard;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints"];


    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];

    NSAppleEventManager* appleEventManager = [NSAppleEventManager sharedAppleEventManager];
    [appleEventManager setEventHandler:self andSelector:@selector(handleQuitEvent:withReplyEvent:) forEventClass:kCoreEventClass andEventID:kAEQuitApplication];

    if([self checkForRingAccount]) {
        [self showMainWindow];
    } else {
        [self showWizard];
    }
    [self connect];
}

- (void) connect
{
    QObject::connect(CallModel::instance(),
                     &CallModel::incomingCall,
                     [=](Call* call) {
                         BOOL shouldComeToForeground = [[NSUserDefaults standardUserDefaults] boolForKey:Preferences::WindowBehaviour];
                         BOOL shouldNotify = [[NSUserDefaults standardUserDefaults] boolForKey:Preferences::Notifications];
                         if(shouldComeToForeground)
                             [NSApp activateIgnoringOtherApps:YES];

                         if(shouldNotify) {
                             [self showIncomingNotification:call];
                         }
                     });
}

- (void) showIncomingNotification:(Call*) call{
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = @"Incoming call", call->peerName();
    //notification.informativeText = @"A notification";
    notification.soundName = NSUserNotificationDefaultSoundName;

    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

/**
 * click in MainMenu "Setup Ring"
 */
- (IBAction)showWizard:(id)sender {
    [self showWizard];
}

- (void) showWizard
{
    NSLog(@"Showing wizard");
    if(self.wizard == nil) {
        self.wizard = [[RingWizardWC alloc] initWithWindowNibName:@"RingWizard"];
    }
    [self.wizard.window orderFront:self];
}

- (void) showMainWindow
{
    if(self.ringWindowController == nil)
        self.ringWindowController = [[RingWindowController alloc] initWithWindowNibName:@"RingWindow"];

    [self.ringWindowController.window makeKeyAndOrderFront:self];
}

- (BOOL) checkForRingAccount
{
    for (int i = 0 ; i < AccountModel::instance()->rowCount() ; ++i) {
        QModelIndex idx = AccountModel::instance()->index(i);
        Account* acc = AccountModel::instance()->getAccountByModelIndex(idx);
        if(acc->protocol() == Account::Protocol::RING) {
            return YES;
        }
    }
    return FALSE;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
    if([self checkForRingAccount]) {
        [self showMainWindow];
    } else {
        [self showWizard];
    }
    return YES;
}

- (void)handleQuitEvent:(NSAppleEventDescriptor*)event withReplyEvent:(NSAppleEventDescriptor*)replyEvent
{
    delete CallModel::instance()->QObject::parent();
    [[NSApplication sharedApplication] terminate:self];
}

-(void)applicationWillTerminate:(NSNotification *)notification
{
    delete CallModel::instance()->QObject::parent();
    [[NSApplication sharedApplication] terminate:self];
}

@end
