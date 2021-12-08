/*
 *  Copyright (C) 2015-2016 Savoir-faire Linux Inc.
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
#import "CurrentCallVC.h"
extern "C" {
#import "libavutil/frame.h"
#import "libavutil/display.h"
}

#import <QuartzCore/QuartzCore.h>

///Qt
#import <QMimeData>
#import <QtMacExtras/qmacfunctions.h>
#import <QtCore/qabstractitemmodel.h>
#import <QPixmap>
#import <QUrl>

///LRC
#import <video/renderer.h>
#import <api/newcallmodel.h>
#import <api/call.h>
#import <api/conversationmodel.h>
#import <api/avmodel.h>
#import <api/pluginmodel.h>
#import <globalinstances.h>

#import "AppDelegate.h"
#import "views/ITProgressIndicator.h"
#import "views/CallView.h"
#import "views/NSColor+RingTheme.h"
#import "delegates/ImageManipulationDelegate.h"
#import "ChatVC.h"
#import "views/IconButton.h"
#import "views/HoverButton.h"
#import "utils.h"
#import "views/CallMTKView.h"
#import "VideoCommon.h"
#import "views/GradientView.h"
#import "views/MovableView.h"
#import "views/RenderingView.h"
#import "ChooseMediaVC.h"
#import "ChangeAudioVolumeVC.h"

@interface CurrentCallVC () <NSPopoverDelegate> {
    QString convUid_;
    QString callUid_;
    QString confUid_;
    QString currentRenderer_;
    const lrc::api::account::Info *accountInfo_;
    lrc::api::PluginModel *pluginModel_;
    NSTimer* refreshDurationTimer;
}

typedef enum {
    audioInputDevices = 1,
    audioOutputDevices,
    videoDevices,
    share,
    changeAudioInputVolume,
    changeAudioOutputVolume,
    addParticipant
} PopoverType;

// Main container
@property (unsafe_unretained) IBOutlet NSSplitView* splitView;
@property (unsafe_unretained) IBOutlet NSView* backgroundImage;
@property (unsafe_unretained) IBOutlet NSBox* bluerBackgroundEffect;

// Header info
@property (unsafe_unretained) IBOutlet NSView* headerContainer;
@property (unsafe_unretained) IBOutlet NSView* headerGradientView;
@property (unsafe_unretained) IBOutlet NSTextField* timeSpentLabel;

// info
@property (unsafe_unretained) IBOutlet NSStackView* infoContainer;
@property (unsafe_unretained) IBOutlet NSImageView* contactPhoto;
@property (unsafe_unretained) IBOutlet NSTextField* contactNameLabel;
@property (unsafe_unretained) IBOutlet NSTextField* callStateLabel;
@property (unsafe_unretained) IBOutlet NSTextField* contactIdLabel;
@property (unsafe_unretained) IBOutlet IconButton* cancelCallButton;
@property (unsafe_unretained) IBOutlet IconButton* pickUpButton;
@property (unsafe_unretained) IBOutlet IconButton* pickUpButtonAudioOnly;
@property (unsafe_unretained) IBOutlet ITProgressIndicator *loadingIndicator;

// Call Controls
@property (unsafe_unretained) IBOutlet GradientView* controlsPanel;
@property (unsafe_unretained) IBOutlet NSStackView* controlsStackView;

@property (unsafe_unretained) IBOutlet IconButton* holdOnOffButton;
@property (unsafe_unretained) IBOutlet IconButton* hangUpButton;
@property (unsafe_unretained) IBOutlet IconButton* recordOnOffButton;
@property (unsafe_unretained) IBOutlet HoverButton* muteAudioButton;
@property (unsafe_unretained) IBOutlet HoverButton* muteVideoButton;
@property (unsafe_unretained) IBOutlet IconButton* addParticipantButton;
@property (unsafe_unretained) IBOutlet IconButton* pluginButton;
@property (unsafe_unretained) IBOutlet IconButton* chatButton;
@property (unsafe_unretained) IBOutlet IconButton* shareButton;
@property (unsafe_unretained) IBOutlet IconButton* audioOutputButton;
@property (unsafe_unretained) IBOutlet IconButton* inputAudioMenuButton;
@property (unsafe_unretained) IBOutlet IconButton* outputAudioMenuButton;
@property (unsafe_unretained) IBOutlet IconButton* videoMenuButton;
@property (unsafe_unretained) IBOutlet IconButton* mozaicLayoutButton;
@property (unsafe_unretained) IBOutlet NSView* mozaicLayoutView;

// Video
@property (unsafe_unretained) IBOutlet CallView *videoView;
@property (unsafe_unretained) IBOutlet RenderingView *previewView;
@property (unsafe_unretained) IBOutlet MovableView *movableBaseForView;
@property (unsafe_unretained) IBOutlet NSView* hidePreviewBackground;
@property (unsafe_unretained) IBOutlet NSButton* hidePreviewButton;
@property (unsafe_unretained) IBOutlet RenderingView *distantView;

@property RendererConnectionsHolder* renderConnections;
@property QMetaObject::Connection videoStarted;
@property QMetaObject::Connection callStateChanged;
@property QMetaObject::Connection callInfosChanged;
@property QMetaObject::Connection messageConnection;
@property QMetaObject::Connection profileUpdatedConnection;
@property QMetaObject::Connection participantsChangedConnection;
@property QMetaObject::Connection pluginButtonVisibilityChange;
@property QMetaObject::Connection videoDeviceEvent;
@property QMetaObject::Connection audioDeviceEvent;

//conference
@property (unsafe_unretained) IBOutlet NSStackView *callingWidgetsContainer;

@property (strong) NSPopover* brokerPopoverVC;

@property (strong) IBOutlet ChatVC* chatVC;

@end

@implementation CurrentCallVC
lrc::api::AVModel* mediaModel;
lrc::api::PluginModel* pluginModel_;
NSMutableDictionary *connectingCalls;
NSMutableDictionary *participantsOverlays;
NSSize framesize;

NSInteger const PREVIEW_WIDTH = 185;
NSInteger const PREVIEW_HEIGHT = 130;
NSInteger const HIDE_PREVIEW_BUTTON_SIZE = 25;
NSInteger const PREVIEW_MARGIN = 20;
BOOL allModeratorsInConference = false;
BOOL displayGridLayoutButton = false;

@synthesize holdOnOffButton, hangUpButton, recordOnOffButton, pickUpButton, pickUpButtonAudioOnly, chatButton, addParticipantButton, timeSpentLabel, muteVideoButton, muteAudioButton, controlsPanel, headerContainer, videoView, previewView, splitView, loadingIndicator, backgroundImage, bluerBackgroundEffect, hidePreviewButton, hidePreviewBackground, movableBaseForView, infoContainer, contactPhoto, contactNameLabel, callStateLabel, contactIdLabel, cancelCallButton, headerGradientView, controlsStackView, callingWidgetsContainer, brokerPopoverVC, audioOutputButton, inputAudioMenuButton, outputAudioMenuButton, videoMenuButton, pluginButton, shareButton;

@synthesize renderConnections;
CVPixelBufferPoolRef pixelBufferPoolDistantView;
CVPixelBufferRef pixelBufferDistantView;
CVPixelBufferPoolRef pixelBufferPoolPreview;
CVPixelBufferRef pixelBufferPreview;

/* update call and conversation info
 * set info for chat view
 * connect signals
 */
-(void) setCurrentCall:(const QString&)callUid
          conversation:(const QString&)convUid
               account:(const lrc::api::account::Info*)account
               avModel:(lrc::api::AVModel *)avModel
           pluginModel:(lrc::api::PluginModel *)pluginModel;
{
    if(account == nil)
        return;

    mediaModel = avModel;
    pluginModel_ = pluginModel;
    auto* callModel = account->callModel.get();

    if (not callModel->hasCall(callUid)){
        callUid_.clear();
        confUid_.clear();
        return;
    }
    callUid_ = callUid;
    convUid_ = convUid;
    accountInfo_ = account;
    auto convOpt = getConversationFromUid(convUid_, *accountInfo_->conversationModel.get());
    if (!convOpt.has_value()) {
        return;
    }
    lrc::api::conversation::Info& conv = *convOpt;
    confUid_ = conv.confId;
    [self.chatVC setConversationUid:convUid model: account->conversationModel.get()];
    [self connectSignals];
}

-(void)updateConferenceOverlays:(QString)callID {
    auto* callModel = accountInfo_->callModel.get();
    auto call = callModel->getCall(callID);
    using Status = lrc::api::call::Status;
    switch (call.status) {
        case Status::ENDED:
        case Status::TERMINATING:
        case Status::INVALID:
        case Status::PEER_BUSY:
        case Status::TIMEOUT:
            if (participantsOverlays[call.peerUri.toNSString()] != nil) {
                [participantsOverlays[call.peerUri.toNSString()] removeFromSuperview];
                participantsOverlays[call.peerUri.toNSString()] = nil;
                if (![self isCurrentCall: callID]) {
                    [self updateCall];
                    [self setCurrentCall: callUid_ conversation:convUid_ account:accountInfo_ avModel:mediaModel pluginModel:pluginModel_];
                }
            }
            break;
    }
}

