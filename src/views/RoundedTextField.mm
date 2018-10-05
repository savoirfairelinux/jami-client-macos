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

    if(!self.borderThickness) {
        self.borderThickness = [NSNumber numberWithDouble:1.0];
    }

    self.backgroundColor = [NSColor controlColor];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    NSColor* backgroundColor = self.bgColor;
    NSColor* borderColor = self.borderColor;
    CGFloat borderThickness = [self.borderThickness floatValue];

    NSRect group = dirtyRect;
    NSBezierPath* ovalPath = [NSBezierPath bezierPathWithRoundedRect: NSMakeRect(dirtyRect.origin.x + borderThickness * 0.5, dirtyRect.origin.y + borderThickness * 0.5, dirtyRect.size.width - borderThickness, dirtyRect.size.height - borderThickness)
                                                             xRadius:[self.cornerRadius floatValue] yRadius:[self.cornerRadius floatValue]];
    [backgroundColor setFill];
    [ovalPath fill];
    [borderColor setStroke];
    [ovalPath setLineWidth: borderThickness];
    [ovalPath stroke];
    NSDictionary *att = nil;

    NSMutableParagraphStyle *style =
    [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [style setLineBreakMode:NSLineBreakByWordWrapping];
    [style setAlignment:NSCenterTextAlignment];
    NSFont *font = [NSFont systemFontOfSize:10.0];

    if (self.stringValue.length > 1) {
        font = [NSFont systemFontOfSize:8.0];
    }
    if (self.stringValue.length > 2) {
       font = [NSFont systemFontOfSize:6.0];
    }

    att = [[NSDictionary alloc] initWithObjectsAndKeys:
           font,NSFontAttributeName,
           style, NSParagraphStyleAttributeName,
           [self textColor],
           NSForegroundColorAttributeName, nil];
    NSAttributedString *attrString =
    [[NSAttributedString alloc] initWithString:[self stringValue]
                                    attributes:att];
    CGFloat stringHeight = attrString.size.height;
    CGFloat originY = (group.size.height - stringHeight)  / 2;
    NSRect titleRect = CGRectMake(group.origin.x, originY, group.size.width, group.size.height);
    [[self stringValue] drawInRect:titleRect withAttributes:att];
}

@end
