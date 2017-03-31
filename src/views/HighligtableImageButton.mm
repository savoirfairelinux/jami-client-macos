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

#import "HighligtableImageButton.h"
#import "NSColor+RingTheme.h"

@implementation HighligtableImageButton

-(void) awakeFromNib {
    if (!self.tintColor) {
        self.tintColor = [NSColor labelColor];
    }

    if (!self.highlightTintColor) {
        self.highlightTintColor = [NSColor shadowColor];
    }

    self.pressed = NO;
}

-(void) setPressed:(BOOL)newVal
{
    _pressed = newVal;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];

    NSColor* imageColor;

    if (self.mouseDown || self.isPressed) {
        imageColor = self.highlightTintColor;

    } else if (!self.isEnabled) {
        imageColor = [self.tintColor colorWithAlphaComponent:0.7];
    } else {
        imageColor = self.tintColor;
    }

    [[NSColor image:self.image tintedWithColor:imageColor] drawInRect:dirtyRect
                                                             fromRect:NSZeroRect
                                                            operation:NSCompositeSourceOver
                                                             fraction:1.0
                                                       respectFlipped:YES
                                                                hints:nil];
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
