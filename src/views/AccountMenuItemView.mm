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

NSTrackingArea *trackingArea;

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self loadFromNib];
    }
    return self;
}

- (void) createTrackingArea
{
   NSTrackingAreaOptions options = (NSTrackingActiveAlways | NSTrackingInVisibleRect | NSTrackingMouseEnteredAndExited);

    trackingArea = [[NSTrackingArea alloc] initWithRect: NSInsetRect(self.frame, 3, 3)
                                                        options:options
                                                          owner:self
                                                       userInfo:nil];

    [self addTrackingArea:trackingArea];
    NSPoint mouseLocation = [[self window] mouseLocationOutsideOfEventStream];
    mouseLocation = [self convertPoint: mouseLocation
                              fromView: nil];

    if (NSPointInRect(mouseLocation, [self bounds]))
    {
        [self mouseEntered: nil];
    }
    else
    {
        [self mouseExited: nil];
    }
}

- (void) updateTrackingAreas
{
    [self removeTrackingArea:trackingArea];
    [self createTrackingArea];
    [super updateTrackingAreas];
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
        [self.backgroundView setFillColor:[NSColor windowBackgroundColor]];
        NSColor *color = [self checkIsDarkMode] ? [NSColor lightGrayColor] : [NSColor darkGrayColor];
        self.rendezVousIndicator.image = [NSColor image: [NSImage imageNamed:@"ic_group.png"] tintedWithColor: color];
        [self createTrackingArea];
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

- (void)mouseExited:(NSEvent *)event {
    [self.backgroundView setFillColor:[NSColor windowBackgroundColor]];
}

- (void)mouseEntered:(NSEvent *)event {
    NSColor* highlightBackground = @available(macOS 10.14, *) ? [NSColor controlColor] : [NSColor whiteColor];
    [self.backgroundView setFillColor: highlightBackground];
}

-(void) viewDidChangeEffectiveAppearance {
    NSColor *color = [self checkIsDarkMode] ? [NSColor lightGrayColor] : [NSColor darkGrayColor];
    self.rendezVousIndicator.image = [NSColor image: [NSImage imageNamed:@"ic_group.png"] tintedWithColor: color];
    [super viewDidChangeEffectiveAppearance];
}

-(BOOL)checkIsDarkMode {
    NSAppearance *appearance = NSAppearance.currentAppearance;
    if (@available(*, macOS 10.14)) {
        NSString *interfaceStyle = [NSUserDefaults.standardUserDefaults valueForKey:@"AppleInterfaceStyle"];
        return [interfaceStyle isEqualToString:@"Dark"];
    }
    return NO;
}


@end
