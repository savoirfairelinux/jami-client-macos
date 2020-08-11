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

#import "RingTableView.h"

#import "HoverTableRowView.h" // For the grid drawing shared code

@implementation RingTableView

- (NSMenu*)menuForEvent:(NSEvent*)evt
{
    // TODO : Reimplement without outlineView itemAtRow: method
    NSPoint pt = [self convertPoint:[evt locationInWindow] fromView:nil];
    int rowIdx = [self rowAtPoint:pt];
    if (self.contextMenuDelegate && rowIdx >= 0) {
        return [self.contextMenuDelegate contextualMenuForRow:rowIdx table: self];
    }
    return nil;
}

- (void)keyDown:(NSEvent *)theEvent
{
    // Handle the Tab key
    if ([[theEvent characters] characterAtIndex:0] == NSTabCharacter) {
        if (([theEvent modifierFlags] & NSShiftKeyMask) != NSShiftKeyMask) {
            [[self window] selectKeyViewFollowingView:self];
        } else {
            [[self window] selectKeyViewPrecedingView:self];
        }
    }
    else if (([theEvent modifierFlags] & NSCommandKeyMask) == NSCommandKeyMask) {
        if (self.shortcutsDelegate) {
            if ([[theEvent characters] characterAtIndex:0] == 'a') {
                [self.shortcutsDelegate onAddShortcut];
            }
        }
    } else
        [super keyDown:theEvent];
}

- (CGFloat)yPositionPastLastRow {
    // Only draw the grid past the last visible row
    NSInteger numberOfRows = self.numberOfRows;
    CGFloat yStart = 0;
    if (numberOfRows > 0) {
        yStart = NSMaxY([self rectOfRow:numberOfRows - 1]);
    }
    return yStart;
}

- (void)drawGridInClipRect:(NSRect)clipRect {
    // Only draw the grid past the last visible row
    CGFloat yStart = [self yPositionPastLastRow];
    // Draw the first separator one row past the last row
    yStart += self.rowHeight;

    // One thing to do is smarter clip testing to see if we actually need to draw!
    NSRect boundsToDraw = self.bounds;
    NSRect separatorRect = boundsToDraw;
    separatorRect.size.height = 1;
    while (yStart < NSMaxY(boundsToDraw)) {
        separatorRect.origin.y = yStart;
        DrawSeparatorInRect(separatorRect);
        yStart += self.rowHeight;
    }
}

- (void)setFrameSize:(NSSize)size {
    [super setFrameSize:size];
    // We need to invalidate more things when live-resizing since we fill with a gradient and stroke
    if ([self inLiveResize]) {
        CGFloat yStart = [self yPositionPastLastRow];
        if (NSHeight(self.bounds) > yStart) {
            // Redraw our horizontal grid lines
            NSRect boundsPastY = self.bounds;
            boundsPastY.size.height -= yStart;
            boundsPastY.origin.y = yStart;
            [self setNeedsDisplayInRect:boundsPastY];
        }
    }
}

@end
