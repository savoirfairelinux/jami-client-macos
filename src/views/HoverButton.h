/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
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
#import "IconButton.h"

@interface HoverButton : IconButton {
@private

    NSTrackingArea *trackingArea;
}
/*
 * Background color of the button when mouse inside
 * default value : [NSColor ringBlue]
 */
@property (nonatomic, strong) NSColor* hoverColor;

/*
 * Background color of the button when mouse outside
 * default value : [NSColor clearColor];
 */
@property (nonatomic, strong) NSColor* mouseOutsideColor;

@end
