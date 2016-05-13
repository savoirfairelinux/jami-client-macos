/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
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

#import "ScreenGrabView.h"
#import <QuartzCore/QuartzCore.h>

@interface ScreenGrabView () {
    NSRect _selectionRect;
    NSPoint _startPoint;
}

@property (nonatomic, strong) CAShapeLayer* shapeLayer;

@end

@implementation ScreenGrabView

#pragma mark Mouse Events

- (void)mouseDown:(NSEvent *)theEvent
{
    _startPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    NSPoint curPoint = [theEvent locationInWindow];
    NSRect previousSelectionRect = _selectionRect;
    _selectionRect = NSMakeRect(
                                MIN(_startPoint.x, curPoint.x),
                                MIN(_startPoint.y, curPoint.y),
                                MAX(_startPoint.x, curPoint.x) - MIN(_startPoint.x, curPoint.x),
                                MAX(_startPoint.y, curPoint.y) - MIN(_startPoint.y, curPoint.y));
    [self setNeedsDisplayInRect:NSUnionRect(_selectionRect, previousSelectionRect)];
}

- (void)mouseUp:(NSEvent *)theEvent
{
    NSPoint mouseUpPoint = [theEvent locationInWindow];
    NSRect selectionRect = NSMakeRect(
                                      MIN(_startPoint.x, mouseUpPoint.x),
                                      MIN(_startPoint.y, mouseUpPoint.y),
                                      MAX(_startPoint.x, mouseUpPoint.x) - MIN(_startPoint.x, mouseUpPoint.x),
                                      MAX(_startPoint.y, mouseUpPoint.y) - MIN(_startPoint.y, mouseUpPoint.y));
    if (self.delegate != nil) {
        [self.delegate grabber:self didSelectRect:selectionRect];
    }
}

- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor blackColor] set];
    NSRectFill(dirtyRect);
    [[NSColor whiteColor] set];
    NSFrameRect(_selectionRect);
}

@end
