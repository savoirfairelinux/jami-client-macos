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

#import "RingIDField.h"

@interface RingIDField() {
    NSSize m_previousIntrinsicContentSize;
}

@end

@implementation RingIDField

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];

    NSPoint origin = { 0.0,0.0 };
    NSRect rect;
    rect.origin = origin;
    rect.size.width  = [self bounds].size.width;
    rect.size.height = [self bounds].size.height;

    NSBezierPath * path;
    path = [NSBezierPath bezierPathWithRect:rect];
    [path setLineWidth:3];
    [[NSColor colorWithCalibratedRed:0.337 green:0.69 blue:0.788 alpha:1.0] set];
    [path stroke];

}

@end