-(void)switchToNextConferenceCall:(QString)confId {
    auto* callModel = accountInfo_->callModel.get();
    AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
    auto activeCalls = [appDelegate getActiveCalls];
    if (activeCalls.isEmpty()) {
        return;
    }
    auto subcalls = callModel->getConferenceSubcalls(confId);
    QString callId;
    if (subcalls.isEmpty()) {
        for(auto subcall: activeCalls) {
            if(subcall != callUid_) {
                callId = subcall;
            }
        }
    } else {
        for(auto subcall: subcalls) {
            if(subcall != callUid_) {
                callId = subcall;
            }
        }
    }
    if (!callModel->hasCall(callId)) {
        return;
    }
    auto convOpt = getConversationFromCallId(callId, *accountInfo_->conversationModel);
    if (!convOpt.has_value()) {
        return;
    }
    lrc::api::conversation::Info& conversation = *convOpt;
    [self.delegate chooseConversation: conversation model:accountInfo_->conversationModel.get()];
}

-(void) connectSignals {
    auto* callModel = accountInfo_->callModel.get();
    auto* convModel = accountInfo_->conversationModel.get();
    QObject::disconnect(self.pluginButtonVisibilityChange);
    self.pluginButtonVisibilityChange == QObject::connect(pluginModel_,
                                                          &lrc::api::PluginModel::chatHandlerStatusUpdated,
                                                          [self](bool status) { // this should not be used
        if(pluginModel_->getPluginsEnabled() && pluginModel_->getCallMediaHandlers().size() != 0)
            [pluginButton setHidden:NO];
        else
            [pluginButton setHidden:YES];
    });
    QObject::disconnect(self.participantsChangedConnection);
    self.participantsChangedConnection = QObject::connect(callModel,
                                                          &lrc::api::NewCallModel::onParticipantsChanged,
                                                          [self](const QString& confId) {
        auto* callModel = accountInfo_->callModel.get();
        if (!callModel->hasCall(confId)) {
            return;
        }
        if ([self isCurrentCall: confId]) {
            [self updateConference];
        }
    });
    //monitor for updated call state
    QObject::disconnect(self.callStateChanged);
    self.callStateChanged = QObject::connect(callModel,
                                             &lrc::api::NewCallModel::callStatusChanged,
                                             [self](const QString& callId) {
        [self updateConferenceOverlays: callId];
        if ([self isCurrentCall: callId]) {
            [self updateCall];
        }
    });
    //monitor for updated call infos
    QObject::disconnect(self.callInfosChanged);
    self.callInfosChanged = QObject::connect(callModel,
                                             &lrc::api::NewCallModel::callInfosChanged,
                                             [self](const QString&, const QString& callId) {
        if ([self isCurrentCall: callId]) {
            if (accountInfo_ == nil)
                return;

            auto* callModel = accountInfo_->callModel.get();
            if (not callModel->hasCall(callUid_)) {
                return;
            }

            auto currentCall = callModel->getCall(callUid_);

            auto participants = currentCall.participantsInfos;

            movableBaseForView.hidden = currentCall.videoMuted || participants.size() > 0;
            [self setUpButtons: currentCall isRecording: (callModel->isRecording([self getcallID]) || mediaModel->getAlwaysRecord())];
        }
    });
    /* monitor media for messaging text messaging */
    QObject::disconnect(self.messageConnection);
    self.messageConnection = QObject::connect(convModel,
                                              &lrc::api::ConversationModel::interactionStatusUpdated,
                                              [self] (const QString& convUid,
                                                      const QString& msgId,
                                                      lrc::api::interaction::Info msg) {
                                                  if (msg.type == lrc::api::interaction::Type::TEXT) {
                                                      if(not [[self splitView] isSubviewCollapsed:[[[self splitView] subviews] objectAtIndex: 1]]){
                                                          return;
                                                      }
                                                      [self uncollapseRightView];
                                                  }
                                              });
    //monitor for updated profile
    QObject::disconnect(self.profileUpdatedConnection);
    self.profileUpdatedConnection =
    QObject::connect(accountInfo_->contactModel.get(),
                     &lrc::api::ContactModel::contactAdded,
                     [self](const QString &contactUri) {
        auto convOpt = getConversationFromUid(convUid_, *accountInfo_->conversationModel.get());
        if (!convOpt.has_value()) {
            return;
        }
        lrc::api::conversation::Info& conv = *convOpt;
        [contactPhoto setImage: [self getContactImageOfSize:120.0 withDefaultAvatar:YES]];
        [self.delegate conversationInfoUpdatedFor:convUid_];
        [self setBackground];
    });
    [self connectVideoSignals];
}

-(void) updatePendingCalls {
    for (NSView *view in callingWidgetsContainer.subviews) {
        view.removeFromSuperview;
    }
    NSDictionary * calls = connectingCalls[callUid_.toNSString()];
    for (NSViewController * callView in calls.allValues) {
       [self.callingWidgetsContainer addView: callView.view inGravity:NSStackViewGravityBottom];
    }
}

-(void) setUpButtons:(lrc::api::call::Info&)callInfo isRecording:(BOOL) isRecording {
    muteAudioButton.image = callInfo.audioMuted ? [NSImage imageNamed:@"micro_off.png"] :
    [NSImage imageNamed:@"micro_on.png"];
    NSColor* audioImageColor = callInfo.audioMuted ? [NSColor callButtonRedColor] : [NSColor whiteColor];
    [self updateColorForButton: muteAudioButton color: audioImageColor];
    NSColor* videoImageColor = callInfo.videoMuted ? [NSColor callButtonRedColor] : [NSColor whiteColor];
    [self updateColorForButton: muteVideoButton color: videoImageColor];
    muteVideoButton.image = callInfo.videoMuted ? [NSImage imageNamed:@"camera_off.png"] :
    [NSImage imageNamed:@"camera_on.png"];
    [shareButton setHidden: callInfo.isAudioOnly ? YES: NO];
    if (isRecording) {
        [recordOnOffButton startBlinkAnimationfrom:[NSColor buttonBlinkColorColor] to:[NSColor whiteColor] scaleFactor: 1 duration: 1.5];
    } else {
        [recordOnOffButton stopBlinkAnimation];
    }
}

- (void) setUpPreviewFrame {
    CGPoint previewOrigin = CGPointMake(self.videoView.frame.size.width - PREVIEW_WIDTH - PREVIEW_MARGIN, PREVIEW_MARGIN);
    movableBaseForView.frame = CGRectMake(previewOrigin.x, previewOrigin.y, PREVIEW_WIDTH, PREVIEW_HEIGHT);
    self.movableBaseForView.movable = true;
    previewView.frame = movableBaseForView.bounds;
    hidePreviewBackground.frame = [self frameForExpendPreviewButton];
    if ([hidePreviewButton respondsToSelector:@selector(contentTintColor)]) {
        hidePreviewButton.contentTintColor = [NSColor blackColor];
    }
}

- (void)awakeFromNib
{
    [self.view setWantsLayer:YES];

    renderConnections = [[RendererConnectionsHolder alloc] init];

    [loadingIndicator setColor:[NSColor whiteColor]];
    [loadingIndicator setNumberOfLines:200];
    [loadingIndicator setWidthOfLine:4];
    [loadingIndicator setLengthOfLine:4];
    [loadingIndicator setInnerMargin:59];

    [self.videoView setCallDelegate:self];
    [bluerBackgroundEffect setWantsLayer:YES];
    [backgroundImage setWantsLayer: YES];
    backgroundImage.layer.contentsGravity = kCAGravityResizeAspectFill;
    movableBaseForView.wantsLayer = YES;
    movableBaseForView.shadow = [[NSShadow alloc] init];
    movableBaseForView.layer.shadowOpacity = 0.6;
    movableBaseForView.layer.shadowColor = [[NSColor blackColor] CGColor];
    movableBaseForView.layer.shadowOffset = NSMakeSize(0, -3);
    movableBaseForView.layer.shadowRadius = 10;
    previewView.wantsLayer = YES;
    previewView.layer.cornerRadius = 5;
    previewView.layer.masksToBounds = true;
    hidePreviewBackground.wantsLayer = YES;
    hidePreviewBackground.layer.cornerRadius = 5;
    hidePreviewBackground.layer.maskedCorners = kCALayerMinXMinYCorner;
    hidePreviewBackground.layer.masksToBounds = true;
    movableBaseForView.hostingView = self.videoView;
    [movableBaseForView setAutoresizingMask: NSViewNotSizable | NSViewMaxXMargin | NSViewMaxYMargin | NSViewMinXMargin | NSViewMinYMargin];
    [previewView setAutoresizingMask: NSViewNotSizable | NSViewMaxXMargin | NSViewMaxYMargin | NSViewMinXMargin | NSViewMinYMargin];
    connectingCalls = [[NSMutableDictionary alloc] init];
    participantsOverlays = [[NSMutableDictionary alloc] init];
}

