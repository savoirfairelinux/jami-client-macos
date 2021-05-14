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
#import "CustomBackgroundView.h"

@implementation ConferenceOverlayView

CGFloat const buttonMargin = 2;
CGFloat const margin = 10;
CGFloat const controlSize = 20;
CGFloat const controlSizeMin = 18;
CGFloat const minWidthConst = 100;
CGFloat const minHeightConst = 70;
CGFloat const cornerRadius = 6;
CGFloat const stackViewSpacing = 5;

CGFloat minHeight = 80;
CGFloat minWidth = 140;

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = false;
        [self setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable | NSViewMinYMargin | NSViewMaxYMargin | NSViewMinXMargin | NSViewMaxXMargin];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewSizeChanged) name:NSWindowDidResizeNotification object:nil];
        self.wantsLayer = true;
        self.layer.masksToBounds = false;
        self.fullViewOverlay = false;
        [self addViews];
    }
    return self;
}

- (void)setMinButtonsSize {
    NSArray* buttons = self.buttonsContainer.arrangedSubviews;
    for (NSView * button in buttons) {
        [button removeConstraints:button.constraints];
        [button.widthAnchor constraintEqualToConstant: controlSizeMin].active = true;
        [button.heightAnchor constraintEqualToConstant: controlSizeMin].active = true;
    }
    NSArray* views = self.states.arrangedSubviews;
    for (NSView * state in views) {
        [state removeConstraints: state.constraints];
        [state.widthAnchor constraintEqualToConstant: controlSizeMin].active = true;
        [state.heightAnchor constraintEqualToConstant: controlSizeMin].active = true;
    }
}

- (void)setMaxButtonsSize {
    NSArray* buttons = self.buttonsContainer.arrangedSubviews;
    for (NSView * button in buttons) {
        [button removeConstraints:button.constraints];
        [button.widthAnchor constraintEqualToConstant: controlSize].active = true;
        [button.heightAnchor constraintEqualToConstant: controlSize].active = true;
    }
    NSArray* views = self.states.arrangedSubviews;
    for (NSView * state in views) {
        [state removeConstraints: state.constraints];
        [state.widthAnchor constraintEqualToConstant: controlSize].active = true;
        [state.heightAnchor constraintEqualToConstant: controlSize].active = true;
    }
}

-(CGFloat)getButtonsWidth {
    if (self.buttonsContainer.isHidden) {
        return 0;
    }
    NSArray* buttons = self.buttonsContainer.arrangedSubviews;
    CGFloat buttonsWidth = 0;
    for (NSView * button in buttons) {
        if (!button.isHidden) {
            buttonsWidth += (button.frame.size.width + stackViewSpacing);
        }
    }
    return buttonsWidth;
}

