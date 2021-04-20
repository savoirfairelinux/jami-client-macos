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
#import <CoreFoundation/CoreFoundation.h>
#import <IOKit/pwr_mgt/IOPMLib.h>

#import "AppDelegate.h"

//lrc
#import <api/lrc.h>
#import <api/newaccountmodel.h>
#import <api/behaviorcontroller.h>
#import <api/conversation.h>
#import <api/newcallmodel.h>


#if ENABLE_SPARKLE
#import <Sparkle/Sparkle.h>
#endif

#import "Constants.h"
#import "RingWizardWC.h"
#import "DialpadWC.h"
#import "utils.h"

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

NSString * const MESSAGE_NOTIFICATION = @"message_notification_type";
NSString * const CALL_NOTIFICATION = @"call_notification_type";
NSString * const CONTACT_REQUEST_NOTIFICATION = @"contact_request_notification_type";

NSString * const ACCOUNT_ID = @"account_id_notification_info";
NSString * const CALL_ID = @"call_id_notification_info";
NSString * const CONVERSATION_ID = @"conversation_id_notification_info";
NSString * const CONTACT_URI = @"contact_uri_notification_info";
NSString * const NOTIFICATION_TYPE = @"contact_type_notification_info";

IOPMAssertionID assertionID = 0;
BOOL sleepDisabled = false;

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

#ifndef NDEBUG
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints"];
#else
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints"];
#endif

    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];

    NSAppleEventManager* appleEventManager = [NSAppleEventManager sharedAppleEventManager];
    [appleEventManager setEventHandler:self andSelector:@selector(handleQuitEvent:withReplyEvent:) forEventClass:kCoreEventClass andEventID:kAEQuitApplication];

    dispatch_queue_t queue = NULL;
    queue = dispatch_queue_create("scNetworkReachability", DISPATCH_QUEUE_SERIAL);
    [self setScNetworkQueue:queue];
    [self beginObservingReachabilityStatus];
    NSActivityOptions options = NSActivitySuddenTerminationDisabled | NSActivityAutomaticTerminationDisabled | NSActivityBackground;
    self.activity = [[NSProcessInfo processInfo] beginActivityWithOptions:options reason:@"Receiving calls and messages"];
    lrc = std::make_unique<lrc::api::Lrc>();
    if([self checkForRingAccount]) {
        [self setRingtonePath];
        [self showMainWindow];
    } else {
        [self showWizard];
    }
    [self connect];
}

- (void) beginObservingReachabilityStatus
{
    SCNetworkReachabilityRef reachabilityRef = NULL;

    void (^callbackBlock)(SCNetworkReachabilityFlags) = ^(SCNetworkReachabilityFlags flags) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            lrc->connectivityChanged();
        });
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

- (void) disableScreenSleep
{
    if (sleepDisabled) {
        return;
    }
    CFStringRef reasonForActivity= CFSTR("Prevent display sleep during calls");
    sleepDisabled = IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep, kIOPMAssertionLevelOn, reasonForActivity, &assertionID) == kIOReturnSuccess;
}

- (void) restoreScreenSleep {
    auto calls = [self getActiveCalls];

    if (!sleepDisabled || !calls.empty()) {
        return;
    }
    IOPMAssertionRelease(assertionID);
    sleepDisabled = false;
}

static void ReachabilityCallback(SCNetworkReachabilityRef __unused target, SCNetworkConnectionFlags flags, void* info)
{
    void (^callbackBlock)(SCNetworkReachabilityFlags) = (__bridge id)info;
    callbackBlock(flags);
}

