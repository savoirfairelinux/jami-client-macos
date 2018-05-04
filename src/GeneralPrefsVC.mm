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
#import "GeneralPrefsVC.h"

#import <Quartz/Quartz.h>

//Qt
#import <QSize>
#import <QtMacExtras/qmacfunctions.h>
#import <QPixmap>

//LRC
#import <categorizedhistorymodel.h>
#import <profilemodel.h>
#import <profile.h>
#import <person.h>
#import <globalinstances.h>
#import <media/recordingmodel.h>

#if ENABLE_SPARKLE
#import <Sparkle/Sparkle.h>
#endif

#import "Constants.h"
#import "views/NSImage+Extensions.h"
#import "delegates/ImageManipulationDelegate.h"

@interface GeneralPrefsVC () {
    __unsafe_unretained IBOutlet NSTextField* historyChangedLabel;
    __unsafe_unretained IBOutlet NSButton* startUpButton;
    __unsafe_unretained IBOutlet NSButton* toggleAutomaticUpdateCheck;
    __unsafe_unretained IBOutlet NSPopUpButton* checkIntervalPopUp;
    __unsafe_unretained IBOutlet NSView* sparkleContainer;
    __unsafe_unretained IBOutlet NSTextField* historyTextField;
    __unsafe_unretained IBOutlet NSStepper* historyStepper;
    __unsafe_unretained IBOutlet NSButton* historySwitch;
    __unsafe_unretained IBOutlet NSButton* photoView;
    __unsafe_unretained IBOutlet NSTextField* profileNameField;
}
@end

@implementation GeneralPrefsVC

- (void)loadView
{
    [super loadView];
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:Preferences::HistoryLimit options:NSKeyValueObservingOptionNew context:NULL];

    [startUpButton setState:[self isLaunchAtStartup]];

    int historyLimit = CategorizedHistoryModel::instance().historyLimit();
    [historyTextField setStringValue:[NSString stringWithFormat:@"%d", historyLimit]];
    [historyStepper setIntValue:historyLimit];

    BOOL limited = CategorizedHistoryModel::instance().isHistoryLimited();
    [historySwitch setState:limited];
    [historyStepper setEnabled:limited];
    [historyTextField setEnabled:limited];
#if ENABLE_SPARKLE
    [sparkleContainer setHidden:NO];
    SUUpdater *updater = [SUUpdater sharedUpdater];
    [toggleAutomaticUpdateCheck bind:@"value" toObject:updater withKeyPath:@"automaticallyChecksForUpdates" options:nil];

    [checkIntervalPopUp bind:@"enabled" toObject:updater withKeyPath:@"automaticallyChecksForUpdates" options:nil];
    [checkIntervalPopUp bind:@"selectedTag" toObject:updater withKeyPath:@"updateCheckInterval" options:nil];
#else
    [sparkleContainer setHidden:YES];
#endif

    [photoView setWantsLayer: YES];
    photoView.layer.cornerRadius = photoView.frame.size.width / 2;
    photoView.layer.masksToBounds = YES;

    if (auto pro = ProfileModel::instance().selectedProfile()) {
        if (pro->person() && pro->person()->photo().isValid()) {
            auto photo = GlobalInstances::pixmapManipulator().contactPhoto(pro->person(), {140,140});
            [photoView setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(photo))];
        }
        [profileNameField setStringValue:pro->person()->formattedName().toNSString()];
    }
}

- (void) dealloc
{
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:Preferences::HistoryLimit];
}

- (IBAction)clearHistory:(id)sender {
    CategorizedHistoryModel::instance().clearAllCollections();
    Media::RecordingModel::instance().clearAllCollections();
    [historyChangedLabel setHidden:NO];
}

- (IBAction)toggleHistory:(NSButton*)sender {
    CategorizedHistoryModel::instance().setHistoryLimited([sender state]);
    int historyLimit = CategorizedHistoryModel::instance().historyLimit();
    [historyTextField setStringValue:[NSString stringWithFormat:@"%d", historyLimit]];
    [historyStepper setIntValue:historyLimit];
    [historyChangedLabel setHidden:NO];
    [historyStepper setEnabled:[sender state]];
    [historyTextField setEnabled:[sender state]];
}

