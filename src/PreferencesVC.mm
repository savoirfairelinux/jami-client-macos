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
#import "PreferencesVC.h"

#import <QuartzCore/QuartzCore.h>

#import <accountmodel.h>
#import <audio/codecmodel.h>

#import "AccountsVC.h"
#import "GeneralPrefsVC.h"
#import "AudioPrefsVC.h"
#import "VideoPrefsVC.h"
#import "AccGeneralVC.h"
#import "Constants.h"

@interface PreferencesVC ()

@property NSButton* toggleAdvancedSettings;

@property (unsafe_unretained) IBOutlet NSTabView *tabView;
@property (unsafe_unretained) IBOutlet NSTabViewItem *generalTabItem;
@property (unsafe_unretained) IBOutlet NSTabViewItem *accountsTabItem;
@property (unsafe_unretained) IBOutlet NSTabViewItem *audioTabItem;
@property (unsafe_unretained) IBOutlet NSTabViewItem *videoTabItem;


@end

@implementation PreferencesVC
@synthesize toggleAdvancedSettings;


static NSString* const kProfilePrefsIdentifier = @"ProfilesPrefsIdentifier";
static NSString* const kGeneralPrefsIdentifier = @"GeneralPrefsIdentifier";
static NSString* const kAudioPrefsIdentifer = @"AudioPrefsIdentifer";
static NSString* const kVideoPrefsIdentifer = @"VideoPrefsIdentifer";
static NSString* const kDonePrefsIdentifer = @"DonePrefsIdentifer";
static NSString* const kPowerSettingsIdentifer = @"PowerSettingsIdentifer";

- (void)awakeFromNib
{

}

- (void)windowDidLoad
{
    [self.window.toolbar setSelectedItemIdentifier:kGeneralPrefsIdentifier];
    [self displayGeneral:nil];
}

- (void)windowWillClose:(NSNotification *)notification
{
    AccountModel::instance()->save();
}

- (IBAction)displayGeneral:(NSToolbarItem *)sender
{
    [self.tabView selectTabViewItemAtIndex:0];
    self.generalPrefsVC = [[GeneralPrefsVC alloc] initWithNibName:@"GeneralPrefs" bundle:nil];
    [[self.generalPrefsVC view] setFrame:[self.generalTabItem.view frame]];
    [[self.generalPrefsVC view] setBounds:[self.generalTabItem.view bounds]];
    [self.generalTabItem setView:self.generalPrefsVC.view];
}

- (IBAction)displayAudio:(NSToolbarItem *)sender
{
    [self.tabView selectTabViewItemAtIndex:1];
    self.audioPrefsVC = [[AudioPrefsVC alloc] initWithNibName:@"AudioPrefs" bundle:nil];
    [[self.audioPrefsVC view] setFrame:[self.audioTabItem.view frame]];
    [[self.audioPrefsVC view] setBounds:[self.audioTabItem.view bounds]];
    [self.audioTabItem setView:self.audioPrefsVC.view];
}

- (IBAction)displayVideo:(NSToolbarItem *)sender
{
    [self.tabView selectTabViewItemAtIndex:2];
    self.videoPrefsVC = [[VideoPrefsVC alloc] initWithNibName:@"VideoPrefs" bundle:nil];
    [[self.videoPrefsVC view] setFrame:[self.videoTabItem.view frame]];
    [[self.videoPrefsVC view] setBounds:[self.videoTabItem.view bounds]];
    [self.videoTabItem setView:self.videoPrefsVC.view];
}

- (IBAction)displayAccounts:(NSToolbarItem *)sender
{
    [self.tabView selectTabViewItemAtIndex:3];
    self.accountsPrefsVC = [[AccountsVC alloc] initWithNibName:@"Accounts" bundle:nil];
    [[self.accountsPrefsVC view] setFrame:[self.accountsTabItem.view frame]];
    [[self.accountsPrefsVC view] setBounds:[self.accountsTabItem.view bounds]];
    [self.accountsTabItem setView:self.accountsPrefsVC.view];
}