- (void) connect
{
    QObject::connect(&lrc->getBehaviorController(),
                     &lrc::api::BehaviorController::newTrustRequest,
                     [self] (const QString& accountId, const QString& contactUri) {
        BOOL shouldNotify = [[NSUserDefaults standardUserDefaults] boolForKey:Preferences::ContactRequestNotifications];
        if(!shouldNotify) {
            return;
        }
        NSUserNotification* notification = [[NSUserNotification alloc] init];
        auto contactModel = lrc->getAccountModel()
        .getAccountInfo(accountId).contactModel.get();
        NSString* name = contactModel->getContact(contactUri)
        .registeredName.isEmpty() ?
        contactUri.toNSString():
        contactModel->getContact(contactUri).registeredName.toNSString();
        NSString* localizedMessage =
        NSLocalizedString(@"Send you a contact request",
                          @"Notification message");

        NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
        userInfo[ACCOUNT_ID] = accountId.toNSString();
        userInfo[CONTACT_URI] = contactUri.toNSString();
        userInfo[NOTIFICATION_TYPE] = CONTACT_REQUEST_NOTIFICATION;

        [notification setTitle: name];
        notification.informativeText = localizedMessage;
        [notification setSoundName:NSUserNotificationDefaultSoundName];
        [notification setUserInfo: userInfo];

        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];

    });

    QObject::connect(&lrc->getBehaviorController(),
                     &lrc::api::BehaviorController::showIncomingCallView,
                     [self] (const QString& accountId,
                             const QString& convUid) {
        BOOL shouldNotify = [[NSUserDefaults standardUserDefaults] boolForKey:Preferences::CallNotifications];
        if(!shouldNotify) {
            return;
        }
        auto convModel = lrc->getAccountModel().getAccountInfo(accountId).conversationModel.get();
        auto conversationOpt = getConversationFromUid(convUid, *convModel);
        if (!conversationOpt.has_value()) { return; }
        lrc::api::conversation::Info& conversation = *conversationOpt;
        bool isIncoming = false;
        auto callModel = lrc->getAccountModel().getAccountInfo(accountId).callModel.get();
        if(callModel->hasCall(conversation.callId)) {
            isIncoming = !callModel->getCall(conversation.callId).isOutgoing;
        }
        if(!isIncoming) {
            return;
        }
        NSString* name = bestIDForConversation(conversation, *lrc->getAccountModel().getAccountInfo(accountId).conversationModel.get());
        NSUserNotification* notification = [[NSUserNotification alloc] init];

        NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
        userInfo[ACCOUNT_ID] = accountId.toNSString();
        userInfo[CALL_ID] = conversation.callId.toNSString();
        userInfo[CONVERSATION_ID] = conversation.uid.toNSString();
        userInfo[NOTIFICATION_TYPE] = CALL_NOTIFICATION;

        NSString* localizedTitle = [NSString stringWithFormat:
                                    NSLocalizedString(@"Incoming call from %@", @"Incoming call from {Name}"),
                                    name];
        // try to activate action button
        @try {
            [notification setValue:@YES forKey:@"_showsButtons"];
        }
        @catch (NSException *exception) {
            NSLog(@"Action button not activable on notification");
        }
        [notification setUserInfo: userInfo];
        [notification setOtherButtonTitle:NSLocalizedString(@"Refuse", @"Button Action")];
        [notification setActionButtonTitle:NSLocalizedString(@"Accept", @"Button Action")];
        [notification setTitle:localizedTitle];
        [notification setSoundName:NSUserNotificationDefaultSoundName];

        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    });

    QObject::connect(&lrc->getBehaviorController(),
                     &lrc::api::BehaviorController::newUnreadInteraction,
                     [self] (const QString& accountId, const QString& conversation,
                             uint64_t interactionId, const lrc::api::interaction::Info& interaction) {
        BOOL shouldNotify = [[NSUserDefaults standardUserDefaults] boolForKey:Preferences::MessagesNotifications];
        if(!shouldNotify) {
            return;
        }
        NSUserNotification* notification = [[NSUserNotification alloc] init];

        NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
        userInfo[ACCOUNT_ID] = accountId.toNSString();
        userInfo[CONVERSATION_ID] = conversation.toNSString();
        userInfo[NOTIFICATION_TYPE] = MESSAGE_NOTIFICATION;
        NSString* name = interaction.authorUri.toNSString();
        auto convOpt = getConversationFromUid(conversation, *lrc->getAccountModel()
                                             .getAccountInfo(accountId)
                                             .conversationModel.get());
        if (convOpt.has_value()) {
            lrc::api::conversation::Info& conversation = *convOpt;
            name = bestIDForConversation(conversation, *lrc->getAccountModel().getAccountInfo(accountId).conversationModel.get());
        }
        NSString* localizedTitle = [NSString stringWithFormat:
                                    NSLocalizedString(@"Incoming message from %@",@"Incoming message from {Name}"),
                                    name];

        [notification setTitle:localizedTitle];
        [notification setSoundName:NSUserNotificationDefaultSoundName];
        [notification setSubtitle:interaction.body.toNSString()];
        [notification setUserInfo:userInfo];

        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    });
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didDismissAlert:(NSUserNotification *)alert {
    // check if user click refuse on incoming call notifications
    if(alert.activationType != NSUserNotificationActivationTypeNone) {
        return;
    }

    auto info = alert.userInfo;
    if(!info) {
        return;
    }
    NSString* identifier = info[NOTIFICATION_TYPE];
    NSString* callId = info[CALL_ID];
    NSString* accountId = info[ACCOUNT_ID];
    if(!identifier || !callId || !accountId) {
        return;
    }
    if([identifier isEqualToString: CALL_NOTIFICATION]) {
        auto accountInfo = &lrc->getAccountModel().getAccountInfo([accountId UTF8String]);
        if (accountInfo == nil)
            return;
        auto* callModel = accountInfo->callModel.get();
        callModel->hangUp([callId UTF8String]);
    }
}

