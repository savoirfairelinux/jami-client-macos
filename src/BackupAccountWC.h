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

#import <QtCore/qdir.h>

#import "LoadingWCDelegate.h"
#import "AbstractLoadingWC.h"

@protocol BackupAccountDelegate <LoadingWCDelegate>

@optional

-(void) didCompleteExportWithPath:(NSURL*) path;

@end

@interface BackupAccountWC : AbstractLoadingWC

- (id)initWithDelegate:(id <LoadingWCDelegate>) del;

/**
 * Allow the NSPathControl of this window to select files or not
 */
@property (nonatomic) BOOL allowFileSelection;

/**
 * password string contained in passwordField.
 * This is a KVO method to bind the text with the OK Button
 * if password.length is > 0, button is enabled, otherwise disabled
 */
@property (retain) NSString* password;

/**
 * Object uses to store account to exports
 */
@property (assign) QStringList accounts;

/**
 * passwordConfirmation string contained in passwordConfirmationField.
 */
@property (retain) NSString* passwordConfirmation;

/**
 * computed properties calculated by password string contained in
 * passwordField and passwordCOnfirmation string contained
 * inpasswordConfirmationField
 * This is a KVO method to bind the text with the OK Button
 * if password.length is > 0 AND passwordConfirmation.length > 0
 * AND password isEqualsToString passwordCOnfirmationbutton is enabled,
 * otherwise disabled
 */
@property (readonly) BOOL validatePasswords;

@end
