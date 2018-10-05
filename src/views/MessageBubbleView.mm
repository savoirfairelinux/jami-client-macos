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
    CGContextSetRGBFillColor(context, 1, 1, 1, 0);
    CGFloat defaultRadius = 16;
    CGFloat radius = (self.cornerRadius) ? self.cornerRadius : defaultRadius;
    CGFloat minx = CGRectGetMinX(dirtyRect);
    CGFloat midx = CGRectGetMidX(dirtyRect);
    CGFloat maxx = CGRectGetMaxX(dirtyRect);
    CGFloat miny = CGRectGetMinY(dirtyRect);
    CGFloat midy = CGRectGetMidY(dirtyRect);
    CGFloat maxy = CGRectGetMaxY(dirtyRect);

    CGMutablePathRef outlinePath = CGPathCreateMutable();
    if (self.pointerDirection == LEFT)
    {
        switch (self.type) {
                case SINGLE:
                CGPathMoveToPoint(outlinePath, nil, midx, miny);
                CGPathAddArcToPoint(outlinePath, nil, maxx, miny, maxx, midy, radius);
                CGPathAddArcToPoint(outlinePath, nil, maxx, maxy, midx, maxy, radius);
                CGPathAddArcToPoint(outlinePath, nil, minx, maxy, minx, midy, radius);
                CGPathAddArcToPoint(outlinePath, nil, minx, miny, midx, miny, radius);
                break;
                case FIRST:
                CGPathMoveToPoint(outlinePath, nil, midx, miny);
                CGPathAddArcToPoint(outlinePath, nil, maxx, miny, maxx, midy, radius);
                CGPathAddArcToPoint(outlinePath, nil, maxx, maxy, midx, maxy, radius);
                CGPathAddArcToPoint(outlinePath, nil, minx, maxy, minx, midy, radius);
                CGPathAddArcToPoint(outlinePath, nil, minx, miny, midx, miny, 0);
                break;
                case MIDDLE:
                CGPathMoveToPoint(outlinePath, nil, midx, miny);
                CGPathAddArcToPoint(outlinePath, nil, maxx, miny, maxx, midy, radius);
                CGPathAddArcToPoint(outlinePath, nil, maxx, maxy, midx, maxy, radius);
                CGPathAddArcToPoint(outlinePath, nil, minx, maxy, minx, midy, 0);
                CGPathAddArcToPoint(outlinePath, nil, minx, miny, midx, miny, 0);
                break;
                case LAST:
                CGPathMoveToPoint(outlinePath, nil, midx, miny);
                CGPathAddArcToPoint(outlinePath, nil, maxx, miny, maxx, midy, radius);
                CGPathAddArcToPoint(outlinePath, nil, maxx, maxy, midx, maxy, radius);
                CGPathAddArcToPoint(outlinePath, nil, minx, maxy, minx, midy, 0);
                CGPathAddArcToPoint(outlinePath, nil, minx, miny, midx, miny, radius);
                break;
        }
    } else {
        switch (self.type) {
                case SINGLE:
                CGPathMoveToPoint(outlinePath, nil, midx, miny);
                CGPathAddArcToPoint(outlinePath, nil, maxx, miny, maxx, midy, radius);
                CGPathAddArcToPoint(outlinePath, nil, maxx, maxy, midx, maxy, radius);
                CGPathAddArcToPoint(outlinePath, nil, minx, maxy, minx, midy, radius);
                CGPathAddArcToPoint(outlinePath, nil, minx, miny, midx, miny, radius);
                break;
                case FIRST:
                CGPathMoveToPoint(outlinePath, nil, midx, miny);
                CGPathAddArcToPoint(outlinePath, nil, maxx, miny, maxx, midy, 0);
                CGPathAddArcToPoint(outlinePath, nil, maxx, maxy, midx, maxy, radius);
                CGPathAddArcToPoint(outlinePath, nil, minx, maxy, minx, midy, radius);
                CGPathAddArcToPoint(outlinePath, nil, minx, miny, midx, miny, radius);
                break;
                case MIDDLE:
                CGPathMoveToPoint(outlinePath, nil, midx, miny);
                CGPathAddArcToPoint(outlinePath, nil, maxx, miny, maxx, midy, 0);
                CGPathAddArcToPoint(outlinePath, nil, maxx, maxy, midx, maxy, 0);
                CGPathAddArcToPoint(outlinePath, nil, minx, maxy, minx, midy, radius);
                CGPathAddArcToPoint(outlinePath, nil, minx, miny, midx, miny, radius);
                break;
                case LAST:
                CGPathMoveToPoint(outlinePath, nil, midx, miny);
                CGPathAddArcToPoint(outlinePath, nil, maxx, miny, maxx, midy, radius);
                CGPathAddArcToPoint(outlinePath, nil, maxx, maxy, midx, maxy, 0);
                CGPathAddArcToPoint(outlinePath, nil, minx, maxy, minx, midy, radius);
                CGPathAddArcToPoint(outlinePath, nil, minx, miny, midx, miny, radius);
                break;
        }
    }
    CGPathCloseSubpath(outlinePath);
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
