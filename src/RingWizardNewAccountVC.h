/*
 *  Copyright (C) 2015-2016 Savoir-faire Linux Inc.
 *  Author: Loïc Siret <loic.siret@savoirfairelinux.com>
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

@protocol RingWizardNewDelegate <NSObject>
- (void)didCreateAccountWithSuccess:(BOOL)success;
- (void)showView:(NSView*)view;
- (void) updateFrame:(float)height;
@end

@interface RingWizardNewAccountVC : NSViewController <LrcModelsProtocol>

@property (nonatomic, weak)NSWindowController <RingWizardNewDelegate>* delegate;

@property (nonatomic, weak)NSString* registeredName;
@property (nonatomic, weak)NSString* password;
@property (nonatomic, weak)NSString* repeatPassword;
@property (readonly)BOOL isRepeatPasswordValid;
@property (readonly)BOOL isPasswordValid;
@property (assign)BOOL isUserNameAvailable;

@property (readonly)BOOL userNameAvailableORNotBlockchain;
@property (readonly)BOOL withBlockchain;
@property (assign)NSInteger signUpBlockchainState;
- (void)show;
@end