-(void) updateDurationLabel
{
    if (accountInfo_ != nil) {
        auto* callModel = accountInfo_->callModel.get();
        if (callModel->hasCall(callUid_)) {
            auto& callStatus = callModel->getCall(callUid_).status;
            if (callStatus != lrc::api::call::Status::ENDED &&
                callStatus != lrc::api::call::Status::TERMINATING &&
                callStatus != lrc::api::call::Status::INVALID) {
                [timeSpentLabel setStringValue:callModel->getFormattedCallDuration(callUid_).toNSString()];
                return;
            }
        }
    }

    // If call is not running anymore or accountInfo_ is not set for any reason
    // we stop the refresh loop
    [refreshDurationTimer invalidate];
    refreshDurationTimer = nil;
}

-(void)removeConferenceLayout {
    for (ConferenceOverlayView* overlay: [participantsOverlays allValues]) {
        [overlay removeFromSuperview];
    }
    participantsOverlays = [[NSMutableDictionary alloc] init];
    allModeratorsInConference = false;
    movableBaseForView.hidden = false;
    displayGridLayoutButton = false;
}

-(void)updateConference
{
    auto confId = [self getcallID];
    if (confId.isEmpty()) {
        [self removeConferenceLayout];
        return;
    }
    auto* callModel = accountInfo_->callModel.get();
    auto& call = callModel->getCall(confId);
    using Status = lrc::api::call::Status;
    auto participants = call.participantsInfos;
    if (participants.size() == 0 || call.status == Status::ENDED ||
        call.status == Status::TERMINATING || call.status == Status::INVALID) {
        [self removeConferenceLayout];
        return;
    }
    NSMutableArray* participantUrs = [[NSMutableArray alloc] init];
    BOOL allModerators = true;
    for (auto participant: participants) {
        if (participant["isModerator"] != "true" &&
            ![self isParticipantHost: participant["uri"].toNSString()]) {
            allModerators = false;
        }
    }
    displayGridLayoutButton = call.layout != lrc::api::call::Layout::GRID;
    movableBaseForView.hidden = true;
    allModeratorsInConference = allModerators;
    for (auto participant: participants) {
        ConferenceParticipant conferenceParticipant;
        conferenceParticipant.x = participant["x"].toFloat();
        conferenceParticipant.y = participant["y"].toFloat();
        conferenceParticipant.width = participant["w"].toFloat();
        conferenceParticipant.hight = participant["h"].toFloat();
        conferenceParticipant.uri = participant["uri"].toNSString();
        [participantUrs addObject:participant["uri"].toNSString()];
        conferenceParticipant.active = participant["active"] == "true";
        conferenceParticipant.isLocal = false;
        conferenceParticipant.bestName = participant["uri"].toNSString();
        if (accountInfo_->profileInfo.uri == participant["uri"]) {
            conferenceParticipant.isLocal = true;
            conferenceParticipant.bestName = NSLocalizedString(@"Me", @"Conference name");
        } else {
            try {
                auto contact = accountInfo_->contactModel->getContact(participant["uri"]);
                conferenceParticipant.bestName = bestNameForContact(contact);
            } catch (...) {}
        }
        conferenceParticipant.videoMuted = participant["videoMuted"] == "true";
        conferenceParticipant.audioLocalMuted = participant["audioLocalMuted"] == "true";
        conferenceParticipant.audioModeratorMuted = participant["audioModeratorMuted"] == "true";
        conferenceParticipant.isModerator = participant["isModerator"] == "true";
        if (participantsOverlays[conferenceParticipant.uri] != nil) {
            ConferenceOverlayView* overlay = participantsOverlays[conferenceParticipant.uri];
            overlay.framesize = framesize;
            [overlay updateViewWithParticipant: conferenceParticipant];
        } else {
            ConferenceOverlayView* overlay = [[ConferenceOverlayView alloc] init];
            overlay.framesize = framesize;
            overlay.delegate = self;
            [overlay configureView];
            [self.distantView addSubview: overlay];
            participantsOverlays[conferenceParticipant.uri] = overlay;
            [overlay updateViewWithParticipant: conferenceParticipant];
        }
    }
    auto keys = [participantsOverlays allKeys];
    for (auto key : keys) {
        if (![participantUrs containsObject:key]) {
            [participantsOverlays[key] removeFromSuperview];
            participantsOverlays[key] = nil;
        }
    }
    self.mozaicLayoutView.hidden = !displayGridLayoutButton;
    self.mozaicLayoutButton.enabled = displayGridLayoutButton;
}

-(void) updateCall
{
    if (accountInfo_ == nil)
        return;

    auto* callModel = accountInfo_->callModel.get();
    if (not callModel->hasCall(callUid_)) {
        return;
    }

    auto currentCall = callModel->getCall([self getcallID]);
    auto convOpt = getConversationFromUid(convUid_, *accountInfo_->conversationModel.get());
    if (!convOpt.has_value()) {
        return;
    }
    lrc::api::conversation::Info& conversation = *convOpt;
    NSString* bestName = bestNameForConversation(conversation, *accountInfo_->conversationModel);
    [contactNameLabel setStringValue:bestName];
    NSString* ringID = bestIDForConversation(conversation, *accountInfo_->conversationModel);
    if([bestName isEqualToString:ringID]) {
        ringID = @"";
    }
    [self updateLMediaListButtonsVisibility];
    [contactIdLabel setStringValue:ringID];
    [self setupContactInfo:contactPhoto];
    confUid_ = conversation.confId;
    [self updateConference];
    self.mozaicLayoutView.hidden = !displayGridLayoutButton;
    self.mozaicLayoutButton.enabled = displayGridLayoutButton;

    [timeSpentLabel setStringValue:callModel->getFormattedCallDuration(callUid_).toNSString()];
    if (refreshDurationTimer == nil)
        refreshDurationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                                target:self
                                                              selector:@selector(updateDurationLabel)
                                                              userInfo:nil
                                                               repeats:YES];
    [self setBackground];

    using Status = lrc::api::call::Status;

    [self setUpButtons: currentCall isRecording: (callModel->isRecording([self getcallID]) || mediaModel->getAlwaysRecord())];

    [videoView setShouldAcceptInteractions: currentCall.status == Status::IN_PROGRESS];
    NSString* incomingString = currentCall.isAudioOnly ? @"Incoming audio call" : @"Incoming video call";
    callStateLabel.stringValue = currentCall.status == Status::INCOMING_RINGING ? NSLocalizedString(incomingString, @"In call status info") : to_string(currentCall.status).toNSString();
    loadingIndicator.hidden = (currentCall.status == Status::SEARCHING ||
                               currentCall.status == Status::CONNECTING ||
                               currentCall.status == Status::OUTGOING_RINGING) ? NO : YES;
    pickUpButton.hidden = (currentCall.status == Status::INCOMING_RINGING) ? NO : YES;
    pickUpButton.image = currentCall.isAudioOnly ? [NSImage imageNamed:@"ic_action_call.png"] : [NSImage imageNamed:@"camera_on.png"];
    pickUpButtonAudioOnly.hidden = (currentCall.status == Status::INCOMING_RINGING) ? currentCall.isAudioOnly : YES;
    callStateLabel.hidden = (currentCall.status == Status::IN_PROGRESS) ? YES : NO;
    cancelCallButton.hidden = (currentCall.status == Status::IN_PROGRESS ||
                             currentCall.status == Status::PAUSED) ? YES : NO;
    cancelCallButton.image = (currentCall.status == Status::INCOMING_RINGING) ? [NSImage imageNamed:@"ic_action_cancel.png"] : [NSImage imageNamed:@"ic_action_hangup.png"];
    callingWidgetsContainer.hidden = (currentCall.status == Status::IN_PROGRESS) ? NO : YES;
    switch (currentCall.status) {
        case Status::SEARCHING:
        case Status::CONNECTING:
        case Status::OUTGOING_RINGING:
        case Status::INCOMING_RINGING:
            [infoContainer setHidden: NO];
            [headerContainer setHidden:YES];
            [headerGradientView setHidden:YES];
            [controlsPanel setHidden:YES];
            [controlsStackView setHidden:YES];
            [self.distantView fillWithBlack];
            [self.previewView fillWithBlack];
            [hidePreviewBackground setHidden:YES];
            [self.previewView setHidden: YES];
            [self.distantView setHidden: YES];
            self.previewView.videoRunning = NO;
            self.distantView.videoRunning = NO;
            [backgroundImage setHidden:NO];
            [bluerBackgroundEffect setHidden:NO];
            break;
        case Status::PAUSED:
            [infoContainer setHidden: NO];
            [headerContainer setHidden:NO];
            [headerGradientView setHidden:NO];
            [controlsPanel setHidden:NO];
            [controlsStackView setHidden:NO];
            [backgroundImage setHidden:NO];
            [bluerBackgroundEffect setHidden:NO];
            if(!currentCall.isAudioOnly) {
                [self.distantView fillWithBlack];
                [self.previewView fillWithBlack];
                [hidePreviewBackground setHidden:YES];
                [self.previewView setHidden: YES];
                [self.distantView setHidden: YES];
                self.previewView.videoRunning = NO;
                self.distantView.videoRunning = NO;
            }
            break;
        case Status::INACTIVE:
            if(currentCall.isAudioOnly) {
                [self setUpAudioOnlyView];
            } else {
                [self setUpVideoCallView];
            }
            break;
        case Status::IN_PROGRESS:
            callModel->setCurrentCall([self getcallID]);
            [headerContainer setHidden:NO];
            [headerGradientView setHidden:NO];
            [controlsPanel setHidden:NO];
            if(!pluginModel_->getPluginsEnabled() || pluginModel_->getCallMediaHandlers().size() == 0)
                [pluginButton setHidden:YES];
            [controlsStackView setHidden:NO];
            if(currentCall.isAudioOnly) {
                [self setUpAudioOnlyView];
            } else {
                [self setUpVideoCallView];
            }
            break;
        case Status::CONNECTED:
            break;
        case Status::ENDED:
        case Status::TERMINATING:
        case Status::INVALID:
        case Status::PEER_BUSY:
        case Status::TIMEOUT:
            connectingCalls[callUid_.toNSString()] = nil;
            [self.delegate callFinished];
            [self removeConferenceLayout];
            [self switchToNextConferenceCall: confUid_];
            AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
            [appDelegate restoreScreenSleep];
            break;
    }
}

