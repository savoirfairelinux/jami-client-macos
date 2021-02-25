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

CGFloat const margin = 2;
CGFloat const controlSize = 25;
CGFloat const minWidth = 140;
CGFloat const minHeight = 80;

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = false;
        [self setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable | NSViewMinYMargin | NSViewMaxYMargin | NSViewMinXMargin | NSViewMaxXMargin];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sizeChanged) name:NSWindowDidResizeNotification object:nil];
        self.wantsLayer = true;
        self.layer.masksToBounds = false;
        [self addViews];
    }
    return self;
}

- (void)addViews {
    self.increasedBackgroundView = [[NSView alloc] init];
    [self.increasedBackgroundView setWantsLayer:  YES];
    self.increasedBackgroundView.layer.backgroundColor = [[NSColor colorWithCalibratedRed: 0 green: 0 blue: 0 alpha: 0.8] CGColor];
    self.increasedBackgroundView.translatesAutoresizingMaskIntoConstraints = false;
    [self addSubview: self.increasedBackgroundView];
    self.increasedBackgroundView.hidden = true;
    self.increasedBackgroundView.layer.masksToBounds = true;
    self.increasedBackgroundView.layer.cornerRadius = 6;
    
    self.backgroundView = [[NSView alloc] init];
    [self.backgroundView setWantsLayer:  YES];
    self.backgroundView.layer.backgroundColor = [[NSColor colorWithCalibratedRed: 0 green: 0 blue: 0 alpha: 0.6] CGColor];
    self.backgroundView.translatesAutoresizingMaskIntoConstraints = false;
    [self addSubview: self.backgroundView];
    self.backgroundView.hidden = true;
    
    //participat state
    self.audioState = [[CustomBackgroundView alloc] init];
    self.audioState.wantsLayer = true;
    self.audioState.layer.cornerRadius = 6;
    self.audioState.layer.backgroundColor = [[NSColor colorWithCalibratedRed: 0 green: 0 blue: 0 alpha: 0.8] CGColor];
    self.backgroundView.layer.maskedCorners = kCALayerMaxXMaxYCorner;
    //self.audioState.backgroundType = RECTANGLE_WITH_ROUNDED_RIGHT_CORNER;
    [self.audioState.widthAnchor constraintEqualToConstant: controlSize].active = true;
    [self.audioState.heightAnchor constraintEqualToConstant: controlSize].active = true;
    NSImage* audioImage = [NSImage imageNamed: @"ic_moderator_audio_muted.png"];
    self.audioState.image = audioImage;
    
    self.moderatorState = [[CustomBackgroundView alloc] init];
    self.moderatorState.wantsLayer = true;
    self.moderatorState.layer.cornerRadius = 0;
    self.moderatorState.layer.maskedCorners = kCALayerMaxXMaxYCorner;
    self.moderatorState.layer.backgroundColor = [[NSColor colorWithCalibratedRed: 0 green: 0 blue: 0 alpha: 0.8] CGColor];
    //self.moderatorState.backgroundType = RECTANGLE;
    [self.moderatorState.widthAnchor constraintEqualToConstant: controlSize].active = true;
    [self.moderatorState.heightAnchor constraintEqualToConstant: controlSize].active = true;
    NSImage* moderatorImage = [NSImage imageNamed: @"ic_moderator.png"];
    self.moderatorState.image = moderatorImage;
    
    self.hostState = [[CustomBackgroundView alloc] init];
    self.hostState.wantsLayer = true;
    self.hostState.layer.cornerRadius = 0;
    self.hostState.layer.maskedCorners = kCALayerMaxXMaxYCorner;
    self.hostState.layer.backgroundColor = [[NSColor colorWithCalibratedRed: 0 green: 0 blue: 0 alpha: 0.8] CGColor];
    //self.hostState.backgroundType = RECTANGLE;
    [self.hostState.widthAnchor constraintEqualToConstant: controlSize].active = true;
    [self.hostState.heightAnchor constraintEqualToConstant: controlSize].active = true;
    NSImage* hostImage = [NSImage imageNamed: @"ic_star.png"];
    self.hostState.image = hostImage;
    
    NSArray *statesViews = [NSArray arrayWithObjects: self.hostState, self.moderatorState, self.audioState, nil];
    self.states = [NSStackView stackViewWithViews: statesViews];
    self.states.spacing = 0;
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
    
    self.usernameLabel = [[NSTextField alloc] init];
    self.usernameLabel.alignment = NSTextAlignmentLeft;
    self.usernameLabel.textColor = [NSColor whiteColor];
    self.usernameLabel.editable = false;
    self.usernameLabel.bordered = false;
    self.usernameLabel.drawsBackground = false;
    self.usernameLabel.backgroundColor = [NSColor blackColor];
    self.usernameLabel.font = [NSFont userFontOfSize: 13.0];
    self.usernameLabel.translatesAutoresizingMaskIntoConstraints = false;
    [self.usernameLabel.heightAnchor constraintEqualToConstant: 20].active = true;
    [self.usernameLabel.widthAnchor constraintGreaterThanOrEqualToConstant: 20].active = true;
    self.usernameLabel.maximumNumberOfLines = 1;
    self.usernameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    
    NSArray* infoItems = [NSArray arrayWithObjects: self.usernameLabel, self.buttonsContainer, nil];
    
    self.infoContainer = [NSStackView stackViewWithViews: infoItems];
    self.infoContainer.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.infoContainer.spacing = 5;
   // self.infoContainer.distribution = NSStackViewDistributionFillEqually;
    //self.infoContainer.alignment = NSLayoutAttributeCenterX;
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
    button.imageInsets = margin;
    button.translatesAutoresizingMaskIntoConstraints = false;
    return button;
}

