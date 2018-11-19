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

@interface NSColor (RingTheme)

+ (NSColor*) ringBlue;
+ (NSColor*) ringLightBlue;
+ (NSColor*) ringBlueWithAlpha:(CGFloat) a;

+ (NSColor*) ringDarkBlue;

+ (NSColor*) ringGreyHighlight;
+ (NSColor*) ringGreyLight;
+ (NSColor*) ringDarkGrey;
+ (NSColor*) errorColor;
+ (NSColor*) greenSuccessColor;
+ (NSColor*) errorTransferColor;
+ (NSColor*) presenceColor;
+ (NSColor*) unregisteredColor;

- (NSColor *)lightenColorByValue:(float)value;
- (NSColor *)darkenColorByValue:(float)value;
- (BOOL)isLightColor;

+ (NSImage*) image:(NSImage*) img tintedWithColor:(NSColor *)tint;

@end
