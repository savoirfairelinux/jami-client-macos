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
        [self.accountAvatar setWantsLayer:YES];
        self.accountAvatar.layer.cornerRadius = self.accountAvatar.frame.size.width * 0.5;
        self.accountAvatar.layer.masksToBounds = YES;
        [self.accountStatus setWantsLayer:YES];
        [self.accountAvatar.layer setBackgroundColor:[[NSColor disabledControlTextColor] CGColor]];
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 101400
        if (@available(macOS 10.14, *)) {
            self.createNewAccountImage.contentTintColor = [NSColor clearColor];
        }
#endif
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
    NSColor* highlightBackground = @available(macOS 10.14, *) ? [NSColor controlColor] : [NSColor whiteColor];
    if (isHighlighted) {
        [self.backgroundView setFillColor: highlightBackground];
    } else {
        [self.backgroundView setFillColor:[NSColor windowBackgroundColor]];
    }
    [super drawRect: rect];
}

@end