-(void) setUpVideoCallView {
    [previewView fillWithBlack];
    [self.distantView fillWithBlack];
    [backgroundImage setHidden:YES];
    [previewView setHidden: NO];
    [self.distantView setHidden:NO];
    [hidePreviewBackground setHidden: !self.previewView.videoRunning];
    [bluerBackgroundEffect setHidden:YES];
    self.previewView.videoRunning = true;
    self.distantView.videoRunning = true;
}

-(void) setUpAudioOnlyView {
    [self.previewView setHidden: YES];
    [self.distantView setHidden: YES];
    [hidePreviewBackground setHidden: YES];
    [bluerBackgroundEffect setHidden:NO];
    [backgroundImage setHidden:NO];
}

-(void) setBackground {
    NSImage *image= [self getContactImageOfSize:120.0 withDefaultAvatar:NO];
    if(image) {
        @autoreleasepool {
            CIImage * ciImage = [[CIImage alloc] initWithData:[image TIFFRepresentation]];
            CIFilter *clamp = [CIFilter filterWithName:@"CIAffineClamp"];
            [clamp setValue:[NSAffineTransform transform] forKey:@"inputTransform"];
            [clamp setValue:ciImage forKey: kCIInputImageKey];
            CIFilter* bluerFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
            [bluerFilter setDefaults];
            [bluerFilter setValue:[NSNumber numberWithFloat: 9] forKey:@"inputRadius"];
            [bluerFilter setValue:[clamp valueForKey:kCIOutputImageKey] forKey: kCIInputImageKey];
            CIImage *result = [bluerFilter valueForKey:kCIOutputImageKey];
            CIContext *context = [CIContext contextWithOptions:nil];
            CGImageRef cgImage = [context createCGImage:result fromRect: [ciImage extent]];
            NSImage *bluredImage = [[NSImage alloc] initWithCGImage:cgImage size:NSSizeFromCGSize(CGSizeMake(image.size.width, image.size.height))];
            backgroundImage.layer.contents = bluredImage;
            [backgroundImage setHidden:NO];
            [bluerBackgroundEffect setFillColor:[NSColor darkGrayColor]];
            [bluerBackgroundEffect setAlphaValue:0.6];
        }
    } else {
        contactNameLabel.textColor = [NSColor textColor];
        contactIdLabel.textColor = [NSColor textColor];
        callStateLabel.textColor = [NSColor textColor];
        backgroundImage.layer.contents = nil;
        [bluerBackgroundEffect setFillColor:[NSColor windowBackgroundColor]];
        [bluerBackgroundEffect setAlphaValue:1];
        [backgroundImage setHidden:YES];
    }
}

-(NSImage *) getContactImageOfSize: (double) size withDefaultAvatar:(BOOL) shouldDrawDefault {
    @autoreleasepool {
        auto* convModel = accountInfo_->conversationModel.get();
        auto convOpt = getConversationFromUid(convUid_, *accountInfo_->conversationModel.get());
        if (!convOpt.has_value()) {
            return nil;
        }
        lrc::api::conversation::Info& conv = *convOpt;
        if (conv.uid.isEmpty() || conv.participants.empty()) {
            return nil;
        }
        if(shouldDrawDefault) {
            auto& imgManip = reinterpret_cast<Interfaces::ImageManipulationDelegate&>(GlobalInstances::pixmapManipulator());
            QVariant photo = imgManip.conversationPhoto(conv, *accountInfo_, QSize(size, size), NO);
            return QtMac::toNSImage(qvariant_cast<QPixmap>(photo));
        }
        try {
            auto contact = accountInfo_->contactModel->getContact(accountInfo_->conversationModel->peersForConversation(conv.uid)[0]);
            NSData *imageData = [[NSData alloc] initWithBase64EncodedString:contact.profileInfo.avatar.toNSString() options:NSDataBase64DecodingIgnoreUnknownCharacters];
            return [[NSImage alloc] initWithData:imageData];
        } catch (std::out_of_range& e) {
            return nil;
        }
    }
}

-(void) setupContactInfo:(NSImageView*)imageView
{
    [imageView setImage: [self getContactImageOfSize:120.0 withDefaultAvatar:YES]];
}

-(void)collapseRightView
{
    NSView *right = [[splitView subviews] objectAtIndex:1];
    NSView *left  = [[splitView subviews] objectAtIndex:0];
    NSRect leftFrame = [left frame];
    [right setHidden:YES];
    [splitView display];
}

-(void) connectVideoSignals
{
    if (accountInfo_ == nil)
        return;
    [self connectRenderer];
}

-(void)updateShareButtonAnimation {
    if (accountInfo_ == nil)
        return;

    auto* callModel = accountInfo_->callModel.get();
    auto type = callModel->getCurrentRenderedDevice(callUid_).type;
    if (type == lrc::api::video::DeviceType::DISPLAY || type == lrc::api::video::DeviceType::FILE) {
        [self.shareButton startBlinkAnimationfrom:[NSColor buttonBlinkColorColor] to:[NSColor whiteColor] scaleFactor: 1 duration: 1.5];
        NSString *tooltip = type == lrc::api::video::DeviceType::DISPLAY ? NSLocalizedString(@"Stop screen sharing", @"share button tooltip") : NSLocalizedString(@"Stop file streaming", @"share button tooltip");
        self.shareButton.toolTip = tooltip;
    } else {
        [self.shareButton stopBlinkAnimation];
        self.shareButton.toolTip = NSLocalizedString(@"Share", @"share button tooltip");;
    }
}

-(void)updateCurrentRendererDeivce {
    auto* callModel = accountInfo_->callModel.get();
    auto device = callModel->getCurrentRenderedDevice(callUid_);
    auto deviceName = device.name;
    switch (device.type) {
        case lrc::api::video::DeviceType::DISPLAY:
            currentRenderer_ = "display://" + deviceName;
            return;
        case lrc::api::video::DeviceType::FILE:
            currentRenderer_ = "file://" + deviceName;
            return;
        case lrc::api::video::DeviceType::CAMERA:
            currentRenderer_ = "camera://" + deviceName;
            return;
        default:
            break;
    }
}

-(void) connectRenderer
{
    QObject::disconnect(renderConnections.frameUpdated);
    QObject::disconnect(renderConnections.stopped);
    QObject::disconnect(renderConnections.started);
    renderConnections.started =
    QObject::connect(mediaModel,
                     &lrc::api::AVModel::rendererStarted,
                     [=](const QString& id) {
                         [self updateCurrentRendererDeivce];
                         if (id == currentRenderer_) {
                             dispatch_async(dispatch_get_main_queue(), ^{
                                 [self.previewView setHidden:NO];
                                 [hidePreviewBackground setHidden: NO];
                                 self.previewView.videoRunning = true;
                                 [self updateShareButtonAnimation];
                             });
                         } else if ([self isCurrentCall: id]) {
                             dispatch_async(dispatch_get_main_queue(), ^{
                                 [self mouseIsMoving: NO];
                                 [backgroundImage setHidden:YES];
                                 self.distantView.videoRunning = true;
                                 [self.distantView setHidden:NO];
                                 [bluerBackgroundEffect setHidden:YES];
                             });
                         }
                     });
    renderConnections.stopped =
    QObject::connect(mediaModel,
                     &lrc::api::AVModel::rendererStopped,
                     [=](const QString& id) {
                         if (id == currentRenderer_) {
                             dispatch_async(dispatch_get_main_queue(), ^{
                                 [self.previewView setHidden:YES];
                                 self.previewView.videoRunning = false;
                                 [self.shareButton stopBlinkAnimation];
                             });
                         } else if ([self isCurrentCall: id]) {
                             dispatch_async(dispatch_get_main_queue(), ^{
                                 [self mouseIsMoving: YES];
                                 self.distantView.videoRunning = false;
                                 [self.distantView setHidden:YES];
                                 [bluerBackgroundEffect setHidden:NO];
                                 [backgroundImage setHidden:NO];
                             });
                         }
                     });
    renderConnections.frameUpdated =
    QObject::connect(mediaModel,
                     &lrc::api::AVModel::frameUpdated,
                     [=](const QString& id) {
                         if (id == currentRenderer_) {
                             auto renderer = &mediaModel->getRenderer(id);
                             if(!renderer->isRendering()) {
                                 return;
                             }
                             [hidePreviewBackground setHidden: !self.previewView.videoRunning];
                             [self rendererPreview: renderer];
                         } else if ([self isCurrentCall: id]) {
                             auto renderer = &mediaModel->getRenderer(id);
                             if(!renderer->isRendering()) {
                                 return;
                             }
                             [self rendererDistantView: renderer];
                         }
                     });
    QObject::disconnect(self.videoDeviceEvent);
    self.videoDeviceEvent = QObject::connect(mediaModel,
                                        &lrc::api::AVModel::deviceEvent,
                                        [=]() {
        [self updateLMediaListButtonsVisibility];
    });
    QObject::disconnect(self.audioDeviceEvent);
    self.audioDeviceEvent = QObject::connect(mediaModel,
                                        &lrc::api::AVModel::audioDeviceEvent,
                                        [=]() {
        [self updateLMediaListButtonsVisibility];
    });
}

