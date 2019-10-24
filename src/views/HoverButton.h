/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
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
 * default value : [NSColor clearColor]
 */
@property (nonatomic, strong) NSColor* hoverColor;

/*
 * image color of the button when mouse inside
 */
@property (nonatomic, strong) NSColor* imageHoverColor;

/*
 * Image color of the button when mouse inside
 */
@property (nonatomic, strong) NSColor* moiuseOutsideImageColor;

/*
 * Background color of the button when mouse outside
 * default value : [NSColor clearColor];
 */
@property (nonatomic, strong) NSColor* mouseOutsideColor;

/*
 * Value to increase image size when mouse entered
 */

@property CGFloat imageIncreaseOnHover;

/*
 * Background color of the button when mouse inside in light mode
 * default value : [NSColor clearColor]
 */
@property (nonatomic, strong) NSColor* hoverLightColor;

/*
 * image color of the button when mouse inside in light mode
 */
@property (nonatomic, strong) NSColor* imageHoverLightColor;

/*
 * Image color of the button when mouse inside in light mode
 */
@property (nonatomic, strong) NSColor* moiuseOutsideImageLightColor;

/*
 * Background color of the button when mouse outside in light mode
 * default value : [NSColor clearColor];
 */
@property (nonatomic, strong) NSColor* mouseOutsideLightColor;

/*
 * Background color of the button when mouse inside in dark mode
 * default value : [NSColor clearColor]
 */
@property (nonatomic, strong) NSColor* hoverDarkColor;

/*
 * image color of the button when mouse inside in dark mode
 */
@property (nonatomic, strong) NSColor* imageHoverDarkColor;

/*
 * Image color of the button when mouse inside in dark mode
 */
@property (nonatomic, strong) NSColor* moiuseOutsideImageDarkColor;

/*
 * Background color of the button when mouse outside in dark mode
 * default value : [NSColor clearColor];
 */
@property (nonatomic, strong) NSColor* mouseOutsideDarkColor;

@end
