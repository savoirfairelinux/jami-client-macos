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
#import "PreferencesViewController.h"

#import <QuartzCore/QuartzCore.h>

#import <accountmodel.h>
#import <audio/codecmodel.h>

#import "AccountsVC.h"
#import "GeneralPrefsVC.h"
#import "AudioPrefsVC.h"
#import "VideoPrefsVC.h"

@interface PreferencesViewController ()

@property NSButton* toggleAdvancedSettings;

@end

@implementation PreferencesViewController
@synthesize toggleAdvancedSettings;

static NSString* const kProfilePrefsIdentifier = @"ProfilesPrefsIdentifier";
static NSString* const kGeneralPrefsIdentifier = @"GeneralPrefsIdentifier";
static NSString* const kAudioPrefsIdentifer = @"AudioPrefsIdentifer";
static NSString* const kAncragePrefsIdentifer = @"AncragePrefsIdentifer";
static NSString* const kVideoPrefsIdentifer = @"VideoPrefsIdentifer";
static NSString* const kDonePrefsIdentifer = @"DonePrefsIdentifer";
static NSString* const kPowerSettingsIdentifer = @"PowerSettingsIdentifer";

-(void)loadView
{
    [super loadView];

    [self displayGeneral:nil];

    [self.view setWantsLayer:YES];
    self.view.layer.backgroundColor = [NSColor windowBackgroundColor].CGColor;

    // Set the layer redraw policy. This would be better done in
    // the initialization method of a NSView subclass instead of here.
    self.view.layerContentsRedrawPolicy = NSViewLayerContentsRedrawDuringViewResize;

    [self.view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

    CGRect frame = CGRectOffset(self.view.frame, 0, -self.view.frame.size.height);

    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
    animation.fromValue = [NSValue valueWithPoint:frame.origin];
    animation.toValue = [NSValue valueWithPoint:self.view.frame.origin];
    animation.duration = 0.3f;
    [animation setTimingFunction:[CAMediaTimingFunction functionWithControlPoints:.7 :0.9 :1 :1]];
    [self.view.layer addAnimation:animation forKey:animation.keyPath];
}

- (void) close
{
    // first save codecs for each account
    for (int i = 0 ; i < AccountModel::instance()->rowCount(); ++i) {
        QModelIndex qIdx = AccountModel::instance()->index(i);
        AccountModel::instance()->getAccountByModelIndex(qIdx)->codecModel()->save();
    }

    // then save accounts
    AccountModel::instance()->save();

    CGRect frame = CGRectOffset(self.view.frame, 0, -self.view.frame.size.height);

    [CATransaction begin];
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
    animation.fromValue = [NSValue valueWithPoint:self.view.frame.origin];
    animation.toValue = [NSValue valueWithPoint:frame.origin];
    animation.duration = 0.3f;
    [animation setTimingFunction:[CAMediaTimingFunction functionWithControlPoints:.7 :0.9 :1 :1]];

    [CATransaction setCompletionBlock:^{
        [self.view removeFromSuperview];
    }];


    [self.view.layer addAnimation:animation forKey:animation.keyPath];
    [CATransaction commit];
}

- (void)displayGeneral:(NSToolbarItem *)sender {
    if (self.currentVC != nil) {
        [self.currentVC.view removeFromSuperview];
    }
    self.generalPrefsVC = [[GeneralPrefsVC alloc] initWithNibName:@"GeneralPrefs" bundle:nil];
    [self.view addSubview:self.generalPrefsVC.view];
    [self.generalPrefsVC.view setFrame:[self.view bounds]];
    self.currentVC = self.generalPrefsVC;
}

- (void)displayAudio:(NSToolbarItem *)sender {
    if (self.currentVC != nil) {
        [self.currentVC.view removeFromSuperview];
    }
    self.audioPrefsVC = [[AudioPrefsVC alloc] initWithNibName:@"AudioPrefs" bundle:nil];
    [self.view addSubview:self.audioPrefsVC.view];
    [self.audioPrefsVC.view setFrame:[self.view bounds]];
    self.currentVC = self.audioPrefsVC;
}

- (void)displayAncrage:(NSToolbarItem *)sender {

}

- (void)displayVideo:(NSToolbarItem *)sender {
    if (self.currentVC != nil) {
        [self.currentVC.view removeFromSuperview];
    }
    self.videoPrefsVC = [[VideoPrefsVC alloc] initWithNibName:@"VideoPrefs" bundle:nil];
    [self.view addSubview:self.videoPrefsVC.view];
    [self.videoPrefsVC.view setFrame:[self.view bounds]];
    self.currentVC = self.videoPrefsVC;
}

- (void) displayAccounts:(NSToolbarItem *) sender {
    if (self.currentVC != nil) {
        [self.currentVC.view removeFromSuperview];
    }
    self.accountsPrefsVC = [[AccountsVC alloc] initWithNibName:@"Accounts" bundle:nil];
    [self.view addSubview:self.accountsPrefsVC.view];
    [self.accountsPrefsVC.view setFrame:[self.view bounds]];
    self.currentVC = self.accountsPrefsVC;
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
        [toggleAdvancedSettings setState:[[NSUserDefaults standardUserDefaults] boolForKey:@"show_advanced"]];
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

    if([[NSUserDefaults standardUserDefaults] boolForKey:@"show_advanced"]) {
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

    if([[NSUserDefaults standardUserDefaults] boolForKey:@"show_advanced"])
        [items insertObject:kProfilePrefsIdentifier atIndex:1];


    return items;
}

-(NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
    return nil;
}





@end
