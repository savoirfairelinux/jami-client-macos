/*
 *  Copyright (C) 2016-2019 Savoir-faire Linux Inc.
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

#import <Cocoa/Cocoa.h>
#import "MessageBubbleView.h"


@interface IMTableCellView : NSTableCellView

@property (nonatomic, strong) IBOutlet NSImageView* photoView;
@property (nonatomic, strong) IBOutlet NSTextView* msgView;
@property (nonatomic, strong) IBOutlet MessageBubbleView* msgBackground;
@property (nonatomic, strong) IBOutlet NSButton* acceptButton;
@property (nonatomic, strong) IBOutlet NSButton* declineButton;
@property (nonatomic, strong) IBOutlet NSProgressIndicator* progressIndicator;
@property (nonatomic, strong) IBOutlet NSTextField* statusLabel;
@property (nonatomic, strong) IBOutlet NSBox* timeBox;
@property (nonatomic, strong) IBOutlet NSTextField* timeLabel;
@property (nonatomic, strong) IBOutlet NSButton* transferedFileName;
@property (nonatomic, strong) IBOutlet NSImageView* transferedImage;
@property (nonatomic, strong) IBOutlet NSProgressIndicator* sendingMessageIndicator;
@property (nonatomic, strong) IBOutlet NSImageView* messageFailed;
@property (nonatomic, strong) IBOutlet NSView* messageStatus;
@property (nonatomic, strong) IBOutlet NSButton* openImagebutton;
@property (nonatomic, strong) IBOutlet NSView* compozingIndicator1;
@property (nonatomic, strong) IBOutlet NSView* compozingIndicator2;
@property (nonatomic, strong) IBOutlet NSView* compozingIndicator3;
@property (assign) IBOutlet NSLayoutConstraint* messageWidthConstraint;
@property (assign) IBOutlet NSLayoutConstraint* messageHeightConstraint;
@property (nonatomic, strong) IBOutlet NSImageView* readIndicator;
@property (nonatomic, strong) IBOutlet NSButton* openFileButton;
@property (copy) void (^onRightClick)(NSEvent* event);

- (uint64_t) interaction;
- (void) setupForInteraction:(uint64_t)inter isFailed:(bool) failed;
- (void) setupForInteraction:(uint64_t)inter;
- (void) updateMessageConstraint:(CGFloat) width andHeight: (CGFloat) height timeIsVisible: (bool) visible isTopPadding: (bool) padding;
- (void)updateWidthConstraints:(CGFloat)width;
- (void)updateHeightConstraints:(CGFloat)height;
- (void) updateImageConstraintWithMax: (CGFloat) maxDimension;
- (void) animateCompozingIndicator:(BOOL) animate;
- (void) startBlinkAnimation:(NSView*) view withDelay:(CGFloat) delay;
- (void) blinkAnimation: (NSView*) view;
@end