- (void)configureView {
    [self.backgroundView.topAnchor constraintEqualToAnchor:self.topAnchor].active = true;
    [self.backgroundView.leadingAnchor constraintEqualToAnchor:self.infoContainer.leadingAnchor constant:-5].active = true;
    [self.backgroundView.trailingAnchor constraintEqualToAnchor:self.infoContainer.trailingAnchor constant:5].active = true;
    [self.backgroundView.heightAnchor constraintEqualToAnchor:self.infoContainer.heightAnchor constant:10].active = true;
   // [self.backgroundView.widthAnchor constraintEqualToAnchor:self.infoContainer.widthAnchor].active = true;
    
    self.backgroundView.wantsLayer = true;
    self.backgroundView.layer.cornerRadius = 6;
    self.backgroundView.layer.maskedCorners = kCALayerMaxXMinYCorner;
    
    [self.states.bottomAnchor constraintEqualToAnchor:self.bottomAnchor].active = true;
    [self.states.leadingAnchor constraintEqualToAnchor:self.leadingAnchor].active = true;
    
    [self.infoContainer.topAnchor constraintEqualToAnchor:self.backgroundView.topAnchor constant:5].active = true;
    [self.backgroundView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor].active = true;
    
    [self.increasedBackgroundView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:1].active = true;
    [self.increasedBackgroundView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor constant:1].active = true;
    [self.increasedBackgroundView.widthAnchor constraintEqualToConstant:minWidth].active = true;
    [self.increasedBackgroundView.heightAnchor constraintEqualToConstant:minHeight].active = true;
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
    [self updateButtonsState];
}