#pragma NSToolbar Delegate

-(NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem* item = nil;

    if ([itemIdentifier isEqualToString: kProfilePrefsIdentifier]) {

        item = [[NSToolbarItem alloc] initWithItemIdentifier: kProfilePrefsIdentifier];
        [item setImage: [NSImage imageNamed: @"NSUserAccounts"]];
        [item setLabel: @"Accounts"];
        [item setAction:@selector(displayAccounts:)];
    }

    if ([itemIdentifier isEqualToString: kGeneralPrefsIdentifier]) {
        item = [[NSToolbarItem alloc] initWithItemIdentifier: kGeneralPrefsIdentifier];
        [item setImage: [NSImage imageNamed: @"general"]];
        [item setLabel: @"General"];
        [item setAction:@selector(displayGeneral:)];
    }

    if ([itemIdentifier isEqualToString: kAudioPrefsIdentifer]) {
        item = [[NSToolbarItem alloc] initWithItemIdentifier: kAudioPrefsIdentifer];
        [item setImage: [NSImage imageNamed: @"audio"]];
        [item setLabel: @"Audio"];
        [item setAction:@selector(displayAudio:)];
    }

    if ([itemIdentifier isEqualToString: kPowerSettingsIdentifer]) {
        item = [[NSToolbarItem alloc] initWithItemIdentifier: kPowerSettingsIdentifer];
        toggleAdvancedSettings = [[NSButton alloc] initWithFrame:NSMakeRect(0,0,20,20)];
        [toggleAdvancedSettings setButtonType:NSSwitchButton];
        [toggleAdvancedSettings setTitle:@""];
        [toggleAdvancedSettings setState:[[NSUserDefaults standardUserDefaults] boolForKey:Preferences::ShowAdvanced]];
        [item setLabel:@"Show Advanced"];
        [item setView:toggleAdvancedSettings];
        [item setAction:@selector(togglePowerSettings:)];
    }

    if ([itemIdentifier isEqualToString: kDonePrefsIdentifer]) {
        item = [[NSToolbarItem alloc] initWithItemIdentifier: kDonePrefsIdentifer];
        [item setImage: [NSImage imageNamed: @"ic_action_cancel"]];
        [item setLabel: @"Done"];
        [item setAction:@selector(closePreferences:)];
    }

    if ([itemIdentifier isEqualToString: kVideoPrefsIdentifer]) {
        item = [[NSToolbarItem alloc] initWithItemIdentifier: kVideoPrefsIdentifer];
        [item setImage: [NSImage imageNamed: @"video"]];
        [item setLabel: @"Video"];
        [item setAction:@selector(displayVideo:)];
    }

    return item;
}

-(NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{

    NSMutableArray* items = [NSMutableArray arrayWithObjects:
                      kPowerSettingsIdentifer,
                      NSToolbarFlexibleSpaceItemIdentifier,
                      kGeneralPrefsIdentifier,
                      kAudioPrefsIdentifer,
                      kVideoPrefsIdentifer,
                      //           kAncragePrefsIdentifer,
                      NSToolbarFlexibleSpaceItemIdentifier,
                      kDonePrefsIdentifer,
                      nil];

    if([[NSUserDefaults standardUserDefaults] boolForKey:Preferences::ShowAdvanced]) {
        [items insertObject:NSToolbarSpaceItemIdentifier atIndex:5];
        [items insertObject:kProfilePrefsIdentifier atIndex:2];
    } else
        [items insertObject:NSToolbarSpaceItemIdentifier atIndex:5];

    return items;
}

-(NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
    NSMutableArray* items = [NSMutableArray arrayWithObjects:
                             kPowerSettingsIdentifer,
                             kGeneralPrefsIdentifier,
                             kAudioPrefsIdentifer,
                             kVideoPrefsIdentifer,
                             nil];

    if([[NSUserDefaults standardUserDefaults] boolForKey:Preferences::ShowAdvanced])
        [items insertObject:kProfilePrefsIdentifier atIndex:1];


    return items;
}

-(NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
    return nil;
}





@end
