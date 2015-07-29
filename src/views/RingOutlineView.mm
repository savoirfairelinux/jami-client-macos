/*
 *  Copyright (C) 2015 Savoir-faire Linux Inc.
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
 *
 *  Additional permission under GNU GPL version 3 section 7:
 *
 *  If you modify this program, or any covered work, by linking or
 *  combining it with the OpenSSL project's OpenSSL library (or a
 *  modified version of that library), containing parts covered by the
 *  terms of the OpenSSL or SSLeay licenses, Savoir-Faire Linux Inc.
 *  grants you additional permission to convey the resulting work.
 *  Corresponding Source for a non-source form of such a combination
 *  shall include the source code for the parts of OpenSSL used as well
 *  as that of the covered work.
 */

#import "RingOutlineView.h"

@implementation RingOutlineView

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
