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
#import "RingWindowController.h"

#import <historymodel.h>
#import <accountmodel.h>
#import <callmodel.h>
#import <account.h>
#include <call.h>

@interface RingWindowController ()


@end

@implementation RingWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    [self connectSlots];
}


- (void) connectSlots
{
    CallModel* callModel_ = CallModel::instance();
    QObject::connect(callModel_, &CallModel::callStateChanged, [](Call*, Call::State) {
        NSLog(@"callStateChanged");
    });
    
    QObject::connect(callModel_, &CallModel::incomingCall, [] (Call*) {
        NSLog(@"incomingCall");
    });
    
}

- (IBAction)openPreferences:(id)sender
{

    if(self.preferencesViewController != nil)
        return;
    NSToolbar* tb = [[NSToolbar alloc] initWithIdentifier: @"PreferencesToolbar"];



    self.preferencesViewController = [[PreferencesViewController alloc] initWithNibName:@"PreferencesScreen" bundle:nil];

    self.myCurrentViewController = self.preferencesViewController;

    NSLayoutConstraint* test = [NSLayoutConstraint constraintWithItem:self.preferencesViewController.view
                                                            attribute:NSLayoutAttributeWidth
                                                            relatedBy:NSLayoutRelationEqual
                                                               toItem:currentView
                                                            attribute:NSLayoutAttributeWidth
                                                           multiplier:1.0f
                                                             constant:0.0f];

    NSLayoutConstraint* test2 = [NSLayoutConstraint constraintWithItem:self.preferencesViewController.view
                                                             attribute:NSLayoutAttributeHeight
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:currentView
                                                             attribute:NSLayoutAttributeHeight
                                                            multiplier:1.0f
                                                              constant:0.0f];

    NSLayoutConstraint* test3 = [NSLayoutConstraint constraintWithItem:self.preferencesViewController.view
                                                             attribute:NSLayoutAttributeCenterX
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:currentView
                                                             attribute:NSLayoutAttributeCenterX
                                                            multiplier:1.0f
                                                              constant:0.0f];


    [currentView addSubview:[self.preferencesViewController view]];

    [tb setDelegate: self.preferencesViewController];
    [self.window setToolbar: tb];

    [self.window.toolbar setSelectedItemIdentifier:@"GeneralPrefsIdentifier"];

    [currentView addConstraint:test];
    [currentView addConstraint:test2];
    [currentView addConstraint:test3];
    // make sure we automatically resize the controller's view to the current window size
    [[self.myCurrentViewController view] setFrame:[currentView bounds]];

    // set the view controller's represented object to the number of subviews in that controller
    // (our NSTextField's value binding will reflect this value)
    [self.myCurrentViewController setRepresentedObject:[NSNumber numberWithUnsignedInteger:[[[self.myCurrentViewController view] subviews] count]]];
    
}

- (IBAction)showNotification:(id)sender{
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = @"Hello, World!";
    notification.informativeText = @"A notification";
    notification.soundName = NSUserNotificationDefaultSoundName;

    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

- (IBAction) closePreferences:(NSToolbarItem *)sender {
    if(self.myCurrentViewController != nil)
    {
        [self.preferencesViewController close];
        [self.window setToolbar:nil];
        self.preferencesViewController = nil;
    }
}

// FIXME: This is sick, NSWindowController is catching my selectors
- (void)displayGeneral:(NSToolbarItem *)sender {
    [self.preferencesViewController displayGeneral:sender];
}

- (void)displayAudio:(NSToolbarItem *)sender {
    [self.preferencesViewController displayAudio:sender];
}

- (void)displayAncrage:(NSToolbarItem *)sender {
    [self.preferencesViewController displayAncrage:sender];
}

- (void)displayVideo:(NSToolbarItem *)sender {
    [self.preferencesViewController displayVideo:sender];
}

@end
