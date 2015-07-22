//
//  RingOutlineView.m
//  Ring
//
//  Created by Alexandre Lision on 2015-07-17.
//
//

#import "RingOutlineView.h"

@implementation RingOutlineView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (NSMenu*)menuForEvent:(NSEvent*)evt
{
    NSPoint pt = [self convertPoint:[evt locationInWindow] fromView:nil];
    int rowIdx = [self rowAtPoint:pt];
    int colIdx = [self columnAtPoint:pt];
    if (self.contextMenuDelegate && rowIdx >= 0 && colIdx >= 0) {
        NSUInteger indexes[2] = {static_cast<NSUInteger>(rowIdx), static_cast<NSUInteger>(colIdx)};
        NSIndexPath* path = [NSIndexPath indexPathWithIndexes:indexes length:2];
        return [self.contextMenuDelegate contextualMenuForIndex:path];
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

@end
