/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
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

#import "MovableView.h"
#import <QuartzCore/QuartzCore.h>

@implementation MovableView

NSPoint firstMouseDownPoint = NSZeroPoint;
NSInteger const MARGIN = 20;

@synthesize movable;

-(void)mouseDown:(NSEvent *)event
{
    if (!movable) {
        return;
    }
    firstMouseDownPoint = [self.hostingView convertPoint:event.locationInWindow toView:self];
}

-(void)mouseDragged:(NSEvent *)event
{
    if (!movable) {
        return;
    }
    NSPoint newPoint = [self.hostingView convertPoint:event.locationInWindow toView:self];
    NSPoint offset = CGPointMake(newPoint.x - firstMouseDownPoint.x,newPoint.y - firstMouseDownPoint.y);
    NSPoint origin = self.frame.origin;
    NSSize size = self.frame.size;
    NSPoint newOrigin= CGPointMake(origin.x + offset.x, origin.y + offset.y);
    NSPoint newMax= CGPointMake(newOrigin.x + self.frame.size.width, newOrigin.y + self.frame.size.height);
    if(!CGRectContainsPoint(CGRectInset([self.hostingView frame], MARGIN, MARGIN), newOrigin)
       || !CGRectContainsPoint(CGRectInset([self.hostingView frame], MARGIN, MARGIN), newMax)) {
        if (newOrigin.x < self.minX) {
            newOrigin.x = self.minX;
        }
        if (newOrigin.x > self.maxX) {
            newOrigin.x = self.maxX;
        }
        if (newOrigin.y < self.minY) {
            newOrigin.y = self.minY;
        }
        if (newOrigin.y > self.maxY) {
            newOrigin.y = self.maxY;
        }
    }
    self.frame = CGRectMake(newOrigin.x, newOrigin.y, size.width, size.height);
}

- (void)viewDidMoveToWindow {
    [self.window setAcceptsMouseMovedEvents:YES];

    NSTrackingAreaOptions options = (NSTrackingActiveAlways | NSTrackingInVisibleRect | NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved);

    NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:self.frame
                                                        options:options
                                                          owner:self
                                                       userInfo:nil];

    [self addTrackingArea:area];
}

- (void)mouseEntered:(NSEvent *)event {
    if (!movable) {
        return;
    }
    auto currentOrigin = self.frame.origin;
    auto currentSize = self.frame.size;
    CGPoint newOrigin;
    CGFloat margin = 4;
    switch (self.closestCorner) {
        case TOP_LEFT:
            newOrigin = CGPointMake(currentOrigin.x + margin, currentOrigin.y - margin);
            break;
        case BOTTOM_LEFT:
            newOrigin = CGPointMake(currentOrigin.x + margin, currentOrigin.y + margin);
            break;
        case TOP_RIGHT:
            newOrigin = CGPointMake(currentOrigin.x - margin, currentOrigin.y - margin);
            break;
        case BOTTOM_RIGHT:
            newOrigin = CGPointMake(currentOrigin.x - margin, currentOrigin.y + margin);
            break;
    }
    auto currentFrame = self.frame;
    auto newFrame = currentFrame;
    newFrame.origin = newOrigin;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
        context.duration = 0.1f;
        context.timingFunction = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseOut];
        self.animator.frame = newFrame;
    } completionHandler: nil];
}

- (void)mouseExited:(NSEvent *)event {
    [self moveToCornerWithDuration:0.1];
}

- (void)mouseUp:(NSEvent *)event {
    [self moveToCornerWithDuration:0.3];
}

-(void) moveToCornerWithDuration:(CGFloat) duration {
    if (!movable) {
        return;
    }
    NSRect frame = self.frame;
    CGPoint currentOrigin = frame.origin;
    auto closestCorner = self.closestCorner;
    frame.origin = [self pointForCorner: self.closestCorner];
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
        context.duration = duration;
        context.timingFunction = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseOut];
        self.animator.frame = frame;
    } completionHandler:nil];
}

- (CGFloat) maxY {
    return self.hostingView.frame.size.height - self.frame.size.height - MARGIN;
}

- (CGFloat) maxX {
    return self.hostingView.frame.size.width - self.frame.size.width - MARGIN;
}

- (CGFloat) minX {
    return MARGIN;
}

- (CGFloat) minY {
    return MARGIN;
}

- (ViewCorner) closestCorner {
    NSPoint origin = self.frame.origin;
    BOOL isLeft = origin.x < self.maxX * 0.5;
    BOOL isTop = origin.y > self.maxY * 0.5;
    if (isLeft) {
        if (isTop) {
            return TOP_LEFT;
        }
        return BOTTOM_LEFT;
    }
    if (isTop) {
        return TOP_RIGHT;
    }
    return BOTTOM_RIGHT;
}

- (CGPoint) pointForCorner:(NSInteger) corner {
    switch (corner) {
        case TOP_LEFT:
            return CGPointMake(self.minX, self.maxY);
        case BOTTOM_LEFT:
            return CGPointMake(self.minX, self.minY);
        case TOP_RIGHT: {
            auto max = self.maxY;
            return CGPointMake(self.maxX, self.maxY);
        }
        case BOTTOM_RIGHT:
            return CGPointMake(self.maxX, self.minY);
    }
}

@end