-(void) updateLMediaListButtonsVisibility {
    auto inputDevices = mediaModel->getAudioInputDevices();
    inputAudioMenuButton.hidden = inputDevices.size() <= 1;
    inputAudioMenuButton.enabled = inputDevices.size() > 1;
    outputAudioMenuButton.hidden = true;
    outputAudioMenuButton.enabled = false;
    auto videoDevices = [self getDeviceList];
    videoMenuButton.hidden = videoDevices.size() <= 1;
    videoMenuButton.enabled = videoDevices.size() > 1;
}

-(void) rendererDistantView: (const lrc::api::video::Renderer*)renderer {
    @autoreleasepool {
        auto framePtr = renderer->currentAVFrame();
        auto frame = framePtr.get();
        if(!frame || !frame->width || !frame->height)  {
            return;
        }
        auto frameSize = CGSizeMake(frame->width, frame->height);
        framesize = frameSize;
        auto rotation = 0;
        if (auto matrix = av_frame_get_side_data(frame, AV_FRAME_DATA_DISPLAYMATRIX)) {
            const int32_t* data = reinterpret_cast<int32_t*>(matrix->data);
            rotation = av_display_rotation_get(data);
        }
        if (frame->data[3] != NULL && (CVPixelBufferRef)frame->data[3]) {
            [self.distantView renderWithPixelBuffer: (CVPixelBufferRef)frame->data[3]
                                   size: frameSize
                               rotation: rotation
                              fillFrame: false];
        }
        if (CVPixelBufferRef pixelBuffer = [self getBufferForDistantViewFromFrame:frame]) {
            [self.distantView renderWithPixelBuffer: pixelBuffer
                                   size: frameSize
                               rotation: rotation
                              fillFrame: false];
        }
    }
}

-(void) rendererPreview: (const lrc::api::video::Renderer*)renderer {
    @autoreleasepool {
        auto framePtr = renderer->currentAVFrame();
        auto frame = framePtr.get();
        if(!frame || !frame->width || !frame->height)  {
            return;
        }
        auto frameSize = CGSizeMake(frame->width, frame->height);
        auto rotation = 0;
        if (auto matrix = av_frame_get_side_data(frame, AV_FRAME_DATA_DISPLAYMATRIX)) {
            const int32_t* data = reinterpret_cast<int32_t*>(matrix->data);
            rotation = av_display_rotation_get(data);
        }
        if (frame->data[3] != NULL && (CVPixelBufferRef)frame->data[3]) {
            [self.previewView renderWithPixelBuffer: (CVPixelBufferRef)frame->data[3]
                                   size: frameSize
                               rotation: rotation
                              fillFrame: false];
        }
        if (CVPixelBufferRef pixelBuffer = [self getBufferForPreviewFromFrame:frame]) {
            [self.previewView renderWithPixelBuffer: pixelBuffer
                                   size: frameSize
                               rotation: rotation
                              fillFrame: true];
        }
    }
}

-(CVPixelBufferRef) getBufferForPreviewFromFrame:(const AVFrame*)frame {
    [VideoCommon fillPixelBuffr:&pixelBufferPreview fromFrame:frame bufferPool:&pixelBufferPoolPreview];
    CVPixelBufferRef buffer  = pixelBufferPreview;
    return buffer;
}

-(CVPixelBufferRef) getBufferForDistantViewFromFrame:(const AVFrame*)frame {
    [VideoCommon fillPixelBuffr:&pixelBufferDistantView fromFrame:frame bufferPool:&pixelBufferPoolDistantView];
    CVPixelBufferRef buffer  = pixelBufferDistantView;
    return buffer;
}

- (void) initFrame
{
    [self.view setFrame:self.view.superview.bounds];
    [self.view setHidden:YES];
    self.view.layer.position = self.view.frame.origin;
    [self collapseRightView];
}

# pragma private IN/OUT animations

-(void)uncollapseRightView
{
    NSView *left  = [[splitView subviews] objectAtIndex:0];
    NSView *right = [[splitView subviews] objectAtIndex:1];
    [right setHidden:NO];

    CGFloat dividerThickness = [splitView dividerThickness];

    // get the different frames
    NSRect leftFrame = [left frame];
    NSRect rightFrame = [right frame];

    leftFrame.size.width = (leftFrame.size.width - rightFrame.size.width - dividerThickness);
    rightFrame.origin.x = leftFrame.size.width + dividerThickness;
    [left setFrameSize:leftFrame.size];
    [right setFrame:rightFrame];
    [splitView display];

    [self.chatVC takeFocus];
}

-(void) cleanUp
{
    if(self.splitView.isInFullScreenMode)
        [self.splitView exitFullScreenModeWithOptions:nil];
    QObject::disconnect(renderConnections.frameUpdated);
    QObject::disconnect(renderConnections.started);
    QObject::disconnect(renderConnections.stopped);
    QObject::disconnect(self.messageConnection);
    QObject::disconnect(self.videoDeviceEvent);
    QObject::disconnect(self.audioDeviceEvent);

    [self.chatButton setPressed:NO];
    [self.pluginButton setPressed:NO];
    [self collapseRightView];

    [timeSpentLabel setStringValue:@""];
    [contactIdLabel setStringValue:@""];
    [contactNameLabel setStringValue:@""];
    [contactPhoto setImage:nil];
    //background view
    [bluerBackgroundEffect setHidden:NO];
    [backgroundImage setHidden:NO];
    backgroundImage.layer.contents = nil;
    [self.previewView setHidden:YES];
    [self.distantView setHidden:YES];

    contactNameLabel.textColor = [NSColor highlightColor];
    contactNameLabel.textColor = [NSColor highlightColor];
    contactIdLabel.textColor = [NSColor highlightColor];
    callStateLabel.textColor = [NSColor highlightColor];
    [self.chatVC clearData];
}

/*
 * update ui
*/

-(void) setupCallView
{
    if (accountInfo_ == nil)
        return;

    auto* callModel = accountInfo_->callModel.get();

    /* check if text media is already present */
    if(not callModel->hasCall(callUid_))
        return;

    // when call comes in we want to show the controls/header
    [self mouseIsMoving: YES];
    [loadingIndicator setAnimates:YES];
    auto currentCall = callModel->getCall([self getcallID]);
    [previewView setHidden: YES];
    [self setUpPreviewFrame];
    [self updatePendingCalls];
    [self updateCall];
}

-(void) showWithAnimation:(BOOL)animate
{
    if (!animate) {
        [self.view setHidden:NO];
        [self setupCallView];
        return;
    }

    CGRect frame = CGRectOffset(self.view.superview.bounds, -self.view.superview.bounds.size.width, 0);
    [self.view setHidden:NO];

    [CATransaction begin];
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
    [animation setFromValue:[NSValue valueWithPoint:frame.origin]];
    [animation setToValue:[NSValue valueWithPoint:self.view.superview.bounds.origin]];
    [animation setDuration:0.2f];
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn]];
    [CATransaction setCompletionBlock:^{
        [self setupCallView];
    }];

    [self.view.layer addAnimation:animation forKey:animation.keyPath];
    [CATransaction commit];
}

-(void) hideWithAnimation:(BOOL)animate
{
    if(self.view.frame.origin.x < 0) {
        return;
    }

    if (!animate) {
        [self.view setHidden:YES];
        return;
    }

    CGRect frame = CGRectOffset(self.view.frame, -self.view.frame.size.width, 0);
    [CATransaction begin];
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
    [animation setFromValue:[NSValue valueWithPoint:self.view.frame.origin]];
    [animation setToValue:[NSValue valueWithPoint:frame.origin]];
    [animation setDuration:0.2f];
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];

    [CATransaction setCompletionBlock:^{
        [self.view setHidden:YES];
        [self cleanUp];
    }];
    [self.view.layer addAnimation:animation forKey:animation.keyPath];

    [self.view.layer setPosition:frame.origin];
    [CATransaction commit];
}

/**
 *  Debug purpose
 */
-(void) dumpFrame:(CGRect) frame WithName:(NSString*) name
{
    NSLog(@"frame %@ : %f %f %f %f \n\n",name ,frame.origin.x, frame.origin.y, frame.size.width, frame.size.height);
}

#pragma mark - Button methods

