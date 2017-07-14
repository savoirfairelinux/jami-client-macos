/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
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

#import "SendMessagePanel.h"
#import "NSColor+RingTheme.h"

@implementation SendMessagePanel

-(void) awakeFromNib {
    self.messageCell.viewDelegate = self;
}


- (void)drawRect:(NSRect)dirtyRect {

    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(40, dirtyRect.size.height)];
    [path lineToPoint:NSMakePoint(dirtyRect.size.width - 40 , dirtyRect.size.height)];
    BOOL isEditing = [(NSTextField *)[self.messageCell controlView] currentEditor] != nil;
    if(isEditing) {
        [[NSColor ringBlue]set];
        [path setLineWidth:3];
    }
    else {

        [[NSColor quaternaryLabelColor]set];
        [path setLineWidth:2];
    }
    [path stroke];
    [super drawRect:dirtyRect];
}

-(void) focusChanged {

    [self setNeedsDisplay:YES];
}

@end
