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

CGFloat const margin = 2;
CGFloat const controlSize = 25;

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = false;
        [self setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable | NSViewMinYMargin | NSViewMaxYMargin | NSViewMinXMargin | NSViewMaxXMargin];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sizeChanged) name:NSWindowDidResizeNotification object:nil];
        [self addViews];
    }
    return self;
}

- (void)addViews {
    self.gradientView = [[NSView alloc] init];
    [self.gradientView setWantsLayer:  YES];
    self.gradientView.layer.backgroundColor = [[NSColor colorWithCalibratedRed: 0 green: 0 blue: 0 alpha: 0.6] CGColor];
    self.gradientView.translatesAutoresizingMaskIntoConstraints = false;
    [self addSubview: self.gradientView];
    self.gradientView.hidden = true;
    
    //participat state
    self.audioState = [self getActionbutton];
    NSImage* audioImage = [NSImage imageNamed: @"ic_moderator_audio_muted.png"];
    [self.audioState setImage: audioImage];
    
    self.moderatorState = [self getActionbutton];
    NSImage* moderatorImage = [NSImage imageNamed: @"ic_moderator.png"];
    [self.moderatorState setImage: moderatorImage];
    
    self.hostState = [self getActionbutton];
    NSImage* hostImage = [NSImage imageNamed: @"ic_star.png"];
    [self.hostState setImage: hostImage];
    
    NSArray *statesViews = [NSArray arrayWithObjects: self.hostState, self.moderatorState, self.audioState, nil];
    self.states = [NSStackView stackViewWithViews: statesViews];
    [self addSubview: self.states];
    
    //actions
    self.maximize = [self getActionbutton];
    NSImage* maximizeImage = [NSImage imageNamed: @"ic_moderator_maximize.png"];
    [self.maximize setImage: maximizeImage];
    [self.maximize setAction:@selector(maximize:)];
    [self.maximize setTarget:self];

    self.minimize = [self getActionbutton];
    NSImage* minimizeImage = [NSImage imageNamed: @"ic_moderator_minimize.png"];
    [self.minimize setImage: minimizeImage];
    [self.minimize setAction:@selector(minimize:)];
    [self.minimize setTarget:self];
    
    self.hangup = [self getActionbutton];
    NSImage* hangupImage = [NSImage imageNamed: @"ic_moderator_hangup.png"];
    [self.hangup setImage: hangupImage];
    [self.hangup setAction:@selector(finishCall:)];
    [self.hangup setTarget:self];

    self.setModerator = [self getActionbutton];
    NSImage* setModeratorImage = [NSImage imageNamed: @"ic_moderator.png"];
    [self.setModerator setImage: setModeratorImage];
    [self.setModerator setAction:@selector(setModerator:)];
    [self.setModerator setTarget:self];
    
    self.muteAudio = [self getActionbutton];
    NSImage* muteAudioImage = [NSImage imageNamed: @"ic_moderator_audio_muted.png"];
    [self.muteAudio setImage: muteAudioImage];
    [self.muteAudio setAction:@selector(muteAudio:)];
    [self.muteAudio setTarget:self];
    
    NSArray *actions = [NSArray arrayWithObjects: self.setModerator, self.muteAudio, self.maximize, self.minimize, self.hangup, nil];
    self.buttonsContainer = [NSStackView stackViewWithViews: actions];
    self.buttonsContainer.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.buttonsContainer.spacing = 5;
    
    self.usernameLabel = [[NSTextView alloc] init];
    self.usernameLabel.alignment = NSTextAlignmentCenter;
    self.usernameLabel.textColor = [NSColor whiteColor];
    self.usernameLabel.editable = false;
    self.usernameLabel.drawsBackground = false;
    self.usernameLabel.font = [NSFont userFontOfSize: 13.0];
    self.usernameLabel.translatesAutoresizingMaskIntoConstraints = false;
    [self.usernameLabel.heightAnchor constraintEqualToConstant: 20].active = true;
    [self.usernameLabel.widthAnchor constraintGreaterThanOrEqualToConstant: 60].active = true;
    self.usernameLabel.textContainer.maximumNumberOfLines = 1;
    
    NSArray* infoItems = [NSArray arrayWithObjects: self.usernameLabel, self.buttonsContainer, nil];
    
    self.infoContainer = [NSStackView stackViewWithViews: infoItems];
    self.infoContainer.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.infoContainer.spacing = 0;
    self.infoContainer.distribution = NSStackViewDistributionFillEqually;
    self.infoContainer.alignment = NSLayoutAttributeCenterX;
    [self.gradientView addSubview: self.infoContainer];
}

