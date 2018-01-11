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
#import <Cocoa/Cocoa.h>

namespace lrc {
    namespace api {
        namespace account {
            struct Info;
        }
    }
}

@interface RingWindowController : NSWindowController <NSSharingServicePickerDelegate> {
    IBOutlet NSView *currentView;
}

/**
 * KVO to show or hide some UI elements in RingWindow:
 * - Share button
 * - QRCode
 * - RingID field
 * - Explanatory label
 */
@property (nonatomic) BOOL hideRingID;

- (IBAction)openPreferences:(id)sender;

/**
 * This method is intended to be used by the ChooseAccountVC to signal the fact that
 * the selected account has been changed by user. It will then forward this information
 * to relevant controllers and views.
 * @param accInfo reference to selected account
 */
- (void) selectAccount:(const lrc::api::account::Info&)accInfo;

/**
 * Method triggered when a panel on the right is closed by user action. It triggers any action needed
 * on itself or other view controllers to react properly to this event.
 */
-(void) rightPanelClosed;

/**
 * Triggered by Conversation view when the current conversation is switching from pending state to
 * trusted. It triggers conversation list change in SmartViewVC in order to keep current conversation
 * visible in left list (to "follow it").
 */
-(void) currentConversationTrusted;

@end
