/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
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

#import "IMTableCellView.h"

#import "NSColor+RingTheme.h"

@implementation IMTableCellView
@synthesize msgView;
@synthesize photoView;


- (void) setup
{
    if ([self.identifier isEqualToString:@"RightMessageView"]) {
        self.msgBackground.pointerDirection = RIGHT;
        self.msgBackground.bgColor = [NSColor ringLightBlue];

    }
    else {
        self.msgBackground.pointerDirection = LEFT;
        self.msgBackground.bgColor = [NSColor whiteColor];
    }
    [self.msgView setBackgroundColor:[NSColor clearColor]];
    [self.msgView setString:@""];
    [self.msgView setAutoresizingMask:NSViewWidthSizable];
     [self.msgView setAutoresizingMask:NSViewHeightSizable];
    [self.msgBackground setAutoresizingMask:NSViewWidthSizable];
    [self.msgBackground setAutoresizingMask:NSViewHeightSizable];
    [self.msgView setEnabledTextCheckingTypes:NSTextCheckingTypeLink];
    [self.msgView setAutomaticLinkDetectionEnabled:YES];
   }

- (void) updateWidthConstraint:(CGFloat) newWidth
{
    [self.msgView removeConstraints:[self.msgView constraints]];
    NSLayoutConstraint* constraint = [NSLayoutConstraint
                                      constraintWithItem:self.msgView
                                      attribute:NSLayoutAttributeWidth
                                      relatedBy:NSLayoutRelationEqual
                                      toItem: nil
                                      attribute:NSLayoutAttributeWidth
                                      multiplier:1.0f
                                      constant:newWidth];

    [self.msgView addConstraint:constraint];
}

@end
