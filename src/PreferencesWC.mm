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
#import "PreferencesWC.h"

#import <QuartzCore/QuartzCore.h>

//LRC
#import <accountmodel.h>
#import <codecmodel.h>
#import <profilemodel.h>
#import <profile.h>

//Ring
#import "AccountsVC.h"
#import "GeneralPrefsVC.h"
#import "AudioPrefsVC.h"
#import "VideoPrefsVC.h"

@implementation PreferencesWC {

    __unsafe_unretained IBOutlet NSView *prefsContainer;
    NSViewController *currentVC;

}

// Identifiers used in PreferencesWindow.xib for tabs
static auto const kProfilePrefsIdentifier = @"AccountsPrefsIdentifier";
static auto const kGeneralPrefsIdentifier = @"GeneralPrefsIdentifier";
static auto const kAudioPrefsIdentifer    = @"AudioPrefsIdentifer";
static auto const kVideoPrefsIdentifer    = @"VideoPrefsIdentifer";

- (void)windowDidLoad
{
    [super windowDidLoad];
    [self.window setMovableByWindowBackground:YES];
    [self.window.toolbar setSelectedItemIdentifier:kGeneralPrefsIdentifier];
    [self displayGeneral:nil];
}

- (void)windowWillClose:(NSNotification *)notification
{
    AccountModel::instance().save();
    ProfileModel::instance().selectedProfile()->save();
}

- (IBAction)displayGeneral:(NSToolbarItem *)sender
{
    [[prefsContainer subviews]
     makeObjectsPerformSelector:@selector(removeFromSuperview)];
    currentVC = [[GeneralPrefsVC alloc] initWithNibName:@"GeneralPrefs" bundle:nil];

    [self resizeWindowWithFrame:currentVC.view.frame];
    [prefsContainer addSubview:currentVC.view];
}

- (IBAction)displayAudio:(NSToolbarItem *)sender
{
    [[prefsContainer subviews]
     makeObjectsPerformSelector:@selector(removeFromSuperview)];
    currentVC = [[AudioPrefsVC alloc] initWithNibName:@"AudioPrefs" bundle:nil];
    [self resizeWindowWithFrame:currentVC.view.frame];
    [prefsContainer addSubview:currentVC.view];
}

- (IBAction)displayVideo:(NSToolbarItem *)sender
{
    [[prefsContainer subviews]
     makeObjectsPerformSelector:@selector(removeFromSuperview)];
    currentVC = [[VideoPrefsVC alloc] initWithNibName:@"VideoPrefs" bundle:nil];
    [self resizeWindowWithFrame:currentVC.view.frame];
    [prefsContainer addSubview:currentVC.view];
}

- (IBAction)displayAccounts:(NSToolbarItem *)sender
{
    [[prefsContainer subviews]
     makeObjectsPerformSelector:@selector(removeFromSuperview)];
    currentVC = [[AccountsVC alloc] initWithNibName:@"Accounts" bundle:nil];
    [self resizeWindowWithFrame:currentVC.view.frame];
    [prefsContainer addSubview:currentVC.view];
}

- (void) resizeWindowWithFrame:(NSRect)fr
{
    auto frame = [self.window frame];
    frame.origin.y += frame.size.height;
    frame.origin.y -= NSHeight(fr) + [self toolBarHeight] + [self titleBarHeight];
    frame.size.height = NSHeight(fr) + [self toolBarHeight];
    frame.size.width = NSWidth(fr);
    frame = [NSWindow frameRectForContentRect:frame
                                         styleMask:[self.window styleMask]];

    [self.window setFrame:frame display:YES animate:YES];
}

- (CGFloat) toolBarHeight
{
    NSRect windowFrame;
    NSToolbar *toolbar = [self.window toolbar];
    CGFloat tHeight = 0.0;
    if (toolbar && [toolbar isVisible]) {

        windowFrame = [NSWindow contentRectForFrameRect:[self.window frame]
                                              styleMask:[self.window styleMask]];
        tHeight = NSHeight(windowFrame) - NSHeight([[self.window contentView] frame]);
    }
    return tHeight;
}

- (float) titleBarHeight
{
    NSRect frame = NSMakeRect (0, 0, 100, 100);
    NSRect contentRect;
    contentRect = [NSWindow contentRectForFrameRect: frame
                                          styleMask: NSTitledWindowMask];

    return (frame.size.height - contentRect.size.height);
}

@end
