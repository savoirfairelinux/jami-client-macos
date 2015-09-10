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
#import "PreferencesWC.h"

#import <QuartzCore/QuartzCore.h>

#import <accountmodel.h>
#import <audio/codecmodel.h>

#import "AccountsVC.h"
#import "GeneralPrefsVC.h"
#import "AudioPrefsVC.h"
#import "VideoPrefsVC.h"
#import "Constants.h"

@interface PreferencesWC ()

@property NSButton* toggleAdvancedSettings;

@property (unsafe_unretained) IBOutlet NSView *prefsContainer;
@property (nonatomic, strong) NSViewController *currentVC;

@end

@implementation PreferencesWC
@synthesize toggleAdvancedSettings;

static NSString* const kProfilePrefsIdentifier = @"AccountsPrefsIdentifier";
static NSString* const kGeneralPrefsIdentifier = @"GeneralPrefsIdentifier";
static NSString* const kAudioPrefsIdentifer = @"AudioPrefsIdentifer";
static NSString* const kVideoPrefsIdentifer = @"VideoPrefsIdentifer";

- (void)windowDidLoad
{
    [self.window setMovableByWindowBackground:YES];
    [self.window.toolbar setSelectedItemIdentifier:kGeneralPrefsIdentifier];
    [self displayGeneral:nil];
}

- (void)windowWillClose:(NSNotification *)notification
{
    AccountModel::instance()->save();
}

- (IBAction)displayGeneral:(NSToolbarItem *)sender
{
    [[self.prefsContainer subviews]
     makeObjectsPerformSelector:@selector(removeFromSuperview)];
    self.currentVC = [[GeneralPrefsVC alloc] initWithNibName:@"GeneralPrefs" bundle:nil];

    [self resizeWindowWithFrame:self.currentVC.view.frame];
    [self.prefsContainer addSubview:self.currentVC.view];
}

- (IBAction)displayAudio:(NSToolbarItem *)sender
{
    [[self.prefsContainer subviews]
     makeObjectsPerformSelector:@selector(removeFromSuperview)];
    self.currentVC = [[AudioPrefsVC alloc] initWithNibName:@"AudioPrefs" bundle:nil];
    [self resizeWindowWithFrame:self.currentVC.view.frame];
    [self.prefsContainer addSubview:self.currentVC.view];
}

- (IBAction)displayVideo:(NSToolbarItem *)sender
{
    [[self.prefsContainer subviews]
     makeObjectsPerformSelector:@selector(removeFromSuperview)];
    self.currentVC = [[VideoPrefsVC alloc] initWithNibName:@"VideoPrefs" bundle:nil];
    [self resizeWindowWithFrame:self.currentVC.view.frame];
    [self.prefsContainer addSubview:self.currentVC.view];
}

- (IBAction)displayAccounts:(NSToolbarItem *)sender
{
    [[self.prefsContainer subviews]
     makeObjectsPerformSelector:@selector(removeFromSuperview)];
    self.currentVC = [[AccountsVC alloc] initWithNibName:@"Accounts" bundle:nil];
    [self resizeWindowWithFrame:self.currentVC.view.frame];
    [self.prefsContainer addSubview:self.currentVC.view];
}

- (void) resizeWindowWithFrame:(NSRect)fr
{
    NSToolbar *toolbar = [self.window toolbar];
    CGFloat toolbarHeight = 0.0;
    NSRect windowFrame;

    if (toolbar && [toolbar isVisible]) {
        windowFrame = [NSWindow contentRectForFrameRect:[self.window frame]
                                                  styleMask:[self.window styleMask]];
        toolbarHeight = NSHeight(windowFrame) - NSHeight([[self.window contentView] frame]);
    }

    auto frame = [self.window frame];
    frame.origin.y += frame.size.height;
    frame.origin.y -= NSHeight(fr) + toolbarHeight;
    frame.size.height = NSHeight(fr) + toolbarHeight;
    frame.size.width = NSWidth(fr);

    frame = [NSWindow frameRectForContentRect:frame
                                         styleMask:[self.window styleMask]];

    [self.window setFrame:frame display:YES animate:YES];
}

@end