- (void)updateInfoSize {
    auto viewSize = self.frame.size;
    if (self.frame.size.width == 0 || self.frame.size.height == 0) {
        return;
    }
    if (self.frame.size.width < minWidthConst || self.frame.size.height < minHeightConst) {
        [self setMinButtonsSize];
        self.usernameLabel.font = [NSFont userFontOfSize: 11.0];
    } else {
        [self setMaxButtonsSize];
        self.usernameLabel.font = [NSFont userFontOfSize: 12.0];
    }
    [self.usernameLabel sizeToFit];
    auto labelFrame = self.usernameLabel.frame;
    auto buttonsWidth = [self getButtonsWidth];
    // not moderatator, does not have action button
    if (buttonsWidth == 0) {
        if (labelFrame.size.width > (viewSize.width - stackViewSpacing * 2)) {
            labelFrame.size.width = viewSize.width - margin * 2;
        }
        auto deltaH = viewSize.height - self.backgroundView.frame.size.height;
        self.fullViewOverlay = (deltaH < 30);
        if (self.fullViewOverlay) {
            minWidth = viewSize.width + margin;
            minHeight = viewSize.height + margin;
            self.minWidthConstraint.constant = minWidth;
            self.minHeightConstraint.constant = minHeight;
            auto overWidth = (minWidth - viewSize.width) * 0.5;
            self.infoLeadingConstraint.constant = overWidth - stackViewSpacing * 2;
        } else {
            self.infoLeadingConstraint.constant = -stackViewSpacing * 2;
        }
        [self.usernameLabel sizeToFit];
        self.nameLabelWidth.constant = labelFrame.size.width;
        return;
    }
    auto buttonsSize = self.buttonsContainer.frame.size;
    if ((labelFrame.size.width + (margin * 2)) > viewSize.width) {
        labelFrame.size.width = viewSize.width - margin * 2;
    }
    self.nameLabelWidth.constant = labelFrame.size.width;
    if ((labelFrame.size.width + buttonsWidth + margin * 2) < (viewSize.width - stackViewSpacing * 2)) {
        self.infoContainer.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        self.infoContainer.alignment = NSLayoutAttributeCenterY;
        self.infoContainer.spacing = stackViewSpacing * 3;
    } else {
        self.infoContainer.orientation = NSUserInterfaceLayoutOrientationVertical;
        self.infoContainer.spacing = stackViewSpacing;
        self.infoContainer.alignment = NSLayoutAttributeLeft;
    }
    [self.superview layoutSubtreeIfNeeded];
    auto deltaH = viewSize.height - self.backgroundView.frame.size.height;
    self.fullViewOverlay = (deltaH < 30);
    if (self.fullViewOverlay) {
        minWidth = MAX(MAX((viewSize.width + margin), (buttonsWidth + margin)), minWidthConst);
        self.nameLabelWidth.constant = minWidth - margin * 2;
        minHeight = MAX((viewSize.height + margin * 2), (self.infoContainer.frame.size.height + margin * 2));
        self.minWidthConstraint.constant = minWidth;
        self.minHeightConstraint.constant = minHeight;
        self.nameLabelWidth.constant = minWidth - margin * 2;
        self.infoContainer.orientation = NSUserInterfaceLayoutOrientationVertical;
        self.infoContainer.spacing = stackViewSpacing;
        auto overWidth = (minWidth - viewSize.width) * 0.5;
        self.infoLeadingConstraint.constant = overWidth - stackViewSpacing * 2;
    } else {
        self.infoLeadingConstraint.constant = -stackViewSpacing * 2;
    }
}

- (void)viewSizeChanged {
    [self sizeChanged];
    [self updateInfoSize];
}

