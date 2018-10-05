/*
     File: HoverTableRowView.m
 Abstract: Custom NSTableRowView class for custom drawing and mouse tracking feedback via NSTrackingArea
  Version: 1.1

 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.

 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.

 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.

 Copyright (C) 2012 Apple Inc. All Rights Reserved.

 */

#import "HoverTableRowView.h"

#import "NSColor+RingTheme.h"

@interface HoverTableRowView ()
@property BOOL mouseInside;
@property NSVisualEffectView* effect_view;
@end

@implementation HoverTableRowView

@dynamic mouseInside;

- (instancetype)init
{
    [self configureView];
}

-  (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];

    if (self) {
        [self configureView];
    }
    return self;
}

- (id)initWithCoder:(NSCoder*)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self configureView];
    }
    return self;
}

- (void)configureView {
    self.highlightable = YES;
    self.effect_view = [[NSVisualEffectView alloc] initWithFrame: [self bounds]];
    [self.effect_view setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
    [self addSubview: self.effect_view positioned: NSWindowBelow relativeTo:nil];
    [self.effect_view setHidden:YES];
    [self.effect_view setMaterial: static_cast<NSVisualEffectMaterial>(6)];
}

- (void)setMouseInside:(BOOL)value {
    if (mouseInside != value) {
        mouseInside = value;
        [self setNeedsDisplay:YES];
    }
}

- (BOOL)mouseInside {
    return mouseInside;
}

- (void)ensureTrackingArea {
    if (trackingArea == nil) {
        trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect
                                                    options:NSTrackingInVisibleRect
                        | NSTrackingActiveAlways
                        | NSTrackingMouseEnteredAndExited owner:self userInfo:nil];
    }
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    [self ensureTrackingArea];
    if (![[self trackingAreas] containsObject:trackingArea]) {
        [self addTrackingArea:trackingArea];
    }
}

- (void)mouseEntered:(NSEvent *)theEvent {
    self.mouseInside = YES;
}

- (void)mouseExited:(NSEvent *)theEvent {
    self.mouseInside = NO;
}

-(void) drawSelection: (BOOL) isSelected {
    [self.effect_view setHidden: !isSelected];
    [self.effect_view setMaterial: isSelected ? static_cast<NSVisualEffectMaterial>(4) : static_cast<NSVisualEffectMaterial>(6)];
}
- (void)drawBackgroundInRect:(NSRect)dirtyRect {
    // Custom background drawing. We don't call super at all.
    [self.effect_view setHidden:YES];

    if ((self.mouseInside) && self.highlightable) {
        [self.effect_view setHidden:NO];
    }
}

- (NSRect)separatorRect {
    NSRect separatorRect = self.bounds;
    separatorRect.origin.y = NSMaxY(separatorRect) - 1;
    separatorRect.size.height = 1;
    return separatorRect;
}

// Only called if the table is set with a horizontal grid
- (void)drawSeparatorInRect:(NSRect)dirtyRect {
    // Use a common shared method of drawing the separator
    DrawSeparatorInRect([self separatorRect]);
}

// Only called if the 'selected' property is yes.
- (void)drawSelectionInRect:(NSRect)dirtyRect {
    [self.effect_view setHidden:NO];
}

// interiorBackgroundStyle is normaly "dark" when the selection is drawn (self.selected == YES) and we are in a key window (self.emphasized == YES). However, we always draw a light selection, so we override this method to always return a light color.
- (NSBackgroundStyle)interiorBackgroundStyle {
    return NSBackgroundStyleLight;
}

- (void)setFrame:(NSRect)frameRect {
    [super setFrame:frameRect];
    // We need to invalidate more things when live-resizing since we fill with a gradient and stroke
    if ([self inLiveResize]) {
        // Redraw everything if we are using a gradient
        if (self.selected || self.mouseInside) {
            [self setNeedsDisplay:YES];
        } else {
            // Redraw our horizontal grid line, which is a gradient
            [self setNeedsDisplayInRect:[self separatorRect]];
        }
    }
}

- (void)prepareForReuse {
    [self.effect_view setHidden:YES];
    self.mouseInside = NO;
    [super prepareForReuse];
}

@end

void DrawSeparatorInRect(NSRect rect) {
    static NSColor *color = [NSColor colorWithSRGBRed:.90 green:.90 blue:.90 alpha:1];
    [color drawSwatchInRect:rect];

}
