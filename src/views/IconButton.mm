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

@interface IconButton()
@property (nonatomic, strong) NSTrackingArea *trackingArea;
@end

@implementation IconButton
@synthesize trackingArea;

-(void) awakeFromNib {
    if (!self.bgColor) {
        self.bgColor = [NSColor ringBlue];
    }

    if (!self.cornerRadius) {
        self.cornerRadius = @(NSWidth(self.frame) / 2);
    }

    if (self.imageInsets == 0)
        self.imageInsets = 8.0f;

    self.pressed = NO;

}

-(instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame: frameRect];
    if (!self.bgColor) {
        self.bgColor = [NSColor ringBlue];
    }

    if (!self.cornerRadius) {
        self.cornerRadius = @(NSWidth(self.frame) / 2);
    }

    if (self.imageInsets == 0)
        self.imageInsets = 8.0f;

    self.pressed = NO;
    return self;
}

-(void) setPressed:(BOOL)newVal
{
    _pressed = newVal;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];

    NSColor* backgroundColor;
    NSColor* backgroundStrokeColor;
    NSColor* tintColor = self.imageColor ? self.imageColor : [NSColor whiteColor];

    if (self.bgColor == [NSColor clearColor]) {
        backgroundColor = self.bgColor ;
        backgroundStrokeColor = self.bgColor;
        if(!self.isEnabled) {
            if (self.buttonDisableColor) {
                tintColor = self.buttonDisableColor;
            } else {
                tintColor = [[NSColor grayColor] colorWithAlphaComponent:0.3];
            }
        }
    }
    else if (!self.isEnabled) {
        backgroundColor = [self.bgColor colorWithAlphaComponent:0.7];
        backgroundStrokeColor = [self.bgColor colorWithAlphaComponent:0.7];
        if (self.buttonDisableColor) {
            tintColor = self.buttonDisableColor;
        } else {
            tintColor = [[NSColor grayColor] colorWithAlphaComponent:0.3];
        }
    } else if (self.mouseDown || self.isPressed) {
        if (self.highlightColor) {
            backgroundColor = self.highlightColor;
            backgroundStrokeColor = [self.highlightColor darkenColorByValue:0.1];
        } else {
            backgroundColor = [self.bgColor darkenColorByValue:0.3];
            backgroundStrokeColor = [self.bgColor darkenColorByValue:0.4];
        }
    }

    else {
        backgroundColor = self.bgColor;
        backgroundStrokeColor = [self.bgColor darkenColorByValue:0.1];
    }

    backgroundStrokeColor = NSColor.clearColor;

    //// Subframes
    NSRect group = NSMakeRect(NSMinX(dirtyRect) + floor(NSWidth(dirtyRect) * 0.03333) + 0.5,
                              NSMinY(dirtyRect) + floor(NSHeight(dirtyRect) * 0.03333) + 0.5,
                              floor(NSWidth(dirtyRect) * 0.96667) - floor(NSWidth(dirtyRect) * 0.03333),
                              floor(NSHeight(dirtyRect) * 0.96667) - floor(NSHeight(dirtyRect) * 0.03333));

    //// Group
    {
        //// Oval Drawing
        NSBezierPath* ovalPath = [NSBezierPath bezierPathWithRoundedRect:dirtyRect
                                                                 xRadius:[self.cornerRadius floatValue]
                                                                 yRadius:[self.cornerRadius floatValue]];
        if(self.cornerColor) {
            NSRect frame = [self frame];

            [backgroundColor setFill];
            [ovalPath fill];
           // [NSGraphicsContext saveGraphicsState];

            CGPoint top = CGPointMake(frame.size.width * 0.5, 0);
            CGPoint right = CGPointMake(frame.size.width, frame.size.height * 0.5);
            CGPoint bottom = CGPointMake(frame.size.width * 0.5, frame.size.height);
            CGPoint left = CGPointMake(0, frame.size.height * 0.5);
            CGPoint topLeft = CGPointMake(0, 0);
            CGPoint topRight = CGPointMake(frame.size.width, 0);
            CGPoint bottomLeft = CGPointMake(0, frame.size.height);
            CGPoint bottomRight = CGPointMake(frame.size.width, frame.size.height);

            NSBezierPath* topLeftPath = [[NSBezierPath alloc] init];
            NSPoint pointArrayLeft[3];
            pointArrayLeft[0] = left;
            pointArrayLeft[1] = topLeft;
            pointArrayLeft[2] = top;

            [topLeftPath appendBezierPathWithPoints:pointArrayLeft count:3];
            [topLeftPath appendBezierPathWithArcFromPoint: topLeft toPoint: left radius: 20.0f];
            [self.cornerColor setFill];
            [topLeftPath fill];

            NSBezierPath* topRightPath = [[NSBezierPath alloc] init];
            NSPoint pointArrayTop[3];
            pointArrayTop[0] = top;
            pointArrayTop[1] = topRight;
            pointArrayTop[2] = right;
            [topRightPath appendBezierPathWithPoints:pointArrayTop count:3];
            [topRightPath appendBezierPathWithArcFromPoint: topRight toPoint: top radius: 20.0f];
            [topRightPath fill];

            NSBezierPath* bottomLeftPath = [[NSBezierPath alloc] init];
            NSPoint pointArrayRight[3];
            pointArrayRight[0] = right;
            pointArrayRight[1] = bottomRight;
            pointArrayRight[2] = bottom;
            [bottomLeftPath appendBezierPathWithPoints:pointArrayRight count:3];
            [bottomLeftPath appendBezierPathWithArcFromPoint: bottomRight toPoint: right radius: 20.0f];
            [bottomLeftPath fill];

            NSBezierPath* bottomRightPath = [[NSBezierPath alloc] init];
            NSPoint pointArrayBottom[3];
            pointArrayBottom[0] = bottom;
            pointArrayBottom[1] = bottomLeft;
            pointArrayBottom[2] = left;
            [bottomRightPath appendBezierPathWithPoints:pointArrayBottom count:3];
            [bottomRightPath appendBezierPathWithArcFromPoint: bottomLeft toPoint: bottom radius: 20.0f];
            [bottomRightPath fill];
            [NSGraphicsContext saveGraphicsState];
            return;
        }

        [backgroundColor setFill];
        [ovalPath fill];
        [backgroundStrokeColor setStroke];
        [ovalPath setLineWidth: 0.5];
        [ovalPath stroke];

        [NSGraphicsContext saveGraphicsState];

        NSBezierPath* path = [NSBezierPath bezierPathWithRect:dirtyRect];
        [path addClip];

        [self setImagePosition:NSImageOverlaps];
        auto rect = NSInsetRect(dirtyRect, self.imageInsets, self.imageInsets);

        [[NSColor image:self.image tintedWithColor:tintColor] drawInRect:rect
                 fromRect:NSZeroRect
                operation:NSCompositeSourceOver
                 fraction:1.0
           respectFlipped:YES
                    hints:nil];

        [NSGraphicsContext restoreGraphicsState];

        NSRect rect2;
        NSDictionary *att = nil;

        NSMutableParagraphStyle *style =
        [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [style setLineBreakMode:NSLineBreakByWordWrapping];
        [style setAlignment:NSCenterTextAlignment];
        att = [[NSDictionary alloc] initWithObjectsAndKeys:
               style, NSParagraphStyleAttributeName,
               [NSColor whiteColor],
               NSForegroundColorAttributeName, nil];

        rect.size = [[self title] sizeWithAttributes:att];
        rect.origin.x = floor( NSMidX([self bounds]) - rect.size.width / 2 );
        rect.origin.y = floor( NSMidY([self bounds]) - rect.size.height / 2 );
        [[self title] drawInRect:rect withAttributes:att];
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
