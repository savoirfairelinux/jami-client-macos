/*
*  Copyright (C) 2021 Savoir-faire Linux Inc.
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

#import "NSColor+RingTheme.h"
#import "CustomBackgroundView.h"

#import <QuartzCore/QuartzCore.h>

@implementation CustomBackgroundView


- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    NSColor *backgroundColor = self.backgroundColor ? self.backgroundColor : [NSColor colorWithCalibratedRed: 0 green: 0 blue: 0 alpha: 0.8];
    NSColor *backgroundStrokeColor = [NSColor clearColor];
    NSColor *tintColor = self.imageColor ? self.imageColor : [NSColor whiteColor];
    
    NSBezierPath* path;
    
    switch (self.backgroundType) {
        case RECTANGLE: {
            path = [NSBezierPath bezierPathWithRoundedRect:dirtyRect xRadius:0 yRadius:0];
            break;
        }
        case RECTANGLE_WITH_ROUNDED_RIGHT_CORNER: {
            path = [[NSBezierPath alloc] init];
            NSPoint bottomLeft = dirtyRect.origin;
            NSPoint topLeft = CGPointMake(dirtyRect.origin.x, dirtyRect.size.height);
            NSPoint topRight = CGPointMake(dirtyRect.size.width, dirtyRect.size.height);
            NSPoint bottomRight = CGPointMake(dirtyRect.size.width * 0.5, dirtyRect.origin.y);
            NSPoint middle = CGPointMake(dirtyRect.size.width, dirtyRect.size.height * 0.5);
            NSPoint controlPoint1 = CGPointMake(dirtyRect.size.width * 0.96, dirtyRect.size.height * 0.1);
            NSPoint controlPoint2 = CGPointMake(dirtyRect.size.width * 0.99, dirtyRect.size.height * 0.4);
            [path setLineWidth:1.0];
            [path moveToPoint:topLeft];
            [path lineToPoint:bottomLeft];
            
            [path lineToPoint:bottomRight];
            [path curveToPoint:middle controlPoint1:controlPoint1 controlPoint2:controlPoint2];
            [path lineToPoint:topRight];
            [path closePath];
            break;
        }
        case CUSP: {
            path = [[NSBezierPath alloc] init];
            NSPoint bottomLeft = CGPointMake(dirtyRect.origin.x, dirtyRect.size.height * 0.5);
            NSPoint topLeft = CGPointMake(dirtyRect.origin.x, dirtyRect.size.height);
            NSPoint topRight = CGPointMake(dirtyRect.size.width, dirtyRect.size.height);
            NSPoint controlPoint1 = CGPointMake(dirtyRect.size.width * 0.1, dirtyRect.size.height * 0.6);
            NSPoint controlPoint2 = CGPointMake(dirtyRect.size.width * 0.01, dirtyRect.size.height * 0.9);
            [path setLineWidth:1.0];
            [path moveToPoint:topLeft];
            [path lineToPoint:bottomLeft];
            
            [path curveToPoint:topRight controlPoint1:controlPoint1 controlPoint2:controlPoint2];
            [path closePath];
            break;
        }
    }
    
    [backgroundColor set];
    [path fill];
    [[NSColor clearColor] set];
    [path stroke];
    
    if (self.backgroundType == CUSP) {
        return;
    }
    
    NSRect rectImage = NSInsetRect(dirtyRect, 4, 4);
    rectImage.size.width = rectImage.size.height;
    
    [[NSColor image: self.image tintedWithColor:tintColor] drawInRect:rectImage
                                                       fromRect:NSZeroRect
                                                      operation:NSCompositeSourceOver
                                                       fraction:1.0
                                                 respectFlipped:YES
                                                          hints:nil];
}

@end
