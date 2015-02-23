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

#import <Cocoa/Cocoa.h>

@interface PreferencesViewController : NSViewController <NSToolbarDelegate>

- (void) close;
@property (nonatomic, assign) NSViewController *currentVC;
@property (nonatomic, assign) NSViewController *generalPrefsVC;
@property (nonatomic, assign) NSViewController *audioPrefsVC;
@property (nonatomic, assign) NSViewController *videoPrefsVC;

- (void)displayGeneral:(NSToolbarItem *)sender;
- (void)displayAudio:(NSToolbarItem *)sender;
- (void)displayAncrage:(NSToolbarItem *)sender;
- (void)displayVideo:(NSToolbarItem *)sender;

@end


