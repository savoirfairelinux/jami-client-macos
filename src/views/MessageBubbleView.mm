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

#import "MessageBubbleView.h"
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>
#import "NSColor+RingTheme.h"

@implementation MessageBubbleView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    CGContextRef context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGFloat radius = 6;
    CGFloat minx = CGRectGetMinX(dirtyRect), midx = CGRectGetMidX(dirtyRect), maxx = CGRectGetMaxX(dirtyRect);
    CGFloat miny = CGRectGetMinY(dirtyRect), midy = CGRectGetMidY(dirtyRect), maxy = CGRectGetMaxY(dirtyRect);

    CGMutablePathRef outlinePath = CGPathCreateMutable();

    if (self.pointerDirection == LEFT)
    {
        minx += 6;
        CGPathMoveToPoint(outlinePath, nil, midx, miny);
        CGPathAddArcToPoint(outlinePath, nil, maxx, miny, maxx, midy, radius);
        CGPathAddArcToPoint(outlinePath, nil, maxx, maxy, midx, maxy, radius);
        CGPathAddArcToPoint(outlinePath, nil, minx, maxy, minx, midy, radius);
        if(self.needPointer) {
            CGPathAddLineToPoint(outlinePath, nil, minx, maxy - 20);
            CGPathAddLineToPoint(outlinePath, nil, minx - 6, maxy - 15);
            CGPathAddLineToPoint(outlinePath, nil, minx, maxy - 10);
        }

        CGPathAddArcToPoint(outlinePath, nil, minx, miny, midx, miny, radius);
        CGPathCloseSubpath(outlinePath);
    }
    else
    {
        maxx-=6;
        CGPathMoveToPoint(outlinePath, nil, midx, miny);
        CGPathAddArcToPoint(outlinePath, nil, minx, miny, minx, midy, radius);
        CGPathAddArcToPoint(outlinePath, nil, minx, maxy, midx, maxy, radius);
        CGPathAddArcToPoint(outlinePath, nil, maxx, maxy, maxx, midy, radius);
        if(self.needPointer) {
            CGPathAddLineToPoint(outlinePath, nil, maxx, maxy - 20);
            CGPathAddLineToPoint(outlinePath, nil, maxx + 6, maxy - 15);
            CGPathAddLineToPoint(outlinePath, nil, maxx, maxy - 10);
        }
        CGPathAddArcToPoint(outlinePath, nil, maxx, miny, midx, miny, radius);
        CGPathCloseSubpath(outlinePath);
    }
    CGContextSetShadowWithColor(context, CGSizeMake(0,1), 1, [NSColor lightGrayColor].CGColor);
    CGContextAddPath(context, outlinePath);
    CGContextFillPath(context);

    CGContextAddPath(context, outlinePath);
    CGContextClip(context);
    if(self.bgColor) {
        CGContextSetFillColorWithColor(context, self.bgColor.CGColor);
        CGContextStrokePath(context);
        NSRectFill(dirtyRect);
    }
}
@end
