
//  KBButton.m
//  KBButton
//
//  Created by Kyle Bock on 11/3/12.
//  Copyright (c) 2012 Kyle Bock. All rights reserved.
//

#import "IconButton.h"


@interface IconButton ()

@property (nonatomic, strong) NSTrackingArea *trackingArea;

@end

@implementation IconButton

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];

    [self drawCloseButtonWithFrame:dirtyRect];
}

- (void)drawCloseButtonWithFrame: (NSRect)frame
{
    NSColor* backgroundColor6;
    NSColor* backgroundStrokeColor5;

    if (self.mouseDown)
    {
        backgroundColor6 = [NSColor colorWithCalibratedRed:0.740 green:0.341 blue:0.326 alpha:1.000];
        backgroundStrokeColor5 = [NSColor colorWithCalibratedRed:0.643 green:0.278 blue:0.267 alpha:1.000];
    }
    else
    {
        backgroundColor6 = [NSColor colorWithCalibratedRed:0.99 green:0.38 blue:0.36 alpha:1];
        backgroundStrokeColor5 = [NSColor colorWithCalibratedRed: 0.875 green: 0.278 blue: 0.267 alpha: 1];
    }

    //// Subframes
    NSRect group = NSMakeRect(NSMinX(frame) + floor(NSWidth(frame) * 0.03333) + 0.5, NSMinY(frame) + floor(NSHeight(frame) * 0.03333) + 0.5, floor(NSWidth(frame) * 0.96667) - floor(NSWidth(frame) * 0.03333), floor(NSHeight(frame) * 0.96667) - floor(NSHeight(frame) * 0.03333));


    //// Group
    {
        //// Oval Drawing
        NSBezierPath* ovalPath = [NSBezierPath bezierPathWithOvalInRect: NSMakeRect(NSMinX(group) + floor(NSWidth(group) * 0.00000 + 0.5), NSMinY(group) + floor(NSHeight(group) * 0.00000 + 0.5), floor(NSWidth(group) * 1.00000 + 0.5) - floor(NSWidth(group) * 0.00000 + 0.5), floor(NSHeight(group) * 1.00000 + 0.5) - floor(NSHeight(group) * 0.00000 + 0.5))];
        [backgroundColor6 setFill];
        [ovalPath fill];
        [backgroundStrokeColor5 setStroke];
        [ovalPath setLineWidth: 0.5];
        [ovalPath stroke];

        if (self.mouseHovering)
        {
            //// Group 2
            {
                //// Bezier Drawing
                NSBezierPath* bezierPath = NSBezierPath.bezierPath;
                [bezierPath moveToPoint: NSMakePoint(NSMinX(group) + 0.25000 * NSWidth(group), NSMinY(group) + 0.78571 * NSHeight(group))];
                [bezierPath lineToPoint: NSMakePoint(NSMinX(group) + 0.73980 * NSWidth(group), NSMinY(group) + 0.22487 * NSHeight(group))];
                [NSColor.blackColor setStroke];
                [bezierPath setLineWidth: 0.5];
                [bezierPath stroke];


                //// Bezier 2 Drawing
                NSBezierPath* bezier2Path = NSBezierPath.bezierPath;
                [bezier2Path moveToPoint: NSMakePoint(NSMinX(group) + 0.75000 * NSWidth(group), NSMinY(group) + 0.78571 * NSHeight(group))];
                [bezier2Path lineToPoint: NSMakePoint(NSMinX(group) + 0.25000 * NSWidth(group), NSMinY(group) + 0.21429 * NSHeight(group))];
                [NSColor.blackColor setStroke];
                [bezier2Path setLineWidth: 0.5];
                [bezier2Path stroke];
            }
        }
    }
}

- (void)mouseEntered:(NSEvent *)theEvent
{
    self.mouseHovering = TRUE;
    [self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent *)theEvent
{
    self.mouseHovering = FALSE;
    [self setNeedsDisplay:YES];
}

- (void)updateTrackingAreas
{
    [super updateTrackingAreas];

    if (self.trackingArea)
    {
        [self removeTrackingArea:self.trackingArea];
    }

    NSTrackingAreaOptions options = NSTrackingInVisibleRect | NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow;
    self.trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:options owner:self userInfo:nil];
    [self addTrackingArea:self.trackingArea];

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
