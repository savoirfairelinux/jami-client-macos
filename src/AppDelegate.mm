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
#import <SystemConfiguration/SystemConfiguration.h>

#import "AppDelegate.h"

#import <callmodel.h>
#import <qapplication.h>
#import <accountmodel.h>
#import <protocolmodel.h>
#import <media/recordingmodel.h>
#import <media/textrecording.h>
#import <QItemSelectionModel>
#import <QDebug>
#import <account.h>
//#import <AvailableAccountModel.h>
#import <api/lrc.h>
#import <api/newaccountmodel.h>
#import <api/newcallmodel.h>
#import <api/behaviorcontroller.h>
#import <api/conversation.h>
#import <api/contactmodel.h>


#if ENABLE_SPARKLE
#import <Sparkle/Sparkle.h>
#endif

#import "Constants.h"
#import "RingWizardWC.h"
#import "DialpadWC.h"

#if ENABLE_SPARKLE
@interface AppDelegate() <SUUpdaterDelegate>
#else
@interface AppDelegate()
#endif

@property RingWindowController* ringWindowController;
@property RingWizardWC* wizard;
@property DialpadWC* dialpad;
@property (nonatomic, strong) dispatch_queue_t scNetworkQueue;
@property (nonatomic, assign) SCNetworkReachabilityRef currentReachability;
@property (strong) id activity;

@end

@implementation AppDelegate {

std::unique_ptr<lrc::api::Lrc> lrc;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

    // hide "Check for update" menu item when sparkle is disabled
    NSMenu *mainMenu = [[NSApplication sharedApplication] mainMenu];
    NSMenu *ringMenu = [[mainMenu itemAtIndex:0] submenu];
    NSMenuItem *updateItem = [ringMenu itemAtIndex:1];
#if ENABLE_SPARKLE
    updateItem.hidden = false;
#else
    updateItem.hidden = true;
#endif

    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints"];

    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];

    NSAppleEventManager* appleEventManager = [NSAppleEventManager sharedAppleEventManager];
    [appleEventManager setEventHandler:self andSelector:@selector(handleQuitEvent:withReplyEvent:) forEventClass:kCoreEventClass andEventID:kAEQuitApplication];
    lrc = std::make_unique<lrc::api::Lrc>();

    if([self checkForRingAccount]) {
        [self showMainWindow];
    } else {
        [self showWizard];
    }
    [self connect];

    dispatch_queue_t queue = NULL;
    queue = dispatch_queue_create("scNetworkReachability", DISPATCH_QUEUE_SERIAL);
    [self setScNetworkQueue:queue];
    [self beginObservingReachabilityStatus];
    NSActivityOptions options = NSActivitySuddenTerminationDisabled | NSActivityAutomaticTerminationDisabled | NSActivityBackground;
    self.activity = [[NSProcessInfo processInfo] beginActivityWithOptions:options reason:@"Receiving calls and messages"];
}

- (void) beginObservingReachabilityStatus
{
    SCNetworkReachabilityRef reachabilityRef = NULL;

    void (^callbackBlock)(SCNetworkReachabilityFlags) = ^(SCNetworkReachabilityFlags flags) {
        BOOL reachable = (flags & kSCNetworkReachabilityFlagsReachable) != 0;
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            AccountModel::instance().slotConnectivityChanged();
        }];
    };

    SCNetworkReachabilityContext context = {
        .version = 0,
        .info = (void *)CFBridgingRetain(callbackBlock),
        .release = CFRelease
    };

    reachabilityRef = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, "test");
    if (SCNetworkReachabilitySetCallback(reachabilityRef, ReachabilityCallback, &context)){
        if (!SCNetworkReachabilitySetDispatchQueue(reachabilityRef, [self scNetworkQueue]) ){
            // Remove our callback if we can't use the queue
            SCNetworkReachabilitySetCallback(reachabilityRef, NULL, NULL);
        }
        [self setCurrentReachability:reachabilityRef];
    }
}

- (void) endObsvervingReachabilityStatusForHost:(NSString *)__unused host
{
    // Un-set the dispatch queue
    if (SCNetworkReachabilitySetDispatchQueue([self currentReachability], NULL) ){
        SCNetworkReachabilitySetCallback([self currentReachability], NULL, NULL);
    }
}

