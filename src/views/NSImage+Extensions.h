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
#import <api/contact.h>
#import <api/lrc.h>

@interface NSImage (Extensions)

/**
 * @param anImage is the original NSImage
 * @param newSize is the desired output size
 * @return a resized NSImage
 */
+ (NSImage *)imageResize:(NSImage*)anImage
                 newSize:(NSSize)newSize;

- (NSImage *) roundCorners:(CGFloat)radius;

- (NSImage *) imageResizeInsideMax:(CGFloat) dimension;

- (NSImage *) cropImageToSize:(NSSize)newSize;

@end