- (void)addViews {
    self.increasedBackgroundView = [[NSView alloc] init];
    [self.increasedBackgroundView setWantsLayer:  YES];
    self.increasedBackgroundView.layer.backgroundColor = [[NSColor colorWithCalibratedRed: 0 green: 0 blue: 0 alpha: 0.8] CGColor];
    self.increasedBackgroundView.translatesAutoresizingMaskIntoConstraints = false;
    self.increasedBackgroundView.hidden = true;
    self.increasedBackgroundView.layer.masksToBounds = true;
    self.increasedBackgroundView.layer.cornerRadius = cornerRadius;

    self.backgroundView = [[NSView alloc] init];
    [self.backgroundView setWantsLayer:  YES];
    self.backgroundView.layer.backgroundColor = [[NSColor colorWithCalibratedRed: 0 green: 0 blue: 0 alpha: 0.6] CGColor];
    self.backgroundView.translatesAutoresizingMaskIntoConstraints = false;
    self.backgroundView.hidden = true;
    self.backgroundView.wantsLayer = true;
    self.backgroundView.layer.cornerRadius = cornerRadius;
    self.backgroundView.layer.maskedCorners = kCALayerMaxXMinYCorner;
    self.backgroundView.layer.masksToBounds = false;

    //participat state
    self.audioState = [self getStateView];
    NSImage* audioImage = [NSImage imageNamed: @"ic_moderator_audio_muted.png"];
    self.audioState.image = audioImage;
    self.audioState.layer.cornerRadius = cornerRadius;
    self.audioState.toolTip = NSLocalizedString(@"Audio muted", @"conference state tooltip Audio muted");

    self.moderatorState = [self getStateView];
    NSImage* moderatorImage = [NSImage imageNamed: @"ic_moderator.png"];
    self.moderatorState.image = moderatorImage;
    self.moderatorState.toolTip = NSLocalizedString(@"Moderator", @"conference state tooltip moderator");

    self.hostState = [self getStateView];
    NSImage* hostImage = [NSImage imageNamed: @"ic_star.png"];
    self.hostState.image = hostImage;
    self.hostState.toolTip = NSLocalizedString(@"Conference Organiser", @"conference state tooltip organiser");

    NSArray *statesViews = [NSArray arrayWithObjects: self.hostState, self.moderatorState, self.audioState, nil];
    self.states = [NSStackView stackViewWithViews: statesViews];
    self.states.spacing = 0;
    [self addSubview: self.states];
    [self addSubview: self.increasedBackgroundView];
    [self addSubview: self.backgroundView];

    //actions
    self.maximize = [self getActionbutton];
    NSImage* maximizeImage = [NSImage imageNamed: @"ic_moderator_maximize.png"];
    self.maximize.toolTip = NSLocalizedString(@"Expand", @"conference tooltip Expand");
    [self.maximize setImage: maximizeImage];
    [self.maximize setAction:@selector(maximize:)];
    [self.maximize setTarget:self];

    self.minimize = [self getActionbutton];
    NSImage* minimizeImage = [NSImage imageNamed: @"ic_moderator_minimize.png"];
    self.minimize.toolTip = NSLocalizedString(@"Minimize", @"conference tooltip Minimize");
    [self.minimize setImage: minimizeImage];
    [self.minimize setAction:@selector(minimize:)];
    [self.minimize setTarget:self];

    self.hangup = [self getActionbutton];
    NSImage* hangupImage = [NSImage imageNamed: @"ic_moderator_hangup.png"];
    self.hangup.toolTip = NSLocalizedString(@"Hangup", @"conference tooltip Hangup");
    [self.hangup setImage: hangupImage];
    [self.hangup setAction:@selector(finishCall:)];
    [self.hangup setTarget:self];

    self.setModerator = [self getActionbutton];
    NSImage* setModeratorImage = [NSImage imageNamed: @"ic_moderator.png"];
    self.setModerator.toolTip = NSLocalizedString(@"Set moderator", @"conference tooltip Set moderator");
    [self.setModerator setImage: setModeratorImage];
    [self.setModerator setAction:@selector(setModerator:)];
    [self.setModerator setTarget:self];

    self.muteAudio = [self getActionbutton];
    NSImage* muteAudioImage = [NSImage imageNamed: @"ic_moderator_audio_muted.png"];
    self.muteAudio.toolTip = NSLocalizedString(@"Mute audio", @"conference tooltip Mute audio");
    [self.muteAudio setImage: muteAudioImage];
    [self.muteAudio setAction:@selector(muteAudio:)];
    [self.muteAudio setTarget:self];

    NSArray *actions = [NSArray arrayWithObjects: self.setModerator, self.muteAudio, self.maximize, self.minimize, self.hangup, nil];
    self.buttonsContainer = [NSStackView stackViewWithViews: actions];
    self.buttonsContainer.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.buttonsContainer.spacing = stackViewSpacing;

    self.usernameLabel = [[NSTextField alloc] init];
    self.usernameLabel.alignment = NSTextAlignmentLeft;
    self.usernameLabel.textColor = [NSColor whiteColor];
    self.usernameLabel.editable = false;
    self.usernameLabel.bordered = false;
    self.usernameLabel.drawsBackground = false;
    self.usernameLabel.font = [NSFont userFontOfSize: 12.0];
    self.usernameLabel.translatesAutoresizingMaskIntoConstraints = true;
    [self.usernameLabel.heightAnchor constraintEqualToConstant: 15].active = true;
    self.nameLabelWidth = [self.usernameLabel.widthAnchor constraintEqualToConstant: 10];
    self.nameLabelWidth.active = true;
    self.usernameLabel.maximumNumberOfLines = 1;
    self.usernameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.usernameLabel.layer.masksToBounds = true;

    NSArray* infoItems = [NSArray arrayWithObjects: self.usernameLabel, self.buttonsContainer, nil];

    self.infoContainer = [NSStackView stackViewWithViews: infoItems];
    self.infoContainer.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.infoContainer.spacing = stackViewSpacing * 3;
    self.infoContainer.alignment = NSLayoutAttributeCenterY;
    [self.backgroundView addSubview: self.infoContainer];
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
    button.imageInsets = buttonMargin;
    button.translatesAutoresizingMaskIntoConstraints = false;
    return button;
}

- (CustomBackgroundView*) getStateView {
    CustomBackgroundView *state = [[CustomBackgroundView alloc] init];
    state.wantsLayer = true;
    state.layer.cornerRadius = 0;
    state.layer.maskedCorners = kCALayerMaxXMaxYCorner;
    state.layer.backgroundColor = [[NSColor colorWithCalibratedRed: 0 green: 0 blue: 0 alpha: 0.6] CGColor];
    [state.widthAnchor constraintEqualToConstant: controlSize].active = true;
    [state.heightAnchor constraintEqualToConstant: controlSize].active = true;
    return state;
}

