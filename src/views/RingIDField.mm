//
//  RingIDField.m
//  Ring
//
//  Created by Alexandre Lision on 2015-08-18.
//
//

#import "RingIDField.h"

@interface RingIDField() {
    NSSize m_previousIntrinsicContentSize;
}

@end

@implementation RingIDField

- (void)drawRect:(NSRect)dirtyRect
{
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

    if (([[self window] firstResponder] == [self currentEditor]) && [NSApp isActive])
    {
        [NSGraphicsContext saveGraphicsState];
        //NSSetFocusRingStyle(NSFocusRing);
        //[path fill];
        [NSGraphicsContext restoreGraphicsState];
    }
    else
    {
        [[self attributedStringValue] drawInRect:rect];
    }
}

- (void)mouseDown:(NSEvent *)theEvent {
    [super mouseDown:theEvent];

    // Only take effect for double clicks; remove to allow for single clicks
    if (theEvent.clickCount < 2) {
        return;
    }

    NSLog(@"DOUBLE CLIIIK");

}

@end