-(void) updateButtonsState {
    self.usernameLabel.stringValue = self.participant.bestName;
   // self.usernameLabel.needsUpdateConstraints = true;
    [self.usernameLabel sizeToFit];
    auto size = self.usernameLabel.frame.size;
    bool audioMuted = self.participant.audioModeratorMuted || self.participant.audioLocalMuted;
    self.audioState.hidden = !audioMuted;
    self.moderatorState.hidden = !self.participant.isModerator || [self.delegate isParticipantHost: self.participant.uri];
    self.hostState.hidden = ![self.delegate isParticipantHost: self.participant.uri];
    auto radius = self.audioState.hidden ? 6 : 0;
    if (!self.moderatorState.hidden) {
        self.moderatorState.layer.cornerRadius = radius;
        //self.moderatorState.backgroundType = type;
        //[self.moderatorState setNeedsDisplay:YES];
    }
    if (!self.hostState.hidden) {
        self.hostState.layer.cornerRadius = radius;
       // [self.hostState setNeedsDisplay:YES];
    }
    bool couldManageConference = [self.delegate isMasterCall] || [self.delegate isCallModerator];
    self.buttonsContainer.hidden = !couldManageConference;
    if (!couldManageConference) {
        return;
    }
    int layout = [self.delegate getCurrentLayout];
    if (layout < 0)
        return;
    auto size1 = self.frame.size;
    if (size1.width > minWidth && size1.height > minHeight) {
        auto nameWidth = self.usernameLabel.frame.size.width;
        auto buttonsWidth = self.buttonsContainer.frame.size.width;
        if (nameWidth + buttonsWidth < (size1.width - 10)) {
            self.infoContainer.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        } else {
            self.infoContainer.orientation = NSUserInterfaceLayoutOrientationVertical;
        }
    }
   
    BOOL showConferenceHostOnly = !self.participant.isLocal && [self.delegate isMasterCall];
    BOOL hangupEnabled = ![self.delegate isParticipantHost: self.participant.uri];
    BOOL showMaximized = layout != 2;
    BOOL showMinimized = !(layout == 0 || (layout == 1 && !self.participant.active));
    self.setModerator.enabled = showConferenceHostOnly;
    self.hangup.enabled = hangupEnabled;
    self.minimize.hidden = !showMinimized;
    self.maximize.hidden = !showMaximized;
    NSImage* muteAudioImage = audioMuted ? [NSImage imageNamed: @"ic_moderator_audio_muted.png"] :
    [NSImage imageNamed: @"ic_moderator_audio_unmuted.png"];
    [self.muteAudio setImage: muteAudioImage];
    self.muteAudio.enabled = !self.participant.audioLocalMuted;
}

-(void)mouseEntered:(NSEvent *)theEvent {
    self.backgroundView.hidden = NO;
    auto size1 = self.frame.size;
    if (size1.width < minWidth && size1.height < minHeight) {
        self.increasedBackgroundView.hidden = false;
        self.backgroundView.layer.backgroundColor = [[NSColor clearColor] CGColor];
        self.states.hidden = true;
        self.infoContainer.orientation = NSUserInterfaceLayoutOrientationVertical;
    }
    [super mouseEntered:theEvent];
    self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:5
                                                    target:self
                                                  selector:@selector(mouseNotMoving) userInfo:nil
                                                   repeats:NO];
}

-(void) mouseNotMoving {
    self.backgroundView.hidden = YES;
    self.increasedBackgroundView.hidden = true;
    self.backgroundView.layer.backgroundColor = [[NSColor colorWithCalibratedRed: 0 green: 0 blue: 0 alpha: 0.6] CGColor];
    self.states.hidden = false;
    self.timeoutTimer.invalidate;
    self.timeoutTimer = nil;
}

-(void)mouseExited:(NSEvent *)theEvent {
    self.backgroundView.hidden = YES;
    self.increasedBackgroundView.hidden = true;
    self.backgroundView.layer.backgroundColor = [[NSColor colorWithCalibratedRed: 0 green: 0 blue: 0 alpha: 0.6] CGColor];
    self.states.hidden = false;
    self.states.hidden = false;
    self.timeoutTimer.invalidate;
    [super mouseExited:theEvent];
}

- (void)mouseMoved:(NSEvent *)event {
    [super mouseMoved: event];
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
