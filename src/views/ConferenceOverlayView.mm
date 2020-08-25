/*
*  Copyright (C) 2020 Savoir-faire Linux Inc.
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

#import "ConferenceOverlayView.h"

@implementation ConferenceOverlayView
@synthesize contextualMenu;

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = false;
        [self setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable | NSViewMinYMargin | NSViewMaxYMargin | NSViewMinXMargin | NSViewMaxXMargin];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sizeChanged) name:NSWindowDidResizeNotification object:nil];
        [self configureView];
        self.alphaValue = 0;
    }
    return self;
}

- (void)configureView {
    self.gradientView = [[GradientView alloc] init];
    self.gradientView.startingColor = [NSColor clearColor];
    self.gradientView.endingColor = [NSColor blackColor];
    self.gradientView.angle = 270;
    self.gradientView.translatesAutoresizingMaskIntoConstraints = false;
    [self addSubview: self.gradientView];
    [self.gradientView.widthAnchor constraintEqualToAnchor:self.widthAnchor multiplier: 1].active = TRUE;
    [self.gradientView.heightAnchor constraintEqualToConstant:40].active = true;
    [self.gradientView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor].active = true;
    [self.gradientView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor].active = true;
    self.settingsButton = [[IconButton alloc] init];
    self.settingsButton.transparent = true;
    self.settingsButton.title = @"";
    NSImage* settingsImage = [NSImage imageNamed: @"ic_more.png"];
    [self.settingsButton setImage:settingsImage];
    self.settingsButton.bgColor = [NSColor clearColor];
    self.settingsButton.imageColor = [NSColor whiteColor];
    self.settingsButton.imageInsets = 6;
    self.settingsButton.translatesAutoresizingMaskIntoConstraints = false;
    [self.gradientView addSubview:self.settingsButton];

    [self.settingsButton.widthAnchor constraintEqualToConstant:40].active = TRUE;
    [self.settingsButton.heightAnchor constraintEqualToConstant:40].active = true;
    [self.settingsButton.trailingAnchor constraintEqualToAnchor:self.gradientView.trailingAnchor].active = true;
    [self.settingsButton.bottomAnchor constraintEqualToAnchor:self.gradientView.bottomAnchor].active = true;
    [self.settingsButton setAction:@selector(triggerMenu:)];
    [self.settingsButton setTarget:self];
}

- (IBAction)triggerMenu:(id)sender {
    int layout = [self.delegate getCurrentLayout];
    if (layout < 0)
        return;
    BOOL showMaximized = layout != 2;
    BOOL showMinimized = !(layout == 0 || (layout == 1 && !self.participant.active));
    contextualMenu = [[NSMenu alloc] initWithTitle:@""];
    if (showMinimized) {
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Minimize participant", @"Conference action") action:@selector(minimize:) keyEquivalent:@""];
        [menuItem setTarget:self];
        [contextualMenu insertItem:menuItem atIndex:contextualMenu.itemArray.count];
    }
    if (showMaximized) {
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Maximize participant", @"Conference action") action:@selector(maximize:) keyEquivalent:@""];
        [menuItem setTarget:self];
        [contextualMenu insertItem:menuItem atIndex:contextualMenu.itemArray.count];
    }
    if (!self.participant.isLocal) {
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Finish call", @"Conference action") action:@selector(finishCall:) keyEquivalent:@""];
        [menuItem setTarget:self];
        [contextualMenu insertItem:menuItem atIndex:contextualMenu.itemArray.count];
    }
    [contextualMenu popUpMenuPositioningItem:nil atLocation:[NSEvent mouseLocation] inView:nil];
}

- (void)minimize:(NSMenuItem*) sender {
    [self.delegate minimizeParticipant];
}

- (void)maximize:(NSMenuItem*) sender {
    [self.delegate maximizeParticipant:self.participant.uri active: self.participant.active];
}

- (void)finishCall:(NSMenuItem*) sender {
    [self.delegate hangUpParticipant:self.participant.uri];
}

- (void)sizeChanged {
    NSArray* constraints = [NSArray arrayWithObjects: self.widthConstraint, self.heightConstraint, self.centerXConstraint, self.centerYConstraint, nil];
    [self.superview removeConstraints: constraints];
    [self.superview layoutSubtreeIfNeeded];
    CGSize viewSize = self.superview.frame.size;
    CGFloat viewRatio = viewSize.width / viewSize.height;
    CGFloat frameRatio = self.framesize.width / self.framesize.height;
    CGFloat ratio = viewRatio * (1/frameRatio);
    // calculate size for all participants
    CGFloat allViewsWidth = viewSize.width;
    CGFloat allViewsHeight = viewSize.height;
    if (ratio < 1) {
        allViewsHeight = allViewsHeight * ratio;
    } else {
        allViewsWidth = allViewsWidth / ratio;
    }

    CGFloat widthRatio = self.participant.width / self.framesize.width;
    CGFloat heightRatio = self.participant.hight / self.framesize.height;

    CGFloat overlayWidth = allViewsWidth * widthRatio;
    CGFloat overlayHeight = allViewsHeight * heightRatio;
    CGFloat ratioX = overlayWidth / viewSize.width;
    CGFloat ratioY = overlayHeight / viewSize.height;
    CGFloat offsetx = (viewSize.width - allViewsWidth) * 0.5;
    CGFloat offsety = (viewSize.height - allViewsHeight) * 0.5;
    CGFloat centerX = (offsetx + (self.participant.x  * (overlayWidth / self.participant.width))+ overlayWidth * 0.5) / (viewSize.width * 0.5);
    CGFloat centerY = (offsety + (self.participant.y * (overlayHeight / self.participant.hight)) + overlayHeight * 0.5) / (viewSize.height * 0.5);

    self.centerXConstraint = [NSLayoutConstraint constraintWithItem:self
                                                          attribute:NSLayoutAttributeCenterX
                                                          relatedBy:NSLayoutRelationEqual toItem:self.superview
                                                          attribute:NSLayoutAttributeCenterX
                                                         multiplier:centerX constant:0];
    self.centerYConstraint = [NSLayoutConstraint constraintWithItem:self
                                                          attribute:NSLayoutAttributeCenterY
                                                          relatedBy:NSLayoutRelationEqual toItem:self.superview
                                                          attribute:NSLayoutAttributeCenterY
                                                         multiplier:centerY constant:0];
    self.widthConstraint =
    [self.widthAnchor constraintEqualToAnchor:self.superview.widthAnchor multiplier: ratioX];
    self.heightConstraint =  [self.heightAnchor constraintEqualToAnchor:self.superview.heightAnchor multiplier: ratioY];
    self.widthConstraint.active = YES;
    self.heightConstraint.active = YES;
    self.centerXConstraint.active = YES;
    self.centerYConstraint.active = YES;
    [self layoutSubtreeIfNeeded];
}

- (void)updateViewWithParticipant:(ConferenceParticipant) participant {
    self.participant = participant;
    [self sizeChanged];
}

-(void)mouseEntered:(NSEvent *)theEvent {
    self.alphaValue = 1;
    [super mouseEntered:theEvent];
}

-(void)mouseExited:(NSEvent *)theEvent {
    self.alphaValue = 0;
    [super mouseExited:theEvent];
}

- (void)ensureTrackingArea {
    if (trackingArea == nil) {
        trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect
                                                    options:NSTrackingInVisibleRect
                        | NSTrackingActiveAlways
                        | NSTrackingMouseEnteredAndExited owner:self userInfo:nil];
    }
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    [self ensureTrackingArea];
    if (![[self trackingAreas] containsObject:trackingArea]) {
        [self addTrackingArea:trackingArea];
    }
}


@end
