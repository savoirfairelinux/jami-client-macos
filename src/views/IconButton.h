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
 * default value : [NSColor clearColor]
 */
@property (nonatomic, strong) NSColor* bgColor;

/*
 * Background color of the button when highlighted
 * default value bgColor
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
 * default value : 8.0
 */
@property CGFloat imageInsets;

/*
 * Channging of image size when mouse is down
 * default value : 0.0
 */
@property CGFloat imageIncreaseOnClick;

/*
 * Button image color
 * default value : [NSColor ringDarkBlue];
 */

@property (nonatomic, strong) NSColor* imageColor;

/*
 * Image color when button is disabled
 * default value : [[NSColor grayColor] colorWithAlphaComponent:0.3];
 */

@property (nonatomic, strong) NSColor* buttonDisableColor;

/*
 * Color of the button corners. Draw circle with cornerRadius filled with bgColor
 * and fill corner with cornerColor
 */
@property (nonatomic, strong) NSColor* cornerColor;
/*
 * Font size of the button title.
 */
@property CGFloat fontSize;

-(void)startBlinkAnimationfrom:(NSColor*)startColor
                            to:(NSColor*)endColor
                   scaleFactor:(CGFloat)scaleFactor
                      duration:(CGFloat) duration;

-(void)stopBlinkAnimation;

@property BOOL animating;
@property BOOL isDarkMode;

/*
 * Button image color when in dark mode
 * default value : [NSColor whiteColor];
 */

@property (nonatomic, strong) NSColor* imageDarkColor;

/*
 * Button image color
 * default value : [NSColor ringDarkBlue];
 */

@property (nonatomic, strong) NSColor* imageLightColor;

/*
 * Button highlight color when in dark mode
 * default value : highlightColor;
 */

@property (nonatomic, strong) NSColor* highlightDarkColor;

/*
 * Button highlight color when in light mode
 * default value : highlightColor;
 */

@property (nonatomic, strong) NSColor* highlightLightColor;

/*
 * Define if should draw boreder
 * default value false;
 */
@property (atomic) BOOL shouldDrawBorder;

/*
 * Image coler when button pressed
 * default value : imageColor;
 */

@property (nonatomic, strong) NSColor* imagePressedColor;

/*
 * Image coler when button pressed in dark mode
 * default value : imagePressedColor;
 */

@property (nonatomic, strong) NSColor* imagePressedDarkColor;

/*
 * Image coler when button pressed in light mode
 * default value : imagePressedColor;
 */

@property (nonatomic, strong) NSColor* imagePressedLightColor;

-(void) onAppearanceChanged;

@end