static void ReachabilityCallback(SCNetworkReachabilityRef __unused target, SCNetworkConnectionFlags flags, void* info)
{
    void (^callbackBlock)(SCNetworkReachabilityFlags) = (__bridge id)info;
    callbackBlock(flags);
}

- (void) connect
{

    QObject::connect(&AccountModel::instance(),
                     &AccountModel::registrationChanged,
                     [=](Account* a, bool registration) {
                         qDebug() << "registrationChanged:" << a->id() << ":" << registration;
                         //track buddy for account
                         AccountModel::instance().subscribeToBuddies(a->id());
                     });

    QObject::connect(&lrc->getBehaviorController(),
                     &lrc::api::BehaviorController::showIncomingCallView,
                     [self](const std::string accountId,
                            const lrc::api::conversation::Info convInfo){
                         auto* accInfo = &lrc->getAccountModel().getAccountInfo(accountId);
                         if(accInfo->callModel->getCall(convInfo.callId).isOutgoing) {
                             return;
                         }
                         BOOL shouldComeToForeground = [[NSUserDefaults standardUserDefaults] boolForKey:Preferences::WindowBehaviour];
                         BOOL shouldNotify = [[NSUserDefaults standardUserDefaults] boolForKey:Preferences::Notifications];
                         if (shouldComeToForeground) {
                             [NSApp activateIgnoringOtherApps:YES];
                             if ([self.ringWindowController.window isMiniaturized]) {
                                 [self.ringWindowController.window deminiaturize:self];
                             }
                         }

                         if(shouldNotify) {
                                [self showIncomingNotification:accInfo->callModel->getCall(convInfo.callId).peer];
                         }
                         
                     });

//    QObject::connect(&CallModel::instance(),
//                     &CallModel::incomingCall,
//                     [=](Call* call) {
//                         // on incoming call set selected account match call destination account
////                         if (call->account()) {
////                             QModelIndex index = call->account()->index();
////                             index = AvailableAccountModel::instance().mapFromSource(index);
////
////                             AvailableAccountModel::instance().selectionModel()->setCurrentIndex(index,
////                                                                                                 QItemSelectionModel::ClearAndSelect);
////                         }
//                         BOOL shouldComeToForeground = [[NSUserDefaults standardUserDefaults] boolForKey:Preferences::WindowBehaviour];
//                         BOOL shouldNotify = [[NSUserDefaults standardUserDefaults] boolForKey:Preferences::Notifications];
//                         if (shouldComeToForeground) {
//                             [NSApp activateIgnoringOtherApps:YES];
//                             if ([self.ringWindowController.window isMiniaturized]) {
//                                 [self.ringWindowController.window deminiaturize:self];
//                             }
//                         }
//
//                         if(shouldNotify) {
//                             [self showIncomingNotification:call];
//                         }
//                     });

//    QObject::connect(&media::RecordingModel::instance(),
//                     &media::RecordingModel::newTextMessage,
//                     [=](media::TextRecording* t, ContactMethod* cm) {
//
//                         BOOL shouldNotify = [[NSUserDefaults standardUserDefaults] boolForKey:Preferences::Notifications];
//                         auto qIdx = t->instantTextMessagingModel()->index(t->instantTextMessagingModel()->rowCount()-1, 0);
//
//                         // Don't show a notification if we are sending the text OR window already has focus OR user disabled notifications
//                         if(qvariant_cast<media::Media::Direction>(qIdx.data((int)media::TextRecording::Role::Direction)) == media::Media::Direction::OUT
//                            || self.ringWindowController.window.isMainWindow || !shouldNotify)
//                             return;
//
//                         NSUserNotification* notification = [[NSUserNotification alloc] init];
//
//                         NSString* localizedTitle = [NSString stringWithFormat:NSLocalizedString(@"Message from %@", @"Message from {Name}"), qIdx.data((int)media::TextRecording::Role::AuthorDisplayname).toString().toNSString()];
//
//                         [notification setTitle:localizedTitle];
//                         [notification setSoundName:NSUserNotificationDefaultSoundName];
//                         [notification setSubtitle:qIdx.data().toString().toNSString()];
//
//                         [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
//                     });
}