- (void)configureView {
    [self.backgroundView.topAnchor constraintEqualToAnchor:self.topAnchor].active = true;
    [self.backgroundView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor].active = true;
    self.infoLeadingConstraint = [self.backgroundView.leadingAnchor constraintEqualToAnchor:self.infoContainer.leadingAnchor constant: -stackViewSpacing * 2];
    self.infoLeadingConstraint.active = true;
    [self.backgroundView.trailingAnchor constraintEqualToAnchor:self.infoContainer.trailingAnchor constant: stackViewSpacing * 2].active = true;
    [self.infoContainer.topAnchor constraintEqualToAnchor:self.backgroundView.topAnchor constant: stackViewSpacing].active = true;
    [self.backgroundView.heightAnchor constraintEqualToAnchor:self.infoContainer.heightAnchor constant: stackViewSpacing * 2].active = true;

    [self.states.bottomAnchor constraintEqualToAnchor:self.bottomAnchor].active = true;
    [self.states.leadingAnchor constraintEqualToAnchor:self.leadingAnchor].active = true;

    [self.increasedBackgroundView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:1].active = true;
    [self.increasedBackgroundView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor constant:1].active = true;
    self.minWidthConstraint = [self.increasedBackgroundView.widthAnchor constraintEqualToConstant:minWidth];
    self.minHeightConstraint = [self.increasedBackgroundView.heightAnchor constraintEqualToConstant:minHeight];
    self.minWidthConstraint.active = true;
    self.minHeightConstraint.active = true;
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
    [self sizeChanged];
    self.usernameLabel.stringValue = self.participant.bestName;
    [self updateButtonsState];
    [self updateInfoSize];
}

-(void) updateButtonsState {
    bool audioMuted = self.participant.audioModeratorMuted || self.participant.audioLocalMuted;
    self.audioState.hidden = !audioMuted;
    self.moderatorState.hidden = !self.participant.isModerator || [self.delegate isParticipantHost: self.participant.uri];
    self.hostState.hidden = ![self.delegate isParticipantHost: self.participant.uri];
    auto radius = self.audioState.hidden ? cornerRadius : 0;
    if (!self.moderatorState.hidden) {
        self.moderatorState.layer.cornerRadius = radius;
    }
    if (!self.hostState.hidden) {
        self.hostState.layer.cornerRadius = radius;
    }
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
    self.setModerator.hidden = !showConferenceHostOnly;
    self.hangup.hidden = !hangupEnabled;
    self.minimize.hidden = !showMinimized;
    self.maximize.hidden = !showMaximized;
    NSImage* muteAudioImage = audioMuted ? [NSImage imageNamed: @"ic_moderator_audio_muted.png"] :
    [NSImage imageNamed: @"ic_moderator_audio_unmuted.png"];
    [self.muteAudio setImage: muteAudioImage];
    self.muteAudio.hidden = self.participant.audioLocalMuted;
}

-(void)mouseEntered:(NSEvent *)theEvent {
    [self showOverlay];
    self.mouseInside = true;
    [super mouseEntered:theEvent];
}

-(void)mouseExited:(NSEvent *)theEvent {
    [self hideOverlay];
    self.mouseInside = false;
    [super mouseExited:theEvent];
}

-(void) hideOverlay {
    self.backgroundView.hidden = YES;
    self.increasedBackgroundView.hidden = true;
    self.backgroundView.layer.backgroundColor = [[NSColor colorWithCalibratedRed: 0 green: 0 blue: 0 alpha: 0.6] CGColor];
    self.states.hidden = false;
    self.timeoutTimer.invalidate;
    self.timeoutTimer = nil;
}

-(void) showOverlay {
    self.backgroundView.hidden = NO;
    auto labelFrame = self.usernameLabel.frame;
    auto viewSize = self.frame.size;
    if (self.fullViewOverlay) {
        self.increasedBackgroundView.hidden = false;
        self.backgroundView.layer.backgroundColor = [[NSColor clearColor] CGColor];
        self.states.hidden = true;
    }
    self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval: 5
                                                    target:self
                                                  selector:@selector(hideOverlay) userInfo:nil
                                                   repeats:NO];
}

- (void)mouseMoved:(NSEvent *)event {
    [super mouseMoved: event];
    if (!self.backgroundView.hidden) {
        return;
    }
    if (self.mouseInside) {
        [self showOverlay];
    }
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
                        | NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved owner:self userInfo:nil];
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
