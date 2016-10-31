/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
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

#import "AbstractLoadingWC.h"
#import "LoadingWCDelegate.h"

@protocol RegisterNameDelegate <LoadingWCDelegate>

@optional

- (void) didRegisterNameWithSuccess;

@end

@interface RegisterNameWC : AbstractLoadingWC

- (id)initWithDelegate:(id <LoadingWCDelegate>) del;

@property (nonatomic, weak) NSWindowController <RegisterNameDelegate>* delegate;

@property (nonatomic, weak)NSString* registeredName;
@property (nonatomic, weak)NSString* password;

@property (readonly)BOOL isPasswordValid;
@property (assign)BOOL isUserNameAvailable;

@end