- (void) showIncomingNotification:(std::string) peerName{
    NSUserNotification* notification = [[NSUserNotification alloc] init];
    NSString* localizedTitle = [NSString stringWithFormat:
                                NSLocalizedString(@"Incoming call from %@", @"Incoming call from {Name}"), @(peerName.c_str())];
    [notification setTitle:localizedTitle];
    [notification setSoundName:NSUserNotificationDefaultSoundName];

    // try to activate action button
    @try {
        [notification setValue:@YES forKey:@"_showsButtons"];
    }
    @catch (NSException *exception) {
        // private API _showsButtons has changed...
        NSLog(@"Action button not activable on notification");
    }
    [notification setActionButtonTitle:NSLocalizedString(@"Refuse", @"Button Action")];

    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

- (void) userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification
{
//    if(notification.activationType == NSUserNotificationActivationTypeActionButtonClicked) {
//        CallModel::instance().selectedCall() << Call::Action::REFUSE;
//    } else {
//        [NSApp activateIgnoringOtherApps:YES];
//        if ([self.ringWindowController.window isMiniaturized]) {
//            [self.ringWindowController.window deminiaturize:self];
//        }
//    }
}

- (void) showWizard
{
    if(self.wizard == nil) {
        self.wizard = [[RingWizardWC alloc] initWithNibName:@"RingWizard" bundle: nil accountmodel: &lrc->getAccountModel()];
    }
    [self.wizard.window makeKeyAndOrderFront:self];
}

- (void) showMainWindow
{
    if(self.ringWindowController == nil) {
        self.ringWindowController = [[RingWindowController alloc] initWithWindowNibName:@"RingWindow" bundle: nil accountModel:&lrc->getAccountModel() dataTransferModel:&lrc->getDataTransferModel() behaviourController:&lrc->getBehaviorController()];
    }
    [[NSApplication sharedApplication] removeWindowsItem:self.wizard.window];
    [self.ringWindowController.window makeKeyAndOrderFront:self];
}

- (void) showDialpad
{
    if (self.dialpad == nil) {
        self.dialpad = [[DialpadWC alloc] initWithWindowNibName:@"Dialpad"];
    }
    [self.dialpad.window makeKeyAndOrderFront:self];
}


- (BOOL) checkForRingAccount
{
    BOOL foundRingAcc = NO;
    for (int i = 0 ; i < AccountModel::instance().rowCount() ; ++i) {
        QModelIndex idx = AccountModel::instance().index(i);
        Account* acc = AccountModel::instance().getAccountByModelIndex(idx);
        if(acc->protocol() == Account::Protocol::RING && !acc->isNew()) {
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
//    NSString* query = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
//    NSURL* url = [[NSURL alloc] initWithString:query];
//    NSString* ringID = [url host];
//    if (!ringID) {
//        //not a valid NSURL, try to parse query directly
//        ringID = [query substringFromIndex:@"ring:".length];
//    }
//
//    // check for a valid ring hash
//    NSCharacterSet *hexSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
//    BOOL valid = [[ringID stringByTrimmingCharactersInSet:hexSet] isEqualToString:@""];
//
//    if(valid && ringID.length == 40) {
//        Call* c = CallModel::instance().dialingCall();
//        c->setDialNumber(QString::fromNSString([NSString stringWithFormat:@"ring:%@",ringID]));
//        c << Call::Action::ACCEPT;
//    } else {
//        NSAlert *alert = [[NSAlert alloc] init];
//        [alert addButtonWithTitle:@"OK"];
//        [alert setMessageText:@"Error"];
//        [alert setInformativeText:@"ringID cannot be read from this URL."];
//        [alert setAlertStyle:NSWarningAlertStyle];
//        [alert runModal];
//    }
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
    [[NSApplication sharedApplication] terminate:self];
}

-(void)applicationWillTerminate:(NSNotification *)notification
{
    [self cleanExit];
}

- (void) cleanExit
{
    if (self.activity != nil) {
        [[NSProcessInfo processInfo] endActivity:self.activity];
        self.activity = nil;
    }
    [self.wizard close];
    [self.ringWindowController close];
   // delete CallModel::instance().QObject::parent();
    [[NSApplication sharedApplication] terminate:self];
}

#if ENABLE_SPARKLE

#pragma mark - Sparkle delegate

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
