/*
 *  Copyright (C) 2015-2017 Savoir-faire Linux Inc.
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

typedef NS_ENUM(NSInteger, PointerDirection) {
    LEFT = 0,
    RIGHT,
    BLOCK,
};
typedef NS_ENUM(NSInteger, BubbleType) {
    SINGLE  = 0,
    FIRST   = 1,
    MIDDLE  = 2,
    LAST    = 3,
};

@interface MessageBubbleView: NSView
/*
 * Background color of the bubble
 */
@property NSColor* bgColor;
@property BubbleType type;
@property enum PointerDirection pointerDirection;
/*
 * Radius value for rounded corner. Default is 12
 */
@property CGFloat cornerRadius;

@end
