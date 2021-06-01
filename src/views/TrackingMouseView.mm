//
//  TrackingMouseView.m
//  Jami
//
//  Created by kateryna on 2021-06-01.
//

#import "TrackingMouseView.h"

@implementation TrackingMouseView

bool shouldTrackMouseEvents = false;

- (void)subscribeForMouceMovement:(BOOL)subscribe {
    shouldTrackMouseEvents = subscribe;
    if (shouldTrackMouseEvents) {
        if (![[self trackingAreas] containsObject:trackingArea]) {
            [self addTrackingArea:trackingArea];
        }
    } else {
        if ([[self trackingAreas] containsObject: trackingArea]) {
            [self removeTrackingArea: trackingArea];
        }
    }
}
- (void)ensureTrackingArea {
    if (trackingArea == nil) {
        trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect
                                                    options:NSTrackingInVisibleRect
                        | NSTrackingActiveAlways
                        | NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved owner:self userInfo:nil];
    }
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    [self ensureTrackingArea];
    if (![[self trackingAreas] containsObject:trackingArea] && shouldTrackMouseEvents) {
        [self addTrackingArea:trackingArea];
    }
}

-(void)mouseExited:(NSEvent *)theEvent {
    [super mouseExited: theEvent];
    [self.delegate mouseExited];
}

@end
