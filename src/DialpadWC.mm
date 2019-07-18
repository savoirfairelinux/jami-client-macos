/*
 *  Copyright (C) 2016-2019 Savoir-faire Linux Inc.
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

#import "DialpadWC.h"

@interface DialpadWC ()

@property (unsafe_unretained) IBOutlet NSTextField* composerField;

@end

@implementation DialpadWC
@synthesize composerField;

- (void)windowDidLoad {
    [super windowDidLoad];
}

- (IBAction)dtmfPressed:(id)sender
{
    [self sendDTMF:[sender title]];
}

- (void) keyDown:(NSEvent *)theEvent
{
    NSString* characters =  [theEvent characters];
    if ([characters length] == 1) {
        NSString* filter = @"0123456789*#";
        if ([filter containsString:characters]) {
            [self sendDTMF:characters];
        }
    }
}

- (void) sendDTMF:(NSString*) dtmf
{
}

///Accessibility
- (void)insertTab:(id)sender
{
    if ([[self window] firstResponder] == self) {
        [[self window] selectNextKeyView:self];
    }
}

- (void)insertBacktab:(id)sender
{
    if ([[self window] firstResponder] == self) {
        [[self window] selectPreviousKeyView:self];
    }
}

- (void) windowWillClose:(NSNotification *)notification
{
    [composerField setStringValue:@""];
    [composerField setNeedsDisplay:YES];
}

@end
