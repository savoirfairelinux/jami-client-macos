/*
 *  Copyright (C) 2016-2018 Savoir-faire Linux Inc.
 *  Author: Alexandre Lision <alexandre.lision@savoirfairelinux.com>
 *  Author: Anthony Léonard <anthony.leonard@savoirfairelinux.com>
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

@implementation IMTableCellView {
    uint64_t interaction;
}

@synthesize msgView;
@synthesize msgBackground;
@synthesize photoView;
@synthesize acceptButton;
@synthesize declineButton;
@synthesize progressIndicator;
@synthesize statusLabel;

- (void) setupDirection
{
    if ([self.identifier containsString:@"Right"]) {
        self.msgBackground.pointerDirection = RIGHT;
        self.msgBackground.bgColor = [NSColor ringLightBlue];
    }
    else {
        self.msgBackground.pointerDirection = LEFT;
        self.msgBackground.bgColor = [NSColor whiteColor];
    }
}

- (void) setupForInteraction:(uint64_t)inter
{
    interaction = inter;
    [self setupDirection];
    [self.msgView setBackgroundColor:[NSColor clearColor]];
    [self.msgView setString:@""];
    [self.msgView setAutoresizingMask:NSViewWidthSizable];
    [self.msgView setAutoresizingMask:NSViewHeightSizable];
    [self.msgBackground setAutoresizingMask:NSViewWidthSizable];
    [self.msgBackground setAutoresizingMask:NSViewHeightSizable];
    [self.msgView setEnabledTextCheckingTypes:NSTextCheckingTypeLink];
    [self.msgView setAutomaticLinkDetectionEnabled:YES];
    [self.msgView setEditable:NO];
    if ([self.identifier containsString:@"Message"]) {
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[msgView]"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:NSDictionaryOfVariableBindings(msgView)]];
    }
}

- (void) updateWidthConstraint:(CGFloat) newWidth andHeight:(CGFloat) height
{
    [self.msgBackground removeConstraints:[self.msgBackground constraints]];
    NSLayoutConstraint* constraint = [NSLayoutConstraint
                                      constraintWithItem:self.msgBackground
                                      attribute:NSLayoutAttributeWidth
                                      relatedBy:NSLayoutRelationEqual
                                      toItem: nil
                                      attribute:NSLayoutAttributeWidth
                                      multiplier:1.0f
                                      constant:newWidth];

    [self.msgBackground addConstraint:constraint];
    [self.msgView removeConstraints:[self.msgView constraints]];
    NSLayoutConstraint* constraintMessage = [NSLayoutConstraint
                                      constraintWithItem:self.msgView
                                      attribute:NSLayoutAttributeHeight
                                      relatedBy:NSLayoutRelationEqual
                                      toItem: nil
                                      attribute:NSLayoutAttributeWidth
                                      multiplier:1.0f
                                      constant:height];
    NSLayoutConstraint* constraintCenter= [NSLayoutConstraint
                                             constraintWithItem:self.msgView
                                             attribute:NSLayoutAttributeCenterY
                                             relatedBy:NSLayoutRelationEqual
                                             toItem: self.msgBackground
                                             attribute:NSLayoutAttributeWidth
                                             multiplier:1.0f
                                             constant:0];
    [self.msgView addConstraint:constraintMessage];
    [self.msgView addConstraint:constraintCenter];
}

- (uint64_t)interaction
{
    return interaction;
}

@end