// KVO handler
-(void)observeValueForKeyPath:(NSString *)aKeyPath ofObject:(id)anObject
                       change:(NSDictionary *)aChange context:(void *)aContext
{
    if ([aKeyPath isEqualToString:Preferences::HistoryLimit]) {
        CategorizedHistoryModel::instance().setHistoryLimit([[aChange objectForKey: NSKeyValueChangeNewKey] integerValue]);
        [historyChangedLabel setHidden:NO];
    }
}

#pragma mark - Startup API

// MIT license by Brian Dunagan
- (BOOL)isLaunchAtStartup {
    // See if the app is currently in LoginItems.
    LSSharedFileListItemRef itemRef = [self itemRefInLoginItems];
    // Store away that boolean.
    BOOL isInList = itemRef != nil;
    // Release the reference if it exists.
    if (itemRef != nil) CFRelease(itemRef);

    return isInList;
}

- (IBAction)toggleLaunchAtStartup:(id)sender {
    // Toggle the state.
    BOOL shouldBeToggled = ![self isLaunchAtStartup];
    // Get the LoginItems list.
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItemsRef == nil) return;
    if (shouldBeToggled) {
        // Add the app to the LoginItems list.
        CFURLRef appUrl = (__bridge CFURLRef)[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
        LSSharedFileListItemRef itemRef = LSSharedFileListInsertItemURL(loginItemsRef, kLSSharedFileListItemLast, NULL, NULL, appUrl, NULL, NULL);
        if (itemRef) CFRelease(itemRef);
    }
    else {
        // Remove the app from the LoginItems list.
        LSSharedFileListItemRef itemRef = [self itemRefInLoginItems];
        LSSharedFileListItemRemove(loginItemsRef,itemRef);
        if (itemRef != nil) CFRelease(itemRef);
    }
    CFRelease(loginItemsRef);
}

- (LSSharedFileListItemRef)itemRefInLoginItems {
    LSSharedFileListItemRef itemRef = nil;
    CFURLRef itemUrl = nil;

    // Get the app's URL.
    auto appUrl = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
    // Get the LoginItems list.
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItemsRef == nil) return nil;
    // Iterate over the LoginItems.
    NSArray *loginItems = (__bridge_transfer NSArray *)LSSharedFileListCopySnapshot(loginItemsRef, nil);
    for (int currentIndex = 0; currentIndex < [loginItems count]; currentIndex++) {
        // Get the current LoginItem and resolve its URL.
        LSSharedFileListItemRef currentItemRef = (__bridge LSSharedFileListItemRef)[loginItems objectAtIndex:currentIndex];
        if (LSSharedFileListItemResolve(currentItemRef, 0, &itemUrl, NULL) == noErr) {
            // Compare the URLs for the current LoginItem and the app.
            if ([(__bridge NSURL *)itemUrl isEqual:appUrl]) {
                // Save the LoginItem reference.
                itemRef = currentItemRef;
            }
        }
    }
    // Retain the LoginItem reference.
    if (itemRef != nil) CFRetain(itemRef);
    // Release the LoginItems lists.
    CFRelease(loginItemsRef);

    return itemRef;
}

#pragma mark - Profile Photo edition

- (IBAction) editPhoto:(id)sender {
    auto pictureTaker = [IKPictureTaker pictureTaker];
    [pictureTaker beginPictureTakerSheetForWindow:self.view.window
                                     withDelegate:self
                                   didEndSelector:@selector(pictureTakerDidEnd:returnCode:contextInfo:)
                                      contextInfo:nil];
}

- (void) pictureTakerDidEnd:(IKPictureTaker *) picker
                 returnCode:(NSInteger) code
                contextInfo:(void*) contextInfo
{
    if (auto outputImage = [picker outputImage]) {
        [photoView setImage:outputImage];
        if (auto pro = ProfileModel::instance().selectedProfile()) {
            QPixmap p;
            auto smallImg = [NSImage imageResize:outputImage newSize:{100,100}];
            if (p.loadFromData(QByteArray::fromNSData([smallImg TIFFRepresentation]))) {
                pro->person()->setPhoto(QVariant(p));
            }
            pro->save();
        }
    }
}

#pragma mark - NSTextFieldDelegate methods

-(void)controlTextDidChange:(NSNotification *)notif
{
    if (auto pro = ProfileModel::instance().selectedProfile()) {
        pro->person()->setFormattedName(profileNameField.stringValue.UTF8String);
        pro->save();
    }
}

@end