- (IBAction)hangUp:(id)sender {
    if (accountInfo_ == nil)
        return;

    auto* callModel = accountInfo_->callModel.get();
    callModel->hangUp(callUid_);
}

- (IBAction)accept:(id)sender {
    if (accountInfo_ == nil)
        return;

    // If we accept a conversation with a non trusted contact, we first accept it
    auto convOpt = getConversationFromUid(convUid_, *accountInfo_->conversationModel.get());
    if (!convOpt.has_value()) {
        return;
    }
    lrc::api::conversation::Info& conv = *convOpt;
    if (conv.uid.isEmpty() || conv.participants.empty()) {
        return;
    }
    try {
        auto& contact = accountInfo_->contactModel->getContact(accountInfo_->conversationModel->peersForConversation(conv.uid)[0]);
        if (contact.profileInfo.type == lrc::api::profile::Type::PENDING) {
            accountInfo_->conversationModel->makePermanent(convUid_);
        }
    } catch (std::out_of_range& e) {
        NSLog(@"contact out of range");
    }

    auto* callModel = accountInfo_->callModel.get();
    callModel->accept(callUid_);
}



- (IBAction)acceptAudioOnly:(id)sender {
    if (accountInfo_ == nil)
        return;

    // If we accept a conversation with a non trusted contact, we first accept it
    auto convOpt = getConversationFromUid(convUid_, *accountInfo_->conversationModel.get());
    if (!convOpt.has_value()) {
        return;
    }
    lrc::api::conversation::Info& conv = *convOpt;
    if (conv.uid.isEmpty() || conv.participants.empty()) {
        return;
    }
    try {
        auto& contact = accountInfo_->contactModel->getContact(accountInfo_->conversationModel->peersForConversation(conv.uid)[0]);
        if (contact.profileInfo.type == lrc::api::profile::Type::PENDING) {
            accountInfo_->conversationModel->makePermanent(convUid_);
        }
    } catch (std::out_of_range& e) {
        NSLog(@"contact out of range");
    }

    auto* callModel = accountInfo_->callModel.get();
    callModel->updateCallMediaList(callUid_, false);
    movableBaseForView.hidden = YES;
    muteVideoButton.image = [NSImage imageNamed:@"camera_off.png"];
    callModel->accept(callUid_);
}

- (IBAction)toggleRecording:(id)sender {
    if (accountInfo_ == nil)
        return;

    auto* callModel = accountInfo_->callModel.get();
    callModel->toggleAudioRecord(callUid_);
    if (callModel->isRecording(callUid_)) {
        [recordOnOffButton startBlinkAnimationfrom:[NSColor buttonBlinkColorColor] to:[NSColor whiteColor] scaleFactor: 1 duration: 1.5];
    } else {
        [recordOnOffButton stopBlinkAnimation];
    }
}

- (IBAction)toggleHold:(id)sender {
    if (accountInfo_ == nil)
        return;

    auto* callModel = accountInfo_->callModel.get();
    callModel->togglePause([self getcallID]);
}

- (IBAction)showDialpad:(id)sender {
    AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
    [appDelegate showDialpad];
}

-(IBAction)toggleChat:(id)sender;
{
    BOOL rightViewCollapsed = [[self splitView] isSubviewCollapsed:[[[self splitView] subviews] objectAtIndex: 1]];
    if (rightViewCollapsed) {
        [self uncollapseRightView];
    } else {
        [self collapseRightView];
    }
    [chatButton setPressed:rightViewCollapsed];
}

- (IBAction)muteAudio:(id)sender {
    if (accountInfo_ == nil)
        return;

    auto* callModel = accountInfo_->callModel.get();
    auto& currentCall = callModel->getCall([self getcallID]);
    callModel->requestMediaChange([self getcallID], "audio_0", "", lrc::api::NewCallModel::MediaRequestType::CAMERA, !currentCall.audioMuted);
    muteAudioButton.image = currentCall.audioMuted ? [NSImage imageNamed:@"micro_off.png"] : [NSImage imageNamed:@"micro_on.png"];
    NSColor* audioImageColor = currentCall.audioMuted ? [NSColor callButtonRedColor] : [NSColor whiteColor];
    [self updateColorForButton: muteAudioButton color: audioImageColor];
}

-(void)updateColorForButton:(HoverButton*)buton color:(NSColor*)color {
    buton.imageColor = color;
    buton.moiuseOutsideImageColor = color;
    buton.imageHoverColor= color;
    [buton setNeedsDisplay: YES];
}

- (IBAction)muteVideo:(id)sender
{
    if (accountInfo_ == nil)
        return;
    auto* callModel = accountInfo_->callModel.get();
    auto& currentCall = callModel->getCall([self getcallID]);
    callModel->requestMediaChange([self getcallID], "video_0", "", lrc::api::NewCallModel::MediaRequestType::CAMERA, !currentCall.videoMuted);
    muteVideoButton.image = currentCall.videoMuted ? [NSImage imageNamed:@"camera_off.png"] : [NSImage imageNamed:@"camera_on.png"];
    NSColor* videoImageColor = currentCall.videoMuted ? [NSColor callButtonRedColor] : [NSColor whiteColor];
    [self updateColorForButton: muteVideoButton color: videoImageColor];
}

- (IBAction)toggleAddParticipantView:(id)sender {
    [self presentPopoverVCOfType: addParticipant sender: sender];
}

- (IBAction)toggleChangeAudioInput:(id)sender {
    [self presentPopoverVCOfType: audioInputDevices sender: sender];
}

- (IBAction)toggleChangeAudioOutput:(id)sender {
    [self presentPopoverVCOfType: audioOutputDevices sender: sender];
}

- (IBAction)toggleChangeCamera:(id)sender {
    [self presentPopoverVCOfType: videoDevices sender: sender];
}

- (IBAction)changeAudioOutputVolume:(id)sender {
    [self presentPopoverVCOfType: changeAudioOutputVolume sender: sender];
}

- (IBAction)changeAudioInputVolume:(id)sender {
    [self presentPopoverVCOfType: changeAudioInputVolume sender: sender];
}

- (IBAction)choosePlugin:(id)sender {
    if (brokerPopoverVC != nullptr) {
        [brokerPopoverVC performClose:self];
        brokerPopoverVC = NULL;
    } else {
        auto* pluginHandlerSelectorVC = [[ChoosePluginHandlerVC alloc] initWithNibName:@"ChoosePluginHandlerVC" bundle:nil];
        pluginHandlerSelectorVC.pluginModel = pluginModel_;
        [pluginHandlerSelectorVC setupForCall: [self getcallID]];
        brokerPopoverVC = [[NSPopover alloc] init];
        [brokerPopoverVC setContentViewController:pluginHandlerSelectorVC];
        [brokerPopoverVC setAnimates:YES];
        [brokerPopoverVC setBehavior:NSPopoverBehaviorTransient];
        [brokerPopoverVC setDelegate:self];
        [brokerPopoverVC showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSMinYEdge];
    }
}

- (IBAction)hidePreview:(id)sender {
    CGRect previewFrame = previewView.frame;
    CGRect newPreviewFrame;
    if (previewFrame.size.width > HIDE_PREVIEW_BUTTON_SIZE) {
        self.movableBaseForView.movable = false;
        newPreviewFrame = self.getVideoPreviewCollapsedSize;
        hidePreviewButton.image = [NSImage imageNamed: NSImageNameTouchBarEnterFullScreenTemplate];
    } else {
        self.movableBaseForView.movable = true;
        newPreviewFrame = CGRectMake(0, 0, PREVIEW_WIDTH, PREVIEW_HEIGHT);
        hidePreviewButton.image = [NSImage imageNamed: NSImageNameTouchBarExitFullScreenTemplate];
    }
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
        context.duration = 0.2f;
        context.timingFunction = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseOut];
        previewView.animator.frame = newPreviewFrame;
    } completionHandler: nil];
}

