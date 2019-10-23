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

#import <Foundation/Foundation.h>

/**
 * Defines a set of preferences constants
 * WARNING: If you modify a KVO compliant value, make sure to change the string associated
 * in the relative xib file in IB.
 */
namespace Preferences {
    /* KVO compliant */
    NSString * const HistoryLimit = @"history_limit";
    /* KVO compliant */
    NSString * const WindowBehaviour = @"window_behaviour";
    /* KVO compliant */
    NSString * const CallNotifications = @"enable_call_notifications";
    /* KVO compliant */
    NSString * const MessagesNotifications = @"enable_messages_notifications";
    /* KVO compliant */
    NSString * const ContactRequestNotifications = @"enable_invitations_notifications";
    /* download folder for incoming images*/
    NSString * const DownloadFolder = @"download_folder";
}

NSString * const SkipBackUpPage = @"always_skip_backup_page";

const CGFloat MAX_IMAGE_SIZE = 1024;
