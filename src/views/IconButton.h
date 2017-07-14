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

@interface IconButton : NSButton

@property (nonatomic) BOOL mouseDown;

/*
 * This properties can be overriden in IB in User Defined Runtime Attributes
 * By default this values will be initialized in awakeFromNib
 */

/*
 * Background color of the button
 * default value : [NSColor ringBlue]
 */
@property (nonatomic, strong) NSColor* bgColor;

/*
 * Background color of the button when highlighted
 * default value : view frame width / 2 (circle)
 */
@property (nonatomic, strong) NSColor* highlightColor;

/*
 * Background color of the button when highlighted
 * default value : view frame width / 2 (circle)
 */
@property (nonatomic, strong) NSNumber* cornerRadius;

/*
 * Define pressed state of the button
 */
@property (atomic, getter=isPressed) BOOL pressed;

/*
 * Padding
 * default value : 5.0
 */
@property CGFloat imageInsets;

/*
 * Add bluer effect behind button
 */

@property NSVisualEffectView* vibrantView;

/*
 * Button image color
 * default value : [NSColor white];
 */

@property (nonatomic, strong) NSColor* imageColor;


@end
