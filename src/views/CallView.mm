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

#import "CallView.h"
#import "CallLayer.h"

#import <QUrl>

@interface CallView ()

@property NSMenu *contextualMenu;

@end

@implementation CallView

NSString *currentDevice;
@synthesize contextualMenu;
@synthesize shouldAcceptInteractions;


- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self setWantsLayer:YES];
        [self setLayer:[CALayer layer]];
        [self.layer setBackgroundColor:[[NSColor blackColor] CGColor]];
    }

    [self.window setAcceptsMouseMovedEvents:YES];

    NSTrackingAreaOptions options = (NSTrackingActiveAlways | NSTrackingInVisibleRect | NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved);

    NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:frame
                                                        options:options
                                                          owner:self
                                                       userInfo:nil];

    [self addTrackingArea:area];
    return self;
}

- (void)mouseMoved:(NSEvent *)theEvent
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self]; // cancel showContextualMenu
    [self performSelector:@selector(mouseIdle:) withObject:theEvent afterDelay:3];
    if (self.callDelegate && shouldAcceptInteractions)
        [self.callDelegate mouseIsMoving:YES];
}

- (void) mouseIdle:(NSEvent *)theEvent
{
    if (self.callDelegate && shouldAcceptInteractions)
        [self.callDelegate mouseIsMoving:NO];
}

- (void)mouseUp:(NSEvent *)theEvent
{
    if([theEvent clickCount] == 2 && self.callDelegate) {
        [self.callDelegate callShouldToggleFullScreen];
    }
}

@end