-(NSViewController*)getControllerForType:(PopoverType)type {
    switch (type) {
        case audioInputDevices:
        {
            auto* mediaSelectorVC = [[ChooseMediaVC alloc] initWithNibName:@"ChooseMediaVC" bundle:nil];
            auto inputDevices = mediaModel->getAudioInputDevices();
            auto currentDevice = mediaModel->getInputDevice();
            [mediaSelectorVC setMediaDevices: inputDevices andDefaultDevice: currentDevice];
            mediaSelectorVC.onDeviceSelected = ^(NSString * _Nonnull device, NSInteger index) {
                mediaModel->setInputDevice(QString::fromNSString(device));
                [brokerPopoverVC performClose:self];
                brokerPopoverVC = NULL;
            };
            return mediaSelectorVC;
        }
        case audioOutputDevices:
        {
            auto* mediaSelectorVC = [[ChooseMediaVC alloc] initWithNibName:@"ChooseMediaVC" bundle:nil];
            auto outputDevices = mediaModel->getAudioOutputDevices();
            auto currentDevice = mediaModel->getOutputDevice();
            [mediaSelectorVC setMediaDevices: outputDevices andDefaultDevice: currentDevice];
            mediaSelectorVC.onDeviceSelected = ^(NSString * _Nonnull device, NSInteger index) {
                mediaModel->setOutputDevice(QString::fromNSString(device));
                [brokerPopoverVC performClose:self];
                brokerPopoverVC = NULL;
            };
            return mediaSelectorVC;
        }
        case videoDevices:
        {
            auto* mediaSelectorVC = [[ChooseMediaVC alloc] initWithNibName:@"ChooseMediaVC" bundle:nil];
            auto videoDevices = [self getDeviceList];
            auto* callModel = accountInfo_->callModel.get();
            auto device = callModel->getCurrentRenderedDevice(callUid_).name;
            auto settings = mediaModel->getDeviceSettings(device);
            auto currentDevice = settings.name;
            [mediaSelectorVC setMediaDevices: videoDevices andDefaultDevice: currentDevice];
            mediaSelectorVC.onDeviceSelected = ^(NSString * _Nonnull device, NSInteger index) {
                [self switchToDevice: index];
                [brokerPopoverVC performClose:self];
                brokerPopoverVC = NULL;
            };
            return mediaSelectorVC;
        }
        case share:
        {
            auto* mediaSelectorVC = [[ChooseMediaVC alloc] initWithNibName:@"ChooseMediaVC" bundle:nil];
            auto shareScreen = QString::fromNSString(NSLocalizedString(@"Share screen", @"Contextual menu entry"));
            auto shareFile = QString::fromNSString(NSLocalizedString(@"Stream file", @"Contextual menu entry"));
            QVector<QString> devices;
            devices.append(shareScreen);
            devices.append(shareFile);
            [mediaSelectorVC setMediaDevices: devices andDefaultDevice: ""];
            mediaSelectorVC.onDeviceSelected = ^(NSString * _Nonnull device, NSInteger index) {
                [brokerPopoverVC performClose:self];
                brokerPopoverVC = NULL;
                if (QString::fromNSString(device) == shareScreen) {
                    [self screenShare];
                    return;
                }
                [self streamFile];
            };
            return mediaSelectorVC;
        }
        case changeAudioInputVolume:
        {
            auto* audioVolumeVC = [[ChangeAudioVolumeVC alloc] initWithNibName:@"ChangeAudioVolumeVC" bundle:nil];
            auto device = mediaModel->getOutputDevice();
            [audioVolumeVC setMediaDevice:device avModel: mediaModel andType: output];
            audioVolumeVC.onMuted = ^{
            };
            return audioVolumeVC;
        }
        case changeAudioOutputVolume:
        {
            auto* audioVolumeVC = [[ChangeAudioVolumeVC alloc] initWithNibName:@"ChangeAudioVolumeVC" bundle:nil];
            auto device = mediaModel->getInputDevice();
            [audioVolumeVC setMediaDevice:device avModel: mediaModel andType: input];
            audioVolumeVC.onMuted = ^{};
        }
        case addParticipant:
        {
            auto* contactSelectorVC = [[ChooseContactVC alloc] initWithNibName:@"ChooseContactVC" bundle:nil];
            auto* convModel = accountInfo_->conversationModel.get();
            [contactSelectorVC setUpForConference:convModel andCurrentConversation:convUid_];
            contactSelectorVC.delegate = self;
            return contactSelectorVC;
        }
    }
}

-(void)presentPopoverVCOfType:(PopoverType)type sender:(id)sender  {
    if (brokerPopoverVC != nullptr) {
        [brokerPopoverVC performClose:self];
        brokerPopoverVC = NULL;
    } else {
        brokerPopoverVC = [[NSPopover alloc] init];
        NSViewController* contenctcontroller = [self getControllerForType: type];
        [brokerPopoverVC setContentSize: contenctcontroller.view.frame.size];
        [brokerPopoverVC setContentViewController: contenctcontroller];
        [brokerPopoverVC setAnimates:YES];
        [brokerPopoverVC setBehavior:NSPopoverBehaviorTransient];
        [brokerPopoverVC setDelegate:self];
        [brokerPopoverVC showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSMinYEdge];
    }
}

- (IBAction)toggleShare:(id)sender {
    if (accountInfo_ == nil)
        return;
    auto* callModel = accountInfo_->callModel.get();
    auto device = callModel->getCurrentRenderedDevice(callUid_);
    if (device.type == lrc::api::video::DeviceType::DISPLAY || device.type == lrc::api::video::DeviceType::FILE) {
        [self switchToDevice:0];
        if (brokerPopoverVC != nullptr) {
            [brokerPopoverVC performClose:self];
            brokerPopoverVC = NULL;
        }
        return;
    }
    [self presentPopoverVCOfType: share sender: sender];
}

- (IBAction)setGridLayout:(id)sender {
    if (accountInfo_ == nil)
        return;
    auto* callModel = accountInfo_->callModel.get();
    if (not callModel->hasCall([self getcallID]))
        return;
    callModel->setConferenceLayout([self getcallID], lrc::api::call::Layout::GRID);
}

#pragma mark - NSSplitViewDelegate

/* Return YES if the subview should be collapsed because the user has double-clicked on an adjacent divider. If a split view has a delegate, and the delegate responds to this message, it will be sent once for the subview before a divider when the user double-clicks on that divider, and again for the subview after the divider, but only if the delegate returned YES when sent -splitView:canCollapseSubview: for the subview in question. When the delegate indicates that both subviews should be collapsed NSSplitView's behavior is undefined.
 */
- (BOOL)splitView:(NSSplitView *)splitView shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex;
{
    NSView* rightView = [[splitView subviews] objectAtIndex:1];
    return ([subview isEqual:rightView]);
}


- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview;
{
    NSView* rightView = [[splitView subviews] objectAtIndex:1];
    return ([subview isEqual:rightView]);
}


# pragma mark - CallnDelegate

- (void) callShouldToggleFullScreen
{
    if(self.splitView.isInFullScreenMode)
        [self.splitView exitFullScreenModeWithOptions:nil];
    else {
        NSApplicationPresentationOptions options = NSApplicationPresentationDefault +NSApplicationPresentationAutoHideDock +
        NSApplicationPresentationAutoHideMenuBar + NSApplicationPresentationAutoHideToolbar;
        NSDictionary *opts = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:options],
                              NSFullScreenModeApplicationPresentationOptions, nil];

        [self.splitView enterFullScreenMode:[NSScreen mainScreen]  withOptions:opts];
    }
    for (ConferenceOverlayView* participant: [participantsOverlays allValues]) {
        [participant viewSizeChanged];
    }
}

-(void) mouseIsMoving:(BOOL) move
{
    [[controlsPanel animator] setAlphaValue:move];// fade out
    [[controlsStackView animator] setAlphaValue:move];
    [[headerContainer animator] setAlphaValue:move];
    [[headerGradientView animator] setAlphaValue:move];
}

- (BOOL)splitView:(NSSplitView *)splitView shouldHideDividerAtIndex:(NSInteger)dividerIndex
{
    return YES;
}

-(void) screenShare {
    if (accountInfo_ == nil)
        return;
    auto* callModel = accountInfo_->callModel.get();
    NSScreen *mainScreen = [NSScreen mainScreen];
    NSRect screenFrame = mainScreen.frame;
    QRect captureRect = QRect(screenFrame.origin.x, screenFrame.origin.y, screenFrame.size.width, screenFrame.size.height);
    callModel->setDisplay(0, screenFrame.origin.x, screenFrame.origin.y, screenFrame.size.width, screenFrame.size.height, [self getcallID]);
}

-(void)streamFile {
    NSOpenPanel *browsePanel = [[NSOpenPanel alloc] init];
    [browsePanel setDirectoryURL:[NSURL URLWithString:NSHomeDirectory()]];
    [browsePanel setCanChooseFiles:YES];
    [browsePanel setCanChooseDirectories:NO];
    [browsePanel setCanCreateDirectories:NO];

    NSMutableArray* fileTypes = [[NSMutableArray alloc] initWithArray:[NSImage imageTypes]];
    [fileTypes addObject:(__bridge NSString *)kUTTypeVideo];
    [fileTypes addObject:(__bridge NSString *)kUTTypeMovie];
    [fileTypes addObject:(__bridge NSString *)kUTTypeImage];
    [browsePanel setAllowedFileTypes:fileTypes];
    [browsePanel beginSheetModalForWindow:[self.view window] completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL*  theDoc = [[browsePanel URLs] objectAtIndex:0];
            auto name = QString::fromNSString([@"file:///" stringByAppendingString: theDoc.path]);
            [self switchToFile: name];
        }
    }];
}

-(void) switchToDevice:(int)index {
    if (accountInfo_ == nil)
        return;
    auto* callModel = accountInfo_->callModel.get();
    auto devices = mediaModel->getDevices();
    auto device = devices[index];
    mediaModel->setCurrentVideoCaptureDevice(device);
    callModel->switchInputTo(device, [self getcallID]);
}

-(QVector<QString>) getDeviceList {
    QVector<QString> devicesVector;
    for (auto device : mediaModel->getDevices()) {
        try {
            auto settings = mediaModel->getDeviceSettings(device);
            devicesVector.append(settings.name);
        } catch (...) {}
    }
    return devicesVector;
}

-(void) switchToFile:(QString)uri {
    if (accountInfo_ == nil)
        return;
    auto* callModel = accountInfo_->callModel.get();
    callModel->setInputFile(uri, [self getcallID]);
}

