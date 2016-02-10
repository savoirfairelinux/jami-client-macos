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

#import "IconButton.h"

#import "NSColor+RingTheme.h"

@implementation IconButton

-(void) awakeFromNib {
    if (!self.bgColor) {
        self.bgColor = [NSColor ringBlue];
    }

    if (!self.cornerRadius) {
        self.cornerRadius = @(NSWidth(self.frame) / 2);
    }

    if (self.imageInsets == 0)
        self.imageInsets = 8.0f;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];

    NSColor* backgroundColor;
    NSColor* backgroundStrokeColor;
    NSColor* tintColor = [NSColor whiteColor];

    if (self.mouseDown || self.isHighlighted) {
        if (self.highlightColor) {
            backgroundColor = self.highlightColor;
            backgroundStrokeColor = [self.highlightColor darkenColorByValue:0.1];
        } else {
            backgroundColor = [self.bgColor darkenColorByValue:0.3];
            backgroundStrokeColor = [self.bgColor darkenColorByValue:0.4];
        }
    } else if (!self.isEnabled) {
        backgroundColor = [self.bgColor colorWithAlphaComponent:0.7];
        backgroundStrokeColor = [self.bgColor colorWithAlphaComponent:0.7];
        tintColor = [[NSColor grayColor] colorWithAlphaComponent:0.3];
    } else {
        backgroundColor = self.bgColor;
        backgroundStrokeColor = [self.bgColor darkenColorByValue:0.1];
    }

    //// Subframes
    NSRect group = NSMakeRect(NSMinX(dirtyRect) + floor(NSWidth(dirtyRect) * 0.03333) + 0.5,
                              NSMinY(dirtyRect) + floor(NSHeight(dirtyRect) * 0.03333) + 0.5,
                              floor(NSWidth(dirtyRect) * 0.96667) - floor(NSWidth(dirtyRect) * 0.03333),
                              floor(NSHeight(dirtyRect) * 0.96667) - floor(NSHeight(dirtyRect) * 0.03333));

    //// Group
    {
        //// Oval Drawing
        NSBezierPath* ovalPath = [NSBezierPath bezierPathWithRoundedRect:
                                  NSMakeRect(NSMinX(group) + floor(NSWidth(group) * 0.00000 + 0.5),
                                             NSMinY(group) + floor(NSHeight(group) * 0.00000 + 0.5),
                                             floor(NSWidth(group) * 1.00000 + 0.5) - floor(NSWidth(group) * 0.00000 + 0.5),
                                             floor(NSHeight(group) * 1.00000 + 0.5) - floor(NSHeight(group) * 0.00000 + 0.5))
                                                                 xRadius:[self.cornerRadius floatValue] yRadius:[self.cornerRadius floatValue]];

        [backgroundColor setFill];
        [ovalPath fill];
        [backgroundStrokeColor setStroke];
        [ovalPath setLineWidth: 0.5];
        [ovalPath stroke];

        [NSGraphicsContext saveGraphicsState];

        NSBezierPath* path = [NSBezierPath bezierPathWithRect:dirtyRect];
        [path addClip];

        [self setImagePosition:NSImageOnly];
        auto rect = NSInsetRect(dirtyRect, self.imageInsets, self.imageInsets);

        [[NSColor image:self.image tintedWithColor:tintColor] drawInRect:rect
                 fromRect:NSZeroRect
                operation:NSCompositeSourceOver
                 fraction:1.0
           respectFlipped:YES
                    hints:nil];

        [NSGraphicsContext restoreGraphicsState];
    }
}

-(void)mouseDown:(NSEvent *)theEvent
{
    self.mouseDown = TRUE;
    [self setNeedsDisplay:YES];

    [super mouseDown:theEvent];

    self.mouseDown = FALSE;
    [self setNeedsDisplay:YES];
}

@end