- (IconButton*) getActionbutton {
    IconButton* button = [[IconButton alloc] init];
    button.transparent = true;
    [button.widthAnchor constraintEqualToConstant: controlSize].active = true;
    [button.heightAnchor constraintEqualToConstant: controlSize].active = true;
    button.title = @"";
    button.buttonDisableColor = [NSColor lightGrayColor];
    button.bgColor = [NSColor clearColor];
    button.imageColor = [NSColor whiteColor];
    button.imagePressedColor = [NSColor lightGrayColor];
    button.imageInsets = margin;
    button.translatesAutoresizingMaskIntoConstraints = false;
    return button;
}

- (void)configureView {
    [self.gradientView.widthAnchor constraintEqualToAnchor:self.widthAnchor multiplier: 1].active = TRUE;
    [self.gradientView.topAnchor constraintEqualToAnchor:self.topAnchor].active = true;
    [self.gradientView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor].active = true;
    [self.gradientView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor].active = true;
    
    [self.states.topAnchor constraintEqualToAnchor:self.topAnchor].active = true;
    [self.states.leadingAnchor constraintEqualToAnchor:self.leadingAnchor].active = true;
    
    [self.infoContainer.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:1].active = true;
    [self.infoContainer.centerXAnchor constraintEqualToAnchor:self.centerXAnchor constant:1].active = true;
}

- (IBAction)minimize:(id) sender {
    [self.delegate minimizeParticipant];
}

- (IBAction)maximize:(id) sender {
    [self.delegate maximizeParticipant:self.participant.uri active: self.participant.active];
}

- (IBAction)finishCall:(id) sender {
    [self.delegate hangUpParticipant: self.participant.uri];
}

- (IBAction)muteAudio:(id) sender {
    [self.delegate muteParticipantAudio: self.participant.uri state: !self.participant.audioModeratorMuted];
}

- (IBAction)setModerator:(id) sender {
    [self.delegate setModerator:self.participant.uri state: !self.participant.isModerator];
}

- (void)sizeChanged {
    if (self.superview == nil) {
        return;
    }
    NSArray* constraints = [NSArray arrayWithObjects: self.widthConstraint, self.heightConstraint, self.centerXConstraint, self.centerYConstraint, nil];
    [self.superview removeConstraints: constraints];
    [self.superview layoutSubtreeIfNeeded];
    CGSize viewSize = self.superview.frame.size;
    if (viewSize.width == 0 || viewSize.height == 0 || self.framesize.width == 0 || self.framesize.height == 0 || self.participant.width == 0 || self.participant.hight == 0) {
        self.frame = CGRectZero;
        return;
    }
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
    bool sizeChanged = self.participant.width != participant.width || self.participant.hight != participant.hight
    || self.participant.x != participant.x || self.participant.y != participant.y;
    self.participant = participant;
    [self updateButtonsState];
    if (sizeChanged) {
        [self sizeChanged];
    }
    self.usernameLabel.string = self.participant.bestName;
}

-(void) updateButtonsState {
    self.audioState.hidden = !self.participant.audioModeratorMuted;
    self.moderatorState.hidden = !self.participant.isModerator || [self.delegate isParticipantHost: self.participant.uri];
    self.hostState.hidden = ![self.delegate isParticipantHost: self.participant.uri];
    bool couldManageConference = [self.delegate isMasterCall] || [self.delegate isCallModerator];
    self.buttonsContainer.hidden = !couldManageConference;
    if (!couldManageConference) {
        return;
    }
    int layout = [self.delegate getCurrentLayout];
    if (layout < 0)
        return;
    BOOL showConferenceHostOnly = !self.participant.isLocal && [self.delegate isMasterCall];
    BOOL hangupEnabled = ![self.delegate isParticipantHost: self.participant.uri];
    BOOL showMaximized = layout != 2;
    BOOL showMinimized = !(layout == 0 || (layout == 1 && !self.participant.active));
    self.setModerator.enabled = showConferenceHostOnly;
    self.hangup.enabled = hangupEnabled;
    self.minimize.hidden = !showMinimized;
    self.maximize.hidden = !showMaximized;
    NSImage* muteAudioImage = self.participant.audioModeratorMuted ? [NSImage imageNamed: @"ic_moderator_audio_muted.png"] :
    [NSImage imageNamed: @"ic_moderator_audio_unmuted.png"];
    [self.muteAudio setImage: muteAudioImage];
}

-(void)mouseEntered:(NSEvent *)theEvent {
    self.gradientView.hidden = NO;
    [super mouseEntered:theEvent];
}

-(void)mouseExited:(NSEvent *)theEvent {
    self.gradientView.hidden = YES;
    [super mouseExited:theEvent];
}

-(void)mouseUp:(NSEvent *)theEvent
{
    [super mouseUp:theEvent];
    if ([theEvent clickCount] == 1) {
        [self performSelector:@selector(singleTap) withObject:nil afterDelay:[NSEvent doubleClickInterval]];
    } else if (theEvent.clickCount == 2) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(singleTap) object:nil];
    }
}

- (void)singleTap {
    [self.delegate maximizeParticipant:self.participant.uri active: self.participant.active];
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