-(CGRect) getVideoPreviewCollapsedSize {
    CGPoint origin;
    switch (movableBaseForView.closestCorner) {
        case TOP_LEFT:
            origin = CGPointMake(0, movableBaseForView.frame.size.height - HIDE_PREVIEW_BUTTON_SIZE);
            break;
        case BOTTOM_LEFT:
            origin = CGPointMake(0, 0);
            break;
        case TOP_RIGHT:
            origin = CGPointMake(movableBaseForView.frame.size.width - HIDE_PREVIEW_BUTTON_SIZE, movableBaseForView.frame.size.height - HIDE_PREVIEW_BUTTON_SIZE);
            break;
        case BOTTOM_RIGHT:
            origin = CGPointMake(movableBaseForView.frame.size.width - HIDE_PREVIEW_BUTTON_SIZE, 0);
            break;
    }
    return CGRectMake(origin.x, origin.y, HIDE_PREVIEW_BUTTON_SIZE, HIDE_PREVIEW_BUTTON_SIZE);
}

-(CGRect) frameForExpendPreviewButton {
    CGPoint origin = CGPointMake(self.previewView.frame.size.width - HIDE_PREVIEW_BUTTON_SIZE,
                                 self.previewView.frame.size.height - HIDE_PREVIEW_BUTTON_SIZE);
    return CGRectMake(origin.x, origin.y, HIDE_PREVIEW_BUTTON_SIZE, HIDE_PREVIEW_BUTTON_SIZE);
}

# pragma mark -ChooseContactVCDelegate

-(void)callToContact:(const QString&)contactUri convUID:(const QString&)convID {
    if (brokerPopoverVC != nullptr) {
        [brokerPopoverVC performClose:self];
        brokerPopoverVC = NULL;
    }
    auto* callModel = accountInfo_->callModel.get();
    auto currentCall = callModel->getCall([self getcallID]);
    auto* convModel = accountInfo_->conversationModel.get();
    auto newCall = callModel->callAndAddParticipant(contactUri,
                                                    [self getcallID],
                                                    currentCall.isAudioOnly);
    [self addPreviewForContactUri:contactUri call: newCall];
}

-(void)joinCall:(const QString&)callId {
    if (brokerPopoverVC != nullptr) {
        [brokerPopoverVC performClose:self];
        brokerPopoverVC = NULL;
    }
    auto* callModel = accountInfo_->callModel.get();
    callModel->joinCalls([self getcallID], callId);
}

# pragma mark -CallInConferenceVCDelegate

-(void)removePreviewForContactUri:(const QString&)uri forCall:(const QString&) callId {
    NSMutableDictionary * calls = connectingCalls[callId.toNSString()];
    if (!calls) {
        return;
    }
    NSViewController *callView = calls[uri.toNSString()];
    if (!callView) {
        return;
    }
    calls[uri.toNSString()] = nil;
    [self.callingWidgetsContainer removeView:callView.view];
}

-(void)addPreviewForContactUri:(const QString&)uri call:(const QString&)callId {
    NSMutableDictionary *calls = connectingCalls[callUid_.toNSString()];
    if (!calls) {
        calls = [[NSMutableDictionary alloc] init];
    }
    if (calls[uri.toNSString()]) {
        return;
    }
    CallInConferenceVC *callingView = [self callingViewForCallId: callId];
    calls[uri.toNSString()] = callingView;
    connectingCalls[callUid_.toNSString()] = calls;
    [self.callingWidgetsContainer addView:callingView.view inGravity:NSStackViewGravityBottom];
    [self.callingWidgetsContainer updateConstraints];
    [self.callingWidgetsContainer updateLayer];
    [self.callingWidgetsContainer setNeedsDisplay:YES];
}

-(CallInConferenceVC*) callingViewForCallId:(const QString&)callId {
    CallInConferenceVC *callView = [[CallInConferenceVC alloc]
                                    initWithNibName:@"CallInConferenceVC"
                                    bundle:nil
                                    callId:callId
                                    accountInfo:accountInfo_];
    callView.delegate = self;
    callView.initiatorCallId = callUid_;
    return callView;
}

-(const QString&)getcallID {
    return confUid_.isEmpty() ? callUid_ : confUid_;
}

-(bool)isCurrentCall:(const QString&)callId {
    return (callId == confUid_ || callId == callUid_);
}

#pragma mark ConferenceLayoutDelegate

-(void)hangUpParticipant:(NSString*)uri {
    if (accountInfo_ == nil)
        return;
    auto* callModel = accountInfo_->callModel.get();
    callModel->hangupParticipant([self getcallID], QString::fromNSString(uri));
}

-(void)minimizeParticipant {
    if (accountInfo_ == nil)
        return;
    auto* callModel = accountInfo_->callModel.get();
    auto confId = [self getcallID];
    if (not callModel->hasCall(confId)) {
        return;
    }
    try {
        auto call = callModel->getCall(confId);
        switch (call.layout) {
            case lrc::api::call::Layout::GRID:
                break;
            case lrc::api::call::Layout::ONE_WITH_SMALL:
                callModel->setConferenceLayout(confId, lrc::api::call::Layout::GRID);
                break;
            case lrc::api::call::Layout::ONE:
                callModel->setConferenceLayout(confId, lrc::api::call::Layout::ONE_WITH_SMALL);
                break;
        };
    } catch (...) {}
}

-(int)getCurrentLayout {
    auto* callModel = accountInfo_->callModel.get();
    auto confId = [self getcallID];
    if (not callModel->hasCall(confId)){
        return -1;
    }
    return static_cast<int>(callModel->getCall(confId).layout);
}

-(BOOL)isMasterCall {
    auto convOpt = getConversationFromUid(convUid_, *accountInfo_->conversationModel.get());
    if (!convOpt.has_value())
        return false;
    lrc::api::conversation::Info& conv = *convOpt;
    auto* callModel = accountInfo_->callModel.get();
    try {
        auto call = callModel->getCall(conv.callId);
        if (call.participantsInfos.size() == 0) {
            return true;
        }
        return !conv.confId.isEmpty() && callModel->hasCall(conv.confId);
    } catch (...) {}
    return true;
}

-(BOOL)isCallModerator {
    if (accountInfo_ == nil)
        return false;
    auto* callModel = accountInfo_->callModel.get();
    return callModel->isModerator([self getcallID]);
}

-(BOOL)isAllModerators {
    return allModeratorsInConference;
}

-(BOOL)isParticipantHost:(NSString*)uri {
    if (accountInfo_ == nil)
        return false;
    if ([self isMasterCall] ) {
        return accountInfo_->profileInfo.uri == QString::fromNSString(uri);
    }
    auto convOpt = getConversationFromUid(convUid_, *accountInfo_->conversationModel.get());
    if (!convOpt.has_value())
        return false;
    lrc::api::conversation::Info& conv = *convOpt;
    auto* callModel = accountInfo_->callModel.get();
    try {
        auto call = callModel->getCall(conv.callId);
        return call.peerUri.remove("ring:") == QString::fromNSString(uri);
    } catch (...) {}
    return true;
}

-(void)maximizeParticipant:(NSString*)uri active:(BOOL)isActive {
    if (accountInfo_ == nil)
        return;
    BOOL localVideo = accountInfo_->profileInfo.uri == QString::fromNSString(uri);
    auto* callModel = accountInfo_->callModel.get();
    auto confId = [self getcallID];
    if (not callModel->hasCall(confId) && !localVideo)
        return;
    try {
        auto call = callModel->getCall(confId);
        switch (call.layout) {
            case lrc::api::call::Layout::GRID:
                callModel->setActiveParticipant(confId, QString::fromNSString(uri));
                callModel->setConferenceLayout(confId, lrc::api::call::Layout::ONE_WITH_SMALL);
                break;
            case lrc::api::call::Layout::ONE_WITH_SMALL:
                callModel->setActiveParticipant(confId, QString::fromNSString(uri));
                callModel->setConferenceLayout(confId,
                                               isActive ? lrc::api::call::Layout::ONE : lrc::api::call::Layout::ONE_WITH_SMALL);
                break;
            case lrc::api::call::Layout::ONE:
                callModel->setActiveParticipant(confId, QString::fromNSString(uri));
                callModel->setConferenceLayout(confId, lrc::api::call::Layout::GRID);
                break;
        };
    } catch (...) {}
}

-(void)muteParticipantAudio:(NSString*)uri state:(BOOL)state {
    if (accountInfo_ == nil)
        return;
    auto* callModel = accountInfo_->callModel.get();
    callModel->muteParticipant([self getcallID], QString::fromNSString(uri), state);
}

-(void)setModerator:(NSString*)uri state:(BOOL)state {
    if (accountInfo_ == nil)
        return;
    auto* callModel = accountInfo_->callModel.get();
    callModel->setModerator([self getcallID], QString::fromNSString(uri), state);
}

#pragma mark Popover delegate

- (void)popoverWillClose:(NSNotification *)notification
{
    if (brokerPopoverVC != nullptr) {
        [brokerPopoverVC performClose:self];
        brokerPopoverVC = NULL;
    }
}
@end
