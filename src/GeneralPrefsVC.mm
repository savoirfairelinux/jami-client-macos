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
#import "GeneralPrefsVC.h"

#import <categorizedhistorymodel.h>

#import "Constants.h"

@interface GeneralPrefsVC ()
@property (assign) IBOutlet NSTextField *historyChangedLabel;
@property (assign) IBOutlet NSView *advancedGeneralSettings;
@property (unsafe_unretained) IBOutlet NSButton *startUpButton;

@end

@implementation GeneralPrefsVC
@synthesize historyChangedLabel;
@synthesize advancedGeneralSettings;
@synthesize startUpButton;

- (void)loadView
{
    [super loadView];
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:Preferences::HistoryLimit options:NSKeyValueObservingOptionNew context:NULL];
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:Preferences::ShowAdvanced options:NSKeyValueObservingOptionNew context:NULL];

    [startUpButton setState:[self isLaunchAtStartup]];

    [advancedGeneralSettings setHidden:![[NSUserDefaults standardUserDefaults] boolForKey:Preferences::ShowAdvanced]];
}

- (IBAction)clearHistory:(id)sender {
    CategorizedHistoryModel::instance()->clearAllCollections();
    [historyChangedLabel setHidden:NO];
}

// KVO handler
-(void)observeValueForKeyPath:(NSString *)aKeyPath ofObject:(id)anObject
                       change:(NSDictionary *)aChange context:(void *)aContext
{
    if (aKeyPath == Preferences::HistoryLimit) {
        [historyChangedLabel setHidden:NO];
    } else if (aKeyPath == Preferences::ShowAdvanced) {
        [advancedGeneralSettings setHidden:[[aChange objectForKey: NSKeyValueChangeNewKey] boolValue]];
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
        CFURLRef appUrl = (CFURLRef)[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
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
    NSURL *itemUrl = nil;

    // Get the app's URL.
    NSURL *appUrl = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
    // Get the LoginItems list.
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItemsRef == nil) return nil;
    // Iterate over the LoginItems.
    NSArray *loginItems = (NSArray *)LSSharedFileListCopySnapshot(loginItemsRef, nil);
    for (int currentIndex = 0; currentIndex < [loginItems count]; currentIndex++) {
        // Get the current LoginItem and resolve its URL.
        LSSharedFileListItemRef currentItemRef = (LSSharedFileListItemRef)[loginItems objectAtIndex:currentIndex];
        if (LSSharedFileListItemResolve(currentItemRef, 0, (CFURLRef *) &itemUrl, NULL) == noErr) {
            // Compare the URLs for the current LoginItem and the app.
            if ([itemUrl isEqual:appUrl]) {
                // Save the LoginItem reference.
                itemRef = currentItemRef;
            }
        }
    }
    // Retain the LoginItem reference.
    if (itemRef != nil) CFRetain(itemRef);
    // Release the LoginItems lists.
    [loginItems release];
    CFRelease(loginItemsRef);

    return itemRef;
}

@end
