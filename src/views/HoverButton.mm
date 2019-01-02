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
    if(!self.hoverColor) {
        self.hoverColor = [NSColor ringBlue];
    }
    if(!self.mouseOutsideColor) {
        self.mouseOutsideColor = [NSColor clearColor];
    }
    self.bgColor = self.mouseOutsideColor;
}

-(instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame: frameRect];
    if(!self.hoverColor) {
        self.hoverColor = [NSColor ringBlue];
    }
    if(!self.mouseOutsideColor) {
        self.mouseOutsideColor = [NSColor clearColor];
    }
    self.bgColor = self.mouseOutsideColor;
    return self;
}

-(void)mouseEntered:(NSEvent *)theEvent {
    if(self.isEnabled) {
        self.bgColor = self.hoverColor;
    }
    [super setNeedsDisplay:YES];
    [super mouseEntered:theEvent];
}

-(void)mouseExited:(NSEvent *)theEvent {
    self.bgColor = self.mouseOutsideColor;
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

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
}


@end
