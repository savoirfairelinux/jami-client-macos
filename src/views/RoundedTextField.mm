/*
 *  Copyright (C) 2015-2017 Savoir-faire Linux Inc.
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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
#import "RoundedTextField.h"
#import "NSColor+RingTheme.h"

@implementation RoundedTextField

-(void) awakeFromNib {
    if (!self.bgColor) {
        self.bgColor = [NSColor controlColor];
    }

    if (!self.cornerRadius) {
        self.cornerRadius = @(NSWidth(self.frame) / 2);
    }

    if(!self.borderColor) {
        self.borderColor = [self.bgColor darkenColorByValue:0.1];
    }

    self.backgroundColor = [NSColor controlColor];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    NSColor* backgroundColor = self.bgColor;
    NSColor* borderColor = self.borderColor;

    NSRect group = NSMakeRect(NSMinX(dirtyRect) + floor(NSWidth(dirtyRect) * 0.03333) + 0.5,
                              NSMinY(dirtyRect) + floor(NSHeight(dirtyRect) * 0.03333) + 0.5,
                              floor(NSWidth(dirtyRect) * 0.96667) - floor(NSWidth(dirtyRect) * 0.03333),
                              floor(NSHeight(dirtyRect) * 0.96667) - floor(NSHeight(dirtyRect) * 0.03333));

    NSBezierPath* ovalPath = [NSBezierPath bezierPathWithRoundedRect:
                              NSMakeRect(NSMinX(group) + floor(NSWidth(group) * 0.00000 + 0.5),
                                         NSMinY(group) + floor(NSHeight(group) * 0.00000 + 0.5),
                                         floor(NSWidth(group) * 1.00000 + 0.5) - floor(NSWidth(group) * 0.00000 + 0.5),
                                         floor(NSHeight(group) * 1.00000 + 0.5) - floor(NSHeight(group) * 0.00000 + 0.5))
                                                             xRadius:[self.cornerRadius floatValue] yRadius:[self.cornerRadius floatValue]];
    [backgroundColor setFill];
    [ovalPath fill];
    [borderColor setStroke];
    [ovalPath setLineWidth: 0.5];
    [ovalPath stroke];
    NSDictionary *att = nil;

    NSMutableParagraphStyle *style =
    [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [style setLineBreakMode:NSLineBreakByWordWrapping];
    [style setAlignment:NSCenterTextAlignment];
    att = [[NSDictionary alloc] initWithObjectsAndKeys:
           style, NSParagraphStyleAttributeName,
           [self textColor],
           NSForegroundColorAttributeName, nil];
    [[self stringValue] drawInRect:dirtyRect withAttributes:att];
}

@end
