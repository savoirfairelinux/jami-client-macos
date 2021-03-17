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

//lrc
#import <api/datatransfermodel.h>
#import <api/avmodel.h>
#import <api/newaccountmodel.h>

#if ENABLE_SPARKLE
#import <Sparkle/Sparkle.h>
#endif

#import "Constants.h"
#import "utils.h"
#import "AppDelegate.h"

@interface GeneralPrefsVC () {
    __unsafe_unretained IBOutlet NSButton* startUpButton;
    __unsafe_unretained IBOutlet NSButton* toggleAutomaticUpdateCheck;
    __unsafe_unretained IBOutlet NSButton* alwaysRecording;
    __unsafe_unretained IBOutlet NSButton* recordPreview;
    __unsafe_unretained IBOutlet NSPopUpButton* checkIntervalPopUp;
    __unsafe_unretained IBOutlet NSStackView* sparkleContainer;
    __unsafe_unretained IBOutlet NSButton *downloadFolder;
    __unsafe_unretained IBOutlet NSTextField *downloadFolderLabel;
    __unsafe_unretained IBOutlet NSButton *recordingFolder;
    __unsafe_unretained IBOutlet NSTextField *recordingFolderLabel;
    __unsafe_unretained IBOutlet NSStackView *generalStackView;
    __unsafe_unretained IBOutlet NSStackView *conversationStackView;
    __unsafe_unretained IBOutlet NSStackView *recordingFolderStackView;
    __unsafe_unretained IBOutlet NSSlider *qualitySlider;
    __unsafe_unretained IBOutlet NSTextField *qualityLabel;
}
@end

@implementation GeneralPrefsVC

@synthesize avModel;
@synthesize accountModel;


-(id) initWithWindowNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil accountModel:( lrc::api::NewAccountModel*) accountModel avModel: (lrc::api::AVModel*)avModel {
    if (self =  [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.accountModel = accountModel;
        self.avModel = avModel;
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    CGFloat heightToReduice = 0;
    [startUpButton setState:[self isLaunchAtStartup]];
#if ENABLE_SPARKLE
    [sparkleContainer setHidden:NO];
    SUUpdater *updater = [SUUpdater sharedUpdater];
    [toggleAutomaticUpdateCheck bind:@"value" toObject:updater withKeyPath:@"automaticallyChecksForUpdates" options:nil];

    [checkIntervalPopUp bind:@"enabled" toObject:updater withKeyPath:@"automaticallyChecksForUpdates" options:nil];
    [checkIntervalPopUp bind:@"selectedTag" toObject:updater withKeyPath:@"updateCheckInterval" options:nil];
#else
    [sparkleContainer setHidden:YES];
    heightToReduice += (sparkleContainer.frame.size.height + 25);
#endif
    [alwaysRecording setState: avModel->getAlwaysRecord()];
    [recordPreview setState: avModel->getRecordPreview()];
    [qualitySlider setDoubleValue: avModel->getRecordQuality()];
    [qualityLabel setIntValue:avModel->getRecordQuality()];
    if (appSandboxed()) {
        [recordingFolderStackView setHidden:YES];
        [conversationStackView setHidden:YES];
        heightToReduice += (downloadFolder.frame.size.height + recordingFolder.frame.size.height + 25);
    } else {
        if (accountModel) {
           // AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
            //[appDelegate setDownloadDirectory: QString::fromNSString(path)];
            //self.accountModel->downloadDirectory = QString::fromNSString(path);
            downloadFolder.title = [self.accountModel->downloadDirectory.toNSString() lastPathComponent];
        }
        if (avModel) {
            auto name1 = avModel->getRecordPath();
            auto name = avModel->getRecordPath().toNSString();
            recordingFolder.title = [avModel->getRecordPath().toNSString() lastPathComponent];
        }
    }
    auto frame = self.view.frame;
    frame.size.height -= heightToReduice;
    self.view.frame = frame;
}

- (IBAction)changeDownloadFolder:(id)sender {

    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:NO];
    panel.delegate = self;
    if ([panel runModal] != NSFileHandlingPanelOKButton) return;
    if ([[panel URLs] lastObject] == nil) return;
    NSString * path = [[[[panel URLs] lastObject] path] stringByAppendingString:@"/"];
   // AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
   // self.accountModel->downloadDirectory = QString::fromNSString(path);
   // [appDelegate setDownloadDirectory: QString::fromNSString(path)];
   // dataTransferModel->downloadDirectory = QString::fromNSString(path);
   // downloadFolder.title = [self.accountModel->downloadDirectory.toNSString() lastPathComponent];
    [[NSUserDefaults standardUserDefaults] setObject:path forKey:Preferences::DownloadFolder];
}

- (IBAction)changeRecordingFolder:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:NO];
    panel.delegate = self;
    if ([panel runModal] != NSFileHandlingPanelOKButton) return;
    if ([[panel URLs] lastObject] == nil) return;
    NSString * path = [[[[panel URLs] lastObject] path] stringByAppendingString:@"/"];
    avModel->setRecordPath(QString::fromNSString(path));
    recordingFolder.title = [avModel->getRecordPath().toNSString() lastPathComponent];
    [[NSUserDefaults standardUserDefaults] setObject:path forKey:Preferences::DownloadFolder];
}

- (IBAction)alwaysRecording:(id)sender {
    avModel->setAlwaysRecord([sender state]);
}

- (IBAction)recordPreview:(id)sender {
    avModel->setRecordPreview([sender state]);
}

- (IBAction)setRecordingQuality:(NSSlider*)sender {
    avModel->setRecordQuality([sender intValue]);
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

#pragma mark - NSOpenSavePanelDelegate delegate methods

- (BOOL) panel:(id)sender shouldEnableURL:(NSURL*)url {
    return YES;
}

@end
