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

NSString* const MESSAGE_MARGIN = @"10";
NSString* const TIME_BOX_HEIGHT = @"34";

@synthesize msgView, msgBackground, timeBox;
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
    [self.msgView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.msgBackground setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.msgView setEnabledTextCheckingTypes:NSTextCheckingTypeLink];
    [self.msgView setAutomaticLinkDetectionEnabled:YES];
    [self.msgView setEditable:NO];
}

- (void) updateConstraint:(CGFloat) width andHeight: (CGFloat) height timeIsVisible: (bool) visible
{
    [NSLayoutConstraint deactivateConstraints:[self.msgView constraints]];
    [NSLayoutConstraint deactivateConstraints:[self.timeBox constraints]];
    NSString* formatWidth = [NSString stringWithFormat:@"H:|-%@-[msgView(==%@)]-%@-|",
                             MESSAGE_MARGIN,[NSString stringWithFormat:@"%f", width],
                             MESSAGE_MARGIN];
    NSString* formatHeight = [NSString stringWithFormat:@"V:[msgView(==%@)]",
                              [NSString stringWithFormat:@"%f", height]];

    NSArray* constraintsMessageHorizontal = [NSLayoutConstraint
                                      constraintsWithVisualFormat:formatWidth
                                      options:NSLayoutFormatAlignAllCenterY
                                      metrics:nil                                                                          views:NSDictionaryOfVariableBindings(msgView)];
    NSArray* constraintsMessageVertical = [NSLayoutConstraint
                                    constraintsWithVisualFormat:formatHeight
                                    options:0
                                    metrics:nil                                                                          views:NSDictionaryOfVariableBindings(msgView)];

    NSLayoutConstraint* centerMessageConstraint =[NSLayoutConstraint constraintWithItem:msgView
                                                                       attribute:NSLayoutAttributeCenterY
                                                                       relatedBy:NSLayoutRelationEqual
                                                                          toItem:msgView.superview
                                                                       attribute:NSLayoutAttributeCenterY
                                                                      multiplier:1.f constant:0.f];

    NSString* formatTime = [NSString stringWithFormat:@"V:[timeBox(%@)]", TIME_BOX_HEIGHT];
    if (!visible) {
        formatTime = [NSString stringWithFormat:@"V:[timeBox(0)]"];
    }
    NSArray* constraintsVerticalTimeBox = [NSLayoutConstraint
                                               constraintsWithVisualFormat:formatTime
                                               options:0
                                               metrics:nil                                                                          views:NSDictionaryOfVariableBindings(timeBox)];
    NSArray* constraints = [[[constraintsMessageHorizontal arrayByAddingObjectsFromArray:constraintsMessageVertical]
                             arrayByAddingObject:centerMessageConstraint] arrayByAddingObjectsFromArray:constraintsVerticalTimeBox];
    [NSLayoutConstraint activateConstraints:constraints];
}

- (uint64_t)interaction
{
    return interaction;
}

@end
