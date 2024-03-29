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
#import "RingWizardChooseVC.h"
#import "RingWizardNewAccountVC.h"
#import "RingWizardLinkAccountVC.h"
#import "LrcModelsProtocol.h"
#import "AddSIPAccountVC.h"
#import "ConnectToAccManagerVC.h"
#import "AccountBackupVC.h"
#include <qstring.h>

@protocol AccountCreationDelegate <NSObject>
- (void)accountCreated:(QString)accountId;
@end

@interface RingWizardWC : NSWindowController <NSWindowDelegate, NSPathControlDelegate,
    NSOpenSavePanelDelegate, RingWizardChooseDelegate, RingWizardNewDelegate,
    RingWizardLinkDelegate, AddSIPAccountDelegate, RingWizardAccManagerDelegate, AccountBackupDelegate,
LrcModelsProtocol>
- (void)showChooseWithCancelButton:(BOOL)showCancel;
- (void)showNewAccountVC;
- (void)showLinkAccountVC;
- (void)showSIPAccountVC;
- (void)showConnectToAccountManager;
@property (weak, nonatomic) id <AccountCreationDelegate> delegate;
@end
