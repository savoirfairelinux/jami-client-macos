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
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>


@implementation IMTableCellView {
    uint64_t interaction;
}

NSString* const MESSAGE_MARGIN = @"10";
NSString* const TIME_BOX_HEIGHT = @"34";

@synthesize msgView, msgBackground, timeBox, transferedImage;
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
        self.messageFailed.image = [NSColor image: [NSImage imageNamed:@"ic_action_cancel.png"] tintedWithColor:[[NSColor errorColor] lightenColorByValue:0.05]];
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
    [self.msgView setEditable:NO];
    acceptButton.image = [NSColor image: [NSImage imageNamed:@"ic_file_upload.png"] tintedWithColor:[NSColor greenSuccessColor]];
    declineButton.image = [NSColor image: [NSImage imageNamed:@"ic_action_cancel.png"] tintedWithColor:[NSColor redColor]];
}

- (void) setupForInteraction:(uint64_t)inter isFailed:(bool) failed {
    [self setupForInteraction:inter];
    if (failed) {
       self.msgBackground.bgColor = [[NSColor errorColor] lightenColorByValue:0.2];
    }
}


- (void) updateMessageConstraint:(CGFloat) width andHeight: (CGFloat) height timeIsVisible: (bool) visible isTopPadding: (bool) padding
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
    [self.timeBox setHidden:NO];
    if (!visible) {
        formatTime = padding ? [NSString stringWithFormat:@"V:[timeBox(15)]"] : [NSString stringWithFormat:@"V:[timeBox(1)]"];
        [self.timeBox setHidden:YES];
    }
    NSArray* constraintsVerticalTimeBox = [NSLayoutConstraint
                                           constraintsWithVisualFormat:formatTime
                                           options:0
                                           metrics:nil                                                                          views:NSDictionaryOfVariableBindings(timeBox)];
    NSArray* constraints = [[[constraintsMessageHorizontal arrayByAddingObjectsFromArray:constraintsMessageVertical]
                             arrayByAddingObject:centerMessageConstraint] arrayByAddingObjectsFromArray:constraintsVerticalTimeBox];
    [NSLayoutConstraint activateConstraints:constraints];
}

- (void) updateImageConstraint: (CGFloat) width andHeight: (CGFloat) height {
    [NSLayoutConstraint deactivateConstraints:[self.transferedImage constraints]];
    [self.msgBackground setHidden:YES];
    NSString* formatHeight = [NSString stringWithFormat:@"V:[transferedImage(==%@)]",[NSString stringWithFormat:@"%f", height]];
    NSString* formatWidth = [NSString stringWithFormat:
                             @"H:[transferedImage(==%@)]",[NSString stringWithFormat:@"%f", width]];
    NSArray* constraintsHorizontal = [NSLayoutConstraint
                                      constraintsWithVisualFormat:formatWidth
                                      options:0
                                      metrics:nil                                                                          views:NSDictionaryOfVariableBindings(transferedImage)];
    NSArray* constraintsVertical = [NSLayoutConstraint
                                    constraintsWithVisualFormat:formatHeight
                                    options:0
                                    metrics:nil                                                                          views:NSDictionaryOfVariableBindings(transferedImage)];
    NSArray* constraints =[constraintsHorizontal arrayByAddingObjectsFromArray:constraintsVertical] ;
    [NSLayoutConstraint activateConstraints:constraintsHorizontal];
}

- (void) updateImageConstraintWithMax: (CGFloat) maxDimension {
    CGFloat widthScaleFactor = maxDimension / self.transferedImage.image.size.width;
    CGFloat heightScaleFactor = maxDimension / self.transferedImage.image.size.height;
    NSSize size = NSZeroSize;
    if((widthScaleFactor >= 0) && (heightScaleFactor >= 0)) {
        size.width = transferedImage.image.size.width;
        size.height = transferedImage.image.size.height;

    } else {
        CGFloat scale = MIN(widthScaleFactor, heightScaleFactor);
        size.width = transferedImage.image.size.width * scale;
        size.height = transferedImage.image.size.height * scale;
    }
    [self updateImageConstraint:size.width andHeight: size.height];
}

- (void) invalidateImageConstraints {
[NSLayoutConstraint deactivateConstraints:[self.transferedImage constraints]];
}

- (uint64_t)interaction
{
    return interaction;
}

@end
