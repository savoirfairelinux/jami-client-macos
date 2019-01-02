/*
 *  Copyright (C) 2016-2019 Savoir-faire Linux Inc.
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


#import "LoadingWCDelegate.h"
#import "AbstractLoadingWC.h"
#import "LrcModelsProtocol.h"
#include <string>

@interface ExportPasswordWC : AbstractLoadingWC <LrcModelsProtocol>

/**
 * password string contained in passwordField.
 * This is a KVO method to bind the text with the OK Button
 * if password.length is > 0, button is enabled, otherwise disabled
 */
@property (retain) NSString* password;
@property std::string selectedAccountID;

@end
