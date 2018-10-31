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
#import "LrcModelsProtocol.h"
#import "ChooseAccountVC.h"
#import "CurrentCallVC.h"

namespace lrc {
    namespace api {
        namespace account {
            struct Info;
        }
    }
}

@interface RingWindowController : NSWindowController <NSSharingServicePickerDelegate, ChooseAccountDelegate, LrcModelsProtocol, CallViewControllerDelegate> {
    IBOutlet NSView *currentView;
}

/**
 * KVO to show or hide some UI elements in RingWindow:
 * - Share button
 * - QRCode
 * - Explanatory label
 */
@property (nonatomic) BOOL notRingAccount;
/**
 * KVO to show or hide ringIDLabel
 */
@property (nonatomic) BOOL isSIPAccount;


- (IBAction)openPreferences:(id)sender;

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

/**
 * Triggered by SmartView when list type is changed by user. It closes the right view as the selected conversation
 * is not in filtered list anymore.
 * @note This method is not to be used if list change is triggered by a left panel view.
 */
-(void) listTypeChanged;

@end