- (void) userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification
{
    auto info = notification.userInfo;
    if(!info) {
        return;
    }
    NSString* identifier = info[NOTIFICATION_TYPE];
    if([identifier isEqualToString: CALL_NOTIFICATION]) {
        if(notification.activationType == NSUserNotificationActivationTypeActionButtonClicked
           || notification.activationType == NSUserNotificationActivationTypeContentsClicked) {
            NSString* callId = info[CALL_ID];
            NSString* accountId = info[ACCOUNT_ID];
            NSString *conversationId = info[CONVERSATION_ID];
            auto accountInfo = &lrc->getAccountModel().getAccountInfo([accountId UTF8String]);
            if (accountInfo == nil)
                return;
            auto* callModel = accountInfo->callModel.get();
            callModel->accept([callId UTF8String]);
            [self.ringWindowController.window deminiaturize:self];
            [_ringWindowController showCall:callId forAccount:accountId forConversation:conversationId];
        }
    } else if(notification.activationType == NSUserNotificationActivationTypeContentsClicked) {
        [self.ringWindowController.window deminiaturize:self];
        if([identifier isEqualToString: MESSAGE_NOTIFICATION]) {
            NSString* accountId = info[ACCOUNT_ID];
            NSString *conversationId = info[CONVERSATION_ID];
            [_ringWindowController showConversation:conversationId forAccount:accountId];
        } else if([identifier isEqualToString: CONTACT_REQUEST_NOTIFICATION]) {
            NSString* accountId = info[ACCOUNT_ID];
            NSString *contactUri = info[CONTACT_URI];
            [_ringWindowController showContactRequestFor:accountId contactUri: contactUri];
        }
    }
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];
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
        self.ringWindowController = [[RingWindowController alloc] initWithWindowNibName:@"RingWindow" bundle: nil accountModel:&lrc->getAccountModel() dataTransferModel:&lrc->getDataTransferModel() behaviourController:&lrc->getBehaviorController() avModel: &lrc->getAVModel() pluginModel: &lrc->getPluginModel()];
    }
    [[NSApplication sharedApplication] removeWindowsItem:self.wizard.window];
    self.wizard = nil;
    [self.ringWindowController.window makeKeyAndOrderFront:self];
}

- (void) showDialpad
{
    if (self.dialpad == nil) {
        self.dialpad = [[DialpadWC alloc] initWithWindowNibName:@"Dialpad"];
    }
    [self.dialpad.window makeKeyAndOrderFront:self];
}

-(QVector<QString>) getActiveCalls {
    return lrc->activeCalls();
}

-(QVector<QString>)getConferenceSubcalls:(QString)confId {
    return lrc->getConferenceSubcalls(confId);
}

-(void)setRingtonePath {
    QStringList accounts = lrc->getAccountModel().getAccountList();
    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (auto account: accounts) {
        lrc::api::account::ConfProperties_t accountProperties = lrc->getAccountModel().getAccountConfig(account);
        NSString *ringtonePath = accountProperties.Ringtone.ringtonePath.toNSString();
        if (![fileManager fileExistsAtPath: ringtonePath]) {
            accountProperties.Ringtone.ringtonePath = [defaultRingtonePath() UTF8String];
            lrc->getAccountModel().setAccountConfig(account, accountProperties);
        }
    }
}

- (BOOL) checkForRingAccount
{
    return !lrc->getAccountModel().getAccountList().empty();
}

-(void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    NSAppleEventManager *appleEventManager = [NSAppleEventManager sharedAppleEventManager];
    [appleEventManager setEventHandler:self
                           andSelector:@selector(handleGetURLEvent:withReplyEvent:)
                         forEventClass:kInternetEventClass andEventID:kAEGetURL];
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
    lrc.reset();
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
