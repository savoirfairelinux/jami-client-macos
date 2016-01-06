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

#import "ContextualTableCellView.h"

@interface ContextualTableCellView()

@property NSTrackingArea *trackingArea;

@end

@implementation ContextualTableCellView


- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    [self ensureTrackingArea];
    if (![[self trackingAreas] containsObject:_trackingArea]) {
        [self addTrackingArea:_trackingArea];
    }
}

- (void)ensureTrackingArea {
    if (_trackingArea == nil) {
        _trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect
                                                    options:NSTrackingInVisibleRect
                        | NSTrackingActiveAlways
                        | NSTrackingMouseEnteredAndExited owner:self userInfo:nil];
    }
}

- (void)prepareForReuse
{
    for (NSView* item in self.contextualsControls) {
        [item setHidden:YES];
    }
}

- (void)mouseEntered:(NSEvent *)theEvent
{
    if (self.activeState)
        return;

    for (NSView* item in self.contextualsControls) {
        [item setHidden:NO];
    }
}

- (void)mouseExited:(NSEvent *)theEvent
{
    for (NSView* item in self.contextualsControls) {
        [item setHidden:YES];
    }
}

@end
