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

#import "HoverButton.h"
#import "NSColor+RingTheme.h"

@implementation HoverButton
-(void) awakeFromNib {
    [super awakeFromNib];
    [self updateParameters];
}

-(instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame: frameRect];
    [self updateParameters];
    return self;
}

-(void)updateParameters {
    if(!self.imageHoverLightColor) {
        self.imageHoverLightColor = self.imageHoverColor ? self.imageHoverColor :  self.imageLightColor;
    }
    if(!self.imageHoverDarkColor) {
        self.imageHoverDarkColor = self.imageHoverColor ? self.imageHoverColor :  self.imageDarkColor;
    }
    self.imageHoverColor = self.isDarkMode ? self.imageHoverDarkColor : self.imageHoverLightColor;
 
    if(!self.hoverLightColor) {
        self.hoverLightColor = self.hoverColor ? self.hoverColor :  self.bgColor;
    }
    if(!self.hoverDarkColor) {
        self.hoverDarkColor = self.bgColor;
    }
    self.hoverColor = self.isDarkMode ? self.hoverDarkColor : self.hoverLightColor;
    if(!self.mouseOutsideLightColor) {
        self.mouseOutsideLightColor = self.mouseOutsideColor ? self.mouseOutsideColor : self.bgColor;
    }
    if(!self.mouseOutsideDarkColor) {
        self.mouseOutsideDarkColor = self.bgColor;
    }
    self.mouseOutsideColor = self.isDarkMode ? self.mouseOutsideDarkColor : self.mouseOutsideLightColor;
    if(self.moiuseOutsideImageLightColor) {
        self.moiuseOutsideImageLightColor = self.moiuseOutsideImageColor ? self.moiuseOutsideImageColor : self.imageLightColor;
    }
    if(!self.moiuseOutsideImageDarkColor) {
        self.moiuseOutsideImageDarkColor = self.moiuseOutsideImageColor ? self.moiuseOutsideImageColor : self.imageDarkColor;
    }
    self.moiuseOutsideImageColor = self.isDarkMode ? self.moiuseOutsideImageDarkColor : self.moiuseOutsideImageLightColor;
}

-(void)mouseEntered:(NSEvent *)theEvent {
    if (self.animating) {
        [self stopBlinkAnimation];
        self.animating = true;
    }
    if(self.isEnabled) {
        self.bgColor = self.hoverColor;
    }
    if(self.imageHoverColor) {
        self.imageColor = self.imageHoverColor;
    }
    if (self.imageIncreaseOnHover && self.enabled) {
        self.imageInsets -= self.imageIncreaseOnHover;
    }
    if (self.textIncreaseOnHover && self.enabled && self.fontSize) {
        self.fontSize += self.textIncreaseOnHover;
    }
    [super setNeedsDisplay:YES];
    [super mouseEntered:theEvent];
}

-(void)mouseExited:(NSEvent *)theEvent {
    self.bgColor = self.mouseOutsideColor;
    if (self.animating) {
        [self startBlinkAnimationfrom:[NSColor buttonBlinkColorColor] to:[NSColor whiteColor] scaleFactor: 1.0 duration: 1.5];
    }
    if(self.imagePressedColor && self.pressed) {
        self.imageColor = self.imagePressedColor;
    } else if ( self.moiuseOutsideImageColor) {
        self.imageColor = self.moiuseOutsideImageColor;
    }
    if (self.imageIncreaseOnHover && self.enabled) {
        self.imageInsets += self.imageIncreaseOnHover;
    }
    if (self.textIncreaseOnHover && self.enabled && self.fontSize) {
        self.fontSize -= self.textIncreaseOnHover;
    }
    [super setNeedsDisplay:YES];
    [super mouseExited:theEvent];
}

- (void)ensureTrackingArea {
    if (trackingArea == nil) {
        trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect
                                                    options:NSTrackingInVisibleRect
                        | NSTrackingActiveAlways
                        | NSTrackingMouseEnteredAndExited owner:self userInfo:nil];
    }
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    [self ensureTrackingArea];
    if (![[self trackingAreas] containsObject:trackingArea]) {
        [self addTrackingArea:trackingArea];
    }
}

-(void) onAppearanceChanged {
    [super onAppearanceChanged];
    self.imageHoverColor = self.isDarkMode ? self.imageHoverDarkColor : self.imageHoverLightColor;
    self.hoverColor = self.isDarkMode ? self.hoverDarkColor : self.hoverLightColor;
    self.mouseOutsideColor = self.isDarkMode ? self.mouseOutsideDarkColor : self.mouseOutsideLightColor;
    self.moiuseOutsideImageColor = self.isDarkMode ? self.moiuseOutsideImageDarkColor : self.moiuseOutsideImageLightColor;
}

@end
