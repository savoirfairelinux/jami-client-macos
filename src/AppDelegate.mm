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
#import "AppDelegate.h"

#import <callmodel.h>
#import <qapplication.h>
#import <accountmodel.h>
#import <protocolmodel.h>
#import <media/recordingmodel.h>
#import <media/textrecording.h>
#import <QItemSelectionModel>
#import <account.h>

#if ENABLE_SPARKLE
#import <Sparkle/Sparkle.h>
#endif

#import "Constants.h"
#import "RingWizardWC.h"

#if ENABLE_SPARKLE
@interface AppDelegate() <SUUpdaterDelegate>
#else
@interface AppDelegate()
#endif

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
    QObject::connect(&CallModel::instance(),
                     &CallModel::incomingCall,
                     [=](Call* call) {
                         BOOL shouldComeToForeground = [[NSUserDefaults standardUserDefaults] boolForKey:Preferences::WindowBehaviour];
                         BOOL shouldNotify = [[NSUserDefaults standardUserDefaults] boolForKey:Preferences::Notifications];
                         if (shouldComeToForeground) {
                             [NSApp activateIgnoringOtherApps:YES];
                             if ([self.ringWindowController.window isMiniaturized]) {
                                 [self.ringWindowController.window deminiaturize:self];
                             }
                         }

                         if(shouldNotify) {
                             [self showIncomingNotification:call];
                         }
                     });


    QObject::connect(&Media::RecordingModel::instance(),
                     &Media::RecordingModel::unreadMessagesCountChanged,
                     [=](int unreadCount) {
                         NSDockTile *tile = [[NSApplication sharedApplication] dockTile];
                         NSString* label = unreadCount ? [NSString stringWithFormat:@"%d", unreadCount]: @"";
                         [tile setBadgeLabel:label];
                     });

    QObject::connect(&Media::RecordingModel::instance(),
                     &Media::RecordingModel::newTextMessage,
                     [=](Media::TextRecording* t, ContactMethod* cm) {

                         BOOL shouldNotify = [[NSUserDefaults standardUserDefaults] boolForKey:Preferences::Notifications];
                         auto qIdx = t->instantTextMessagingModel()->index(t->instantTextMessagingModel()->rowCount()-1, 0);

                         // Don't show a notification if we are sending the text OR window already has focus OR user disabled notifications
                         if(qvariant_cast<Media::Media::Direction>(qIdx.data((int)Media::TextRecording::Role::Direction)) == Media::Media::Direction::OUT
                            || self.ringWindowController.window.keyWindow || !shouldNotify)
                             return;

                         NSUserNotification* notification = [[NSUserNotification alloc] init];

                         NSString* localizedTitle = NSLocalizedString(([NSString stringWithFormat:@"Message from %@",
                                                                        qIdx.data((int)Media::TextRecording::Role::AuthorDisplayname).toString().toNSString()]),
                                                                      @"Text message notification title");

                         [notification setTitle:localizedTitle];
                         [notification setSoundName:NSUserNotificationDefaultSoundName];
                         [notification setSubtitle:qIdx.data().toString().toNSString()];

                         [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
                     });
}

- (void) showIncomingNotification:(Call*) call{
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    NSString* localizedTitle = NSLocalizedString(([NSString stringWithFormat:@"Incoming call from %@",
                                                   call->peerName().toNSString()]),
                                                 @"Call notification title");
    [notification setTitle:localizedTitle];
    [notification setSoundName:NSUserNotificationDefaultSoundName];

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
    if(self.wizard == nil) {
        self.wizard = [[RingWizardWC alloc] initWithWindowNibName:@"RingWizard"];
    }
    [self.wizard.window orderFront:self];
}

- (void) showMainWindow
{
    if(self.ringWindowController == nil) {
        self.ringWindowController = [[RingWindowController alloc] initWithWindowNibName:@"RingWindow"];
    }

    self.wizard = nil;

    [self.ringWindowController.window makeKeyAndOrderFront:self];
}

- (BOOL) checkForRingAccount
{
    BOOL foundRingAcc = NO;
    for (int i = 0 ; i < AccountModel::instance().rowCount() ; ++i) {
        QModelIndex idx = AccountModel::instance().index(i);
        Account* acc = AccountModel::instance().getAccountByModelIndex(idx);
        if(acc->protocol() == Account::Protocol::RING) {
            if (acc->displayName().isEmpty())
                acc->setDisplayName(acc->alias());
            foundRingAcc = YES;
        }
    }
    return foundRingAcc;
}

-(void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    NSAppleEventManager *appleEventManager = [NSAppleEventManager sharedAppleEventManager];
    [appleEventManager setEventHandler:self
                           andSelector:@selector(handleGetURLEvent:withReplyEvent:)
                         forEventClass:kInternetEventClass andEventID:kAEGetURL];
}

/**
 * Recognized patterns:
 *   - ring:<hash>
 *   - ring://<hash>
 */
- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
    NSString* query = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    NSURL* url = [[NSURL alloc] initWithString:query];
    NSString* ringID = [url host];
    if (!ringID) {
        //not a valid NSURL, try to parse query directly
        ringID = [query substringFromIndex:@"ring:".length];
    }

    // check for a valid ring hash
    NSCharacterSet *hexSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
    BOOL valid = [[ringID stringByTrimmingCharactersInSet:hexSet] isEqualToString:@""];

    if(valid && ringID.length == 40) {
        Call* c = CallModel::instance().dialingCall();
        c->setDialNumber(QString::fromNSString([NSString stringWithFormat:@"ring:%@",ringID]));
        c << Call::Action::ACCEPT;
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Error"];
        [alert setInformativeText:@"ringID cannot be read from this URL."];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert runModal];
    }
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
    delete CallModel::instance().QObject::parent();
    [[NSApplication sharedApplication] terminate:self];
}

-(void)applicationWillTerminate:(NSNotification *)notification
{
    delete CallModel::instance().QObject::parent();
    [[NSApplication sharedApplication] terminate:self];
}

#if ENABLE_SPARKLE

#pragma mark -
#pragma mark Sparkle delegate

- (void)updater:(SUUpdater *)updater willInstallUpdate:(SUAppcastItem *)update
{
    [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)updaterMayCheckForUpdates:(SUUpdater *)bundle
{
    return YES;
}

- (BOOL)updaterShouldRelaunchApplication:(SUUpdater *)updater
{
    return YES;
}

- (void)updater:(SUUpdater *)updater didAbortWithError:(NSError *)error
{
    NSLog(@"Error:%@", error.localizedDescription);
}

#endif
@end
