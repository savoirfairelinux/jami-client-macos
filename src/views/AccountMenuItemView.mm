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

#import "AccountMenuItemView.h"
#import "NSColor+RingTheme.h"

@implementation AccountMenuItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self loadFromNib];
    }
    return self;
}

- (void)loadFromNib
{
    NSView *viewFromXib = nil;
    NSArray *objectsFromXib = nil;
    [[NSBundle mainBundle] loadNibNamed:@"AccountMenuItemView" owner:self topLevelObjects:&objectsFromXib];
    for (id item in objectsFromXib) {
        if ([item isKindOfClass:[NSView class]]) {
            viewFromXib = item;
            break;
        }
    }
    if (viewFromXib != nil) {
        self.frame = viewFromXib.frame;
        self.containerView = viewFromXib;
        [self addSubview:self.containerView];
    }
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    return YES;
}

-(void) mouseUp:(NSEvent *)theEvent {
    NSMenu *menu = self.enclosingMenuItem.menu;
    [menu cancelTracking];
    [menu performActionForItemAtIndex:[menu indexOfItem:self.enclosingMenuItem]];
    [super mouseUp:theEvent];
}

- (void) drawRect: (NSRect) rect {
    NSMenuItem *menuItem = ([self enclosingMenuItem]);
    BOOL isHighlighted = [menuItem isHighlighted];
    if (isHighlighted) {
        [[NSColor ringGreyHighlight] set];
        [NSBezierPath fillRect:rect];
    } else {
        [super drawRect: rect];
    }
}

@end
