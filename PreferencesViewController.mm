/************************************************************************************
 *   Copyright (C) 2014-2015 by Savoir-Faire Linux                                  *
 *   Author : Alexandre Lision <alexandre.lision@savoirfairelinux.com>              *
 *                                                                                  *
 *   This library is free software; you can redistribute it and/or                  *
 *   modify it under the terms of the GNU Lesser General Public                     *
 *   License as published by the Free Software Foundation; either                   *
 *   version 2.1 of the License, or (at your option) any later version.             *
 *                                                                                  *
 *   This library is distributed in the hope that it will be useful,                *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of                 *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU              *
 *   Lesser General Public License for more details.                                *
 *                                                                                  *
 *   You should have received a copy of the GNU Lesser General Public               *
 *   License along with this library; if not, write to the Free Software            *
 *   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA *
 ***********************************************************************************/
#import "PreferencesViewController.h"

#import <QuartzCore/QuartzCore.h>

#import "GeneralPrefsVC.h"
#import "AudioPrefsVC.h"
#import "VideoPrefsVC.h"

@interface PreferencesViewController ()

@end

@implementation PreferencesViewController

static NSString* const kGeneralPrefsIdentifier = @"GeneralPrefsIdentifier";
static NSString* const kAudioPrefsIdentifer = @"AudioPrefsIdentifer";
static NSString* const kAncragePrefsIdentifer = @"AncragePrefsIdentifer";
static NSString* const kVideoPrefsIdentifer = @"VideoPrefsIdentifer";
static NSString* const kDonePrefsIdentifer = @"DonePrefsIdentifer";

-(void)loadView
{
    [super loadView];

    [self displayGeneral:nil];

    [self.view setWantsLayer:YES];
    self.view.layer.backgroundColor = [NSColor windowBackgroundColor].CGColor;

    // Set the layer redraw policy. This would be better done in
    // the initialization method of a NSView subclass instead of here.
    self.view.layerContentsRedrawPolicy = NSViewLayerContentsRedrawDuringViewResize;

    CGRect frame = CGRectOffset(self.view.frame, 0, -self.view.frame.size.height);

    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
    animation.fromValue = [NSValue valueWithPoint:frame.origin];
    animation.toValue = [NSValue valueWithPoint:self.view.frame.origin];
    animation.duration = 0.3f;
    [animation setTimingFunction:[CAMediaTimingFunction functionWithControlPoints:.7 :0.9 :1 :1]];


    [self.view.layer addAnimation:animation forKey:animation.keyPath];
    self.view.layer.position = frame.origin;
}

- (void) close
{
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


#pragma NSToolbar Delegate

-(NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem* item = nil;

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

//    if ([itemIdentifier isEqualToString: kAncragePrefsIdentifer]) {
//        item = [[NSToolbarItem alloc] initWithItemIdentifier: kAncragePrefsIdentifer];
//        [item setImage: [NSImage imageNamed: @"ancrage"]];
//        [item setLabel: @"Ancrage"];
//        [item setAction:@selector(displayAncrage:)];
//    }

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
    return [NSArray arrayWithObjects:
            NSToolbarSpaceItemIdentifier,
            NSToolbarFlexibleSpaceItemIdentifier,
            kGeneralPrefsIdentifier,
            kAudioPrefsIdentifer,
            kVideoPrefsIdentifer,
 //           kAncragePrefsIdentifer,
            NSToolbarFlexibleSpaceItemIdentifier,
            kDonePrefsIdentifer,
            nil];
}

-(NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:
            kGeneralPrefsIdentifier,
            kAudioPrefsIdentifer,
 //           kAncragePrefsIdentifer,
            kVideoPrefsIdentifer,
            nil];
}

-(NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
    return nil;
}





@end
