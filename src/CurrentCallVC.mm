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
#import <globalinstances.h>

#import "AppDelegate.h"
#import "views/ITProgressIndicator.h"
#import "views/CallView.h"
#import "views/NSColor+RingTheme.h"
#import "delegates/ImageManipulationDelegate.h"
#import "ChatVC.h"
#import "views/IconButton.h"
#import "utils.h"
#import "views/CallMTKView.h"
#import "VideoCommon.h"
#import "views/GradientView.h"
#import "views/MovableView.h"

@interface RendererConnectionsHolder : NSObject

@property QMetaObject::Connection frameUpdated;
@property QMetaObject::Connection started;
@property QMetaObject::Connection stopped;

@end

@implementation RendererConnectionsHolder

@end

@interface CurrentCallVC () <NSPopoverDelegate> {
    std::string convUid_;
    std::string callUid_;
    const lrc::api::account::Info *accountInfo_;
    NSTimer* refreshDurationTimer;
}

// Main container
@property (unsafe_unretained) IBOutlet NSSplitView* splitView;
@property (unsafe_unretained) IBOutlet NSView* backgroundImage;
@property (unsafe_unretained) IBOutlet NSBox* bluerBackgroundEffect;

// Header info
@property (unsafe_unretained) IBOutlet NSView* headerContainer;
@property (unsafe_unretained) IBOutlet NSTextField* timeSpentLabel;

// info
@property (unsafe_unretained) IBOutlet NSStackView* infoContainer;
@property (unsafe_unretained) IBOutlet NSImageView* contactPhoto;
@property (unsafe_unretained) IBOutlet NSTextField* contactNameLabel;
@property (unsafe_unretained) IBOutlet NSTextField* callStateLabel;
@property (unsafe_unretained) IBOutlet NSTextField* contactIdLabel;
@property (unsafe_unretained) IBOutlet IconButton* cancelCallButton;
@property (unsafe_unretained) IBOutlet IconButton* pickUpButton;
@property (unsafe_unretained) IBOutlet ITProgressIndicator *loadingIndicator;

// Call Controls
@property (unsafe_unretained) IBOutlet GradientView* controlsPanel;

@property (unsafe_unretained) IBOutlet IconButton* holdOnOffButton;
@property (unsafe_unretained) IBOutlet IconButton* hangUpButton;
@property (unsafe_unretained) IBOutlet IconButton* recordOnOffButton;
@property (unsafe_unretained) IBOutlet IconButton* muteAudioButton;
@property (unsafe_unretained) IBOutlet IconButton* muteVideoButton;
@property (unsafe_unretained) IBOutlet IconButton* transferButton;
@property (unsafe_unretained) IBOutlet IconButton* addParticipantButton;
@property (unsafe_unretained) IBOutlet IconButton* chatButton;
@property (unsafe_unretained) IBOutlet IconButton* qualityButton;

// Video
@property (unsafe_unretained) IBOutlet CallView *videoView;
@property (unsafe_unretained) IBOutlet CallMTKView *previewView;
@property (unsafe_unretained) IBOutlet MovableView *movableBaseForView;
@property (unsafe_unretained) IBOutlet NSView* hidePreviewBackground;
@property (unsafe_unretained) IBOutlet NSButton* hidePreviewButton;

@property (unsafe_unretained) IBOutlet CallMTKView *videoMTKView;

@property RendererConnectionsHolder* renderConnections;
@property QMetaObject::Connection videoStarted;
@property QMetaObject::Connection selectedCallChanged;
@property QMetaObject::Connection messageConnection;
@property QMetaObject::Connection mediaAddedConnection;
@property QMetaObject::Connection profileUpdatedConnection;

@property (strong) IBOutlet ChatVC* chatVC;

@end

@implementation CurrentCallVC
lrc::api::AVModel* mediaModel;

NSInteger const PREVIEW_WIDTH = 185;
NSInteger const PREVIEW_HEIGHT = 130;
NSInteger const HIDE_PREVIEW_BUTTON_MIN_SIZE = 25;
NSInteger const HIDE_PREVIEW_BUTTON_MAX_SIZE = 35;
NSInteger const PREVIEW_MARGIN = 20;

@synthesize holdOnOffButton, hangUpButton, recordOnOffButton, pickUpButton, chatButton, transferButton, addParticipantButton, timeSpentLabel, muteVideoButton, muteAudioButton, controlsPanel, headerContainer, videoView, previewView, splitView, loadingIndicator, backgroundImage, bluerBackgroundEffect, hidePreviewButton, hidePreviewBackground, movableBaseForView, infoContainer, contactPhoto, contactNameLabel, callStateLabel, contactIdLabel, cancelCallButton;

@synthesize renderConnections;
CVPixelBufferPoolRef pixelBufferPoolDistantView;
CVPixelBufferRef pixelBufferDistantView;
CVPixelBufferPoolRef pixelBufferPoolPreview;
CVPixelBufferRef pixelBufferPreview;

-(void) setCurrentCall:(const std::string&)callUid
          conversation:(const std::string&)convUid
               account:(const lrc::api::account::Info*)account
               avModel:(lrc::api::AVModel *)avModel;
{
    if(account == nil)
        return;

    mediaModel = avModel;
    auto* callModel = account->callModel.get();

    if (not callModel->hasCall(callUid)){
        callUid_.clear();
        return;
    }
    callUid_ = callUid;
    convUid_ = convUid;
    accountInfo_ = account;
    [self.chatVC setConversationUid:convUid model:account->conversationModel.get()];
    auto currentCall = callModel->getCall(callUid_);
    [self setUpButtons: currentCall isRecording: (callModel->isRecording(callUid_) || avModel->getAlwaysRecord())];
    [previewView setHidden: YES];
    videoView.callId = callUid;
    [self setUpPrewviewFrame];
}

-(void) setUpButtons:(lrc::api::call::Info&)callInfo isRecording:(BOOL) isRecording {
    muteAudioButton.image = callInfo.audioMuted ? [NSImage imageNamed:@"ic_action_mute_audio.png"] :
    [NSImage imageNamed:@"ic_action_audio.png"];
    muteVideoButton.image = callInfo.videoMuted ? [NSImage imageNamed:@"ic_action_mute_video.png"] :
    [NSImage imageNamed:@"ic_action_video.png"];
    [muteVideoButton setHidden: callInfo.isAudioOnly ? YES: NO];
    if (isRecording) {
        [recordOnOffButton startBlinkAnimationfrom:[NSColor buttonBlinkColorColor] to:[NSColor whiteColor] scaleFactor: 1 duration: 1.5];
    } else {
        [recordOnOffButton stopBlinkAnimation];
    }
}

- (void) setUpPrewviewFrame {
    CGPoint previewOrigin = CGPointMake(self.videoView.frame.size.width - PREVIEW_WIDTH - PREVIEW_MARGIN, PREVIEW_MARGIN);
    movableBaseForView.frame = CGRectMake(previewOrigin.x, previewOrigin.y, PREVIEW_WIDTH, PREVIEW_HEIGHT);
    self.movableBaseForView.movable = true;
    previewView.frame = movableBaseForView.bounds;
    hidePreviewBackground.frame = [self frameForExpendPreviewButton: false];;
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
    CGColor* color = [[[NSColor blackColor] colorWithAlphaComponent:0.2] CGColor];
    [headerContainer.layer setBackgroundColor:color];
    [bluerBackgroundEffect setWantsLayer:YES];
    bluerBackgroundEffect.alphaValue = 0.6;
    [backgroundImage setWantsLayer: YES];
    backgroundImage.layer.contentsGravity = kCAGravityResizeAspectFill;
    movableBaseForView.wantsLayer = YES;
    movableBaseForView.layer.cornerRadius = 4;
    movableBaseForView.layer.masksToBounds = true;
    movableBaseForView.hostingView = self.videoView;
    [movableBaseForView setAutoresizingMask: NSViewNotSizable | NSViewMaxXMargin | NSViewMaxYMargin | NSViewMinXMargin | NSViewMinYMargin];
    [previewView setAutoresizingMask: NSViewNotSizable | NSViewMaxXMargin | NSViewMaxYMargin | NSViewMinXMargin | NSViewMinYMargin];
    [hidePreviewBackground setAutoresizingMask: NSViewNotSizable | NSViewMaxXMargin | NSViewMaxYMargin | NSViewMinXMargin | NSViewMinYMargin];
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
                [timeSpentLabel setStringValue:@(callModel->getFormattedCallDuration(callUid_).c_str())];
                return;
            }
        }
    }

    // If call is not running anymore or accountInfo_ is not set for any reason
    // we stop the refresh loop
    [refreshDurationTimer invalidate];
    refreshDurationTimer = nil;
}

-(void) updateCall
{
    if (accountInfo_ == nil)
        return;

    auto* callModel = accountInfo_->callModel.get();
    if (not callModel->hasCall(callUid_)) {
        return;
    }

    auto currentCall = callModel->getCall(callUid_);
    NSLog(@"\n status %@ \n",@(lrc::api::call::to_string(currentCall.status).c_str()));
    auto convIt = getConversationFromUid(convUid_, *accountInfo_->conversationModel);
    if (convIt != accountInfo_->conversationModel->allFilteredConversations().end()) {
        NSString* bestName = bestNameForConversation(*convIt, *accountInfo_->conversationModel);
        [contactNameLabel setStringValue:bestName];
        NSString* ringID = bestIDForConversation(*convIt, *accountInfo_->conversationModel);
        if([bestName isEqualToString:ringID]) {
            ringID = @"";
        }
        [contactIdLabel setStringValue:ringID];
    }
    [self setupContactInfo:contactPhoto];

    [timeSpentLabel setStringValue:@(callModel->getFormattedCallDuration(callUid_).c_str())];
    if (refreshDurationTimer == nil)
        refreshDurationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                                target:self
                                                              selector:@selector(updateDurationLabel)
                                                              userInfo:nil
                                                               repeats:YES];
    [self setBackground];

    using Status = lrc::api::call::Status;
    if (currentCall.status == Status::PAUSED) {
        [holdOnOffButton startBlinkAnimationfrom:[NSColor buttonBlinkColorColor] to:[NSColor whiteColor] scaleFactor: 1.0 duration: 1.5];
    } else {
        [holdOnOffButton stopBlinkAnimation];
    }
    callStateLabel.stringValue = currentCall.status == Status::INCOMING_RINGING ? @"wants to talk to you" : @(to_string(currentCall.status).c_str());
    loadingIndicator.hidden = (currentCall.status == Status::SEARCHING ||
                               currentCall.status == Status::CONNECTING ||
                               currentCall.status == Status::OUTGOING_RINGING) ? NO : YES;
    pickUpButton.hidden = (currentCall.status == Status::INCOMING_RINGING) ? NO : YES;
    callStateLabel.hidden = (currentCall.status == Status::IN_PROGRESS) ? YES : NO;
    cancelCallButton.hidden = (currentCall.status == Status::IN_PROGRESS ||
                             currentCall.status == Status::PAUSED) ? YES : NO;

    switch (currentCall.status) {
        case Status::SEARCHING:
        case Status::CONNECTING:
        case Status::OUTGOING_RINGING:
        case Status::INCOMING_RINGING:
            [infoContainer setHidden: NO];
            [headerContainer setHidden:YES];
            [controlsPanel setHidden:YES];
            break;
        /*case Status::CONFERENCE:
            [self setupConference:currentCall];
            break;*/
        case Status::PAUSED:
            [infoContainer setHidden: NO];
            [headerContainer setHidden:NO];
            [controlsPanel setHidden:NO];
            [backgroundImage setHidden:NO];
            [bluerBackgroundEffect setHidden:NO];
            if(!currentCall.isAudioOnly) {
                [self.videoMTKView fillWithBlack];
                [self.previewView fillWithBlack];
                [hidePreviewBackground setHidden:YES];
                [self.previewView setHidden: YES];
                [self.videoMTKView setHidden: YES];
                self.previewView.stopRendering = true;
                self.videoMTKView.stopRendering = true;
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
            [headerContainer setHidden:NO];
            [controlsPanel setHidden:NO];
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
            break;
    }
}

-(void) setUpVideoCallView {
    self.previewView.stopRendering = false;
    self.videoMTKView.stopRendering = false;
    [previewView fillWithBlack];
    [self.videoMTKView fillWithBlack];
    [previewView setHidden: NO];
    [self.videoMTKView setHidden:NO];
    [hidePreviewBackground setHidden: YES];
    [bluerBackgroundEffect setHidden:YES];
    [backgroundImage setHidden:YES];
}

-(void) setUpAudioOnlyView {
    [self.previewView setHidden: YES];
    [self.videoMTKView setHidden: YES];
    [hidePreviewBackground setHidden: YES];
    [bluerBackgroundEffect setHidden:NO];
    [backgroundImage setHidden:NO];
}

-(void) setBackground {
    auto* convModel = accountInfo_->conversationModel.get();
    auto it = getConversationFromUid(convUid_, *convModel);
    NSImage *image= [self getContactImageOfSize:120.0 withDefaultAvatar:NO];
    if(image) {
        CIImage * ciImage = [[CIImage alloc] initWithData:[image TIFFRepresentation]];
        CIContext *context = [[CIContext alloc] init];
        CIFilter *clamp = [CIFilter filterWithName:@"CIAffineClamp"];
        [clamp setValue:[NSAffineTransform transform] forKey:@"inputTransform"];
        [clamp setValue:ciImage forKey: kCIInputImageKey];
        CIFilter* bluerFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
        [bluerFilter setDefaults];
        [bluerFilter setValue:[NSNumber numberWithFloat: 9] forKey:@"inputRadius"];
        [bluerFilter setValue:[clamp valueForKey:kCIOutputImageKey] forKey: kCIInputImageKey];
        CIImage *result = [bluerFilter valueForKey:kCIOutputImageKey];
        CGRect extent = [result extent];
        CGImageRef cgImage = [context createCGImage:result fromRect: [ciImage extent]];
        NSImage *bluredImage = [[NSImage alloc] initWithCGImage:cgImage size:NSSizeFromCGSize(CGSizeMake(image.size.width, image.size.height))];
        backgroundImage.layer.contents = bluredImage;
        [backgroundImage setHidden:NO];
    } else {
        contactNameLabel.textColor = [NSColor darkGrayColor];
        contactNameLabel.textColor = [NSColor darkGrayColor];
        contactIdLabel.textColor = [NSColor darkGrayColor];
        callStateLabel.textColor = [NSColor darkGrayColor];
        backgroundImage.layer.contents = nil;
        [bluerBackgroundEffect setFillColor:[NSColor ringGreyHighlight]];
        [bluerBackgroundEffect setAlphaValue:1];
        [backgroundImage setHidden:YES];
    }
}

-(NSImage *) getContactImageOfSize: (double) size withDefaultAvatar:(BOOL) shouldDrawDefault {
    auto* convModel = accountInfo_->conversationModel.get();
    auto convIt = getConversationFromUid(convUid_, *convModel);
    if (convIt == convModel->allFilteredConversations().end()) {
        return nil;
    }
    if(shouldDrawDefault) {
        auto& imgManip = reinterpret_cast<Interfaces::ImageManipulationDelegate&>(GlobalInstances::pixmapManipulator());
        QVariant photo = imgManip.conversationPhoto(*convIt, *accountInfo_, QSize(size, size), NO);
        return QtMac::toNSImage(qvariant_cast<QPixmap>(photo));
    }
    auto contact = accountInfo_->contactModel->getContact(convIt->participants[0]);
    NSData *imageData = [[NSData alloc] initWithBase64EncodedString:@(contact.profileInfo.avatar.c_str()) options:NSDataBase64DecodingIgnoreUnknownCharacters];
    return [[NSImage alloc] initWithData:imageData];
}

-(void) setupContactInfo:(NSImageView*)imageView
{
    [imageView setImage: [self getContactImageOfSize:120.0 withDefaultAvatar:YES]];
}

-(void) setupConference
{
    [videoView setShouldAcceptInteractions:YES];
    [self.chatButton setHidden:NO];
    [self.addParticipantButton setHidden:NO];
    [self.transferButton setHidden:YES];
}

-(void)collapseRightView
{
    NSView *right = [[splitView subviews] objectAtIndex:1];
    NSView *left  = [[splitView subviews] objectAtIndex:0];
    NSRect leftFrame = [left frame];
    [right setHidden:YES];
    [splitView display];
}

- (void) changeCallSelection:(std::string&)callUid
{
    if (accountInfo_ == nil)
        return;

    auto* callModel = accountInfo_->callModel.get();
    if (not callModel->hasCall(callUid)) {
        return;
    }

    QObject::disconnect(self.selectedCallChanged);
    self.selectedCallChanged = QObject::connect(callModel,
                                                &lrc::api::NewCallModel::callStatusChanged,
                                                [self](const std::string callId) {
                                                    [self updateCall];
                                                });
}

-(void) connectVideoSignals
{
    if (accountInfo_ == nil)
        return;
    [self connectRenderer];
}

-(void) connectRenderer
{
    QObject::disconnect(renderConnections.frameUpdated);
    QObject::disconnect(renderConnections.stopped);
    QObject::disconnect(renderConnections.started);
    renderConnections.started =
    QObject::connect(mediaModel,
                     &lrc::api::AVModel::rendererStarted,
                     [=](const std::string& id) {
                         if (id == lrc::api::video::PREVIEW_RENDERER_ID) {
                             [self.previewView setHidden:NO];
                             self.previewView.stopRendering = false;
                         } else {
                             [self mouseIsMoving: NO];
                             self.videoMTKView.stopRendering = false;
                             [self.videoMTKView setHidden:NO];
                             [bluerBackgroundEffect setHidden:YES];
                             [backgroundImage setHidden:YES];
                             [videoView setShouldAcceptInteractions:YES];
                         }
                         QObject::disconnect(renderConnections.frameUpdated);
                         renderConnections.frameUpdated =
                         QObject::connect(mediaModel,
                                          &lrc::api::AVModel::frameUpdated,
                                          [=](const std::string& id) {
                                              if (id == lrc::api::video::PREVIEW_RENDERER_ID) {
                                                  auto renderer = &mediaModel->getRenderer(lrc::api::video::PREVIEW_RENDERER_ID);
                                                  if(!renderer->isRendering()) {
                                                      return;
                                                  }
                                                  [hidePreviewBackground setHidden: NO];
                                                  [self renderer: renderer renderFrameForPreviewView:previewView];

                                              } else {
                                                  auto renderer = &mediaModel->getRenderer(id);
                                                  if(!renderer->isRendering()) {
                                                      return;
                                                  }
                                                  [self renderer:renderer renderFrameForDistantView: self.videoMTKView];
                                              }
                                          });
                     });
    renderConnections.stopped =
    QObject::connect(mediaModel,
                     &lrc::api::AVModel::rendererStopped,
                     [=](const std::string& id) {
                         QObject::disconnect(renderConnections.frameUpdated);
                         if (id == lrc::api::video::PREVIEW_RENDERER_ID) {
                             [self.previewView setHidden:YES];
                             self.previewView.stopRendering = true;
                         } else {
                             [self mouseIsMoving: YES];
                             self.videoMTKView.stopRendering = true;
                             [self.videoMTKView setHidden:YES];
                             [bluerBackgroundEffect setHidden:NO];
                             [backgroundImage setHidden:NO];
                             [videoView setShouldAcceptInteractions:NO];
                         }
                     });
    renderConnections.frameUpdated =
    QObject::connect(mediaModel,
                     &lrc::api::AVModel::frameUpdated,
                     [=](const std::string& id) {
                         if (id == lrc::api::video::PREVIEW_RENDERER_ID) {
                             auto renderer = &mediaModel->getRenderer(lrc::api::video::PREVIEW_RENDERER_ID);
                             if(!renderer->isRendering()) {
                                 return;
                             }
                             [self renderer: renderer renderFrameForPreviewView:previewView];

                         } else {
                             auto renderer = &mediaModel->getRenderer(id);
                             if(!renderer->isRendering()) {
                                 return;
                             }
                             [self renderer:renderer renderFrameForDistantView: self.videoMTKView];
                         }
                     });
}

-(void) renderer: (const lrc::api::video::Renderer*)renderer renderFrameForPreviewView:(CallMTKView*) view
{
    @autoreleasepool {
        auto framePtr = renderer->currentAVFrame();
        auto frame = framePtr.get();
        if(!frame || !frame->width || !frame->height) {
            return;
        }
        auto frameSize = CGSizeMake(frame->width, frame->height);
        auto rotation = 0;
        if (frame->data[3] != NULL && (CVPixelBufferRef)frame->data[3]) {
            [view renderWithPixelBuffer:(CVPixelBufferRef)frame->data[3]
                                   size: frameSize
                               rotation: rotation
                              fillFrame: true];
            return;
        }
        else if (CVPixelBufferRef pixelBuffer = [self getBufferForPreviewFromFrame:frame]) {
            [view renderWithPixelBuffer: pixelBuffer
                                   size: frameSize
                               rotation: rotation
                              fillFrame: true];
        }
    }
}

-(void) renderer: (const lrc::api::video::Renderer*)renderer renderFrameForDistantView:(CallMTKView*) view
{
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
            [view renderWithPixelBuffer: (CVPixelBufferRef)frame->data[3]
                                   size: frameSize
                               rotation: rotation
                              fillFrame: false];
        }
        if (CVPixelBufferRef pixelBuffer = [self getBufferForDistantViewFromFrame:frame]) {
            [view renderWithPixelBuffer: pixelBuffer
                                   size: frameSize
                               rotation: rotation
                              fillFrame: false];
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

    [self.chatButton setPressed:NO];
    [self collapseRightView];

    [timeSpentLabel setStringValue:@""];
    [contactIdLabel setStringValue:@""];
    [contactNameLabel setStringValue:@""];
    [contactPhoto setImage:nil];
    //background view
    [bluerBackgroundEffect setHidden:NO];
    [bluerBackgroundEffect setFillColor:[NSColor darkGrayColor]];
    [bluerBackgroundEffect setAlphaValue:0.6];
    [backgroundImage setHidden:NO];
    backgroundImage.layer.contents = nil;
    [self.previewView setHidden:YES];
    [self.videoMTKView setHidden:YES];

    contactNameLabel.textColor = [NSColor highlightColor];
    contactNameLabel.textColor = [NSColor highlightColor];
    contactIdLabel.textColor = [NSColor highlightColor];
    callStateLabel.textColor = [NSColor highlightColor];
}

-(void) setupCallView
{
    if (accountInfo_ == nil)
        return;

    auto* callModel = accountInfo_->callModel.get();
    auto* convModel = accountInfo_->conversationModel.get();

    // when call comes in we want to show the controls/header
    [self mouseIsMoving: YES];
    [videoView setShouldAcceptInteractions: NO];

    [self connectVideoSignals];
    /* check if text media is already present */
    if(not callModel->hasCall(callUid_))
        return;

    [loadingIndicator setAnimates:YES];
    [self updateCall];

    /* monitor media for messaging text messaging */
    QObject::disconnect(self.messageConnection);
    self.messageConnection = QObject::connect(convModel,
                                              &lrc::api::ConversationModel::interactionStatusUpdated,
                                              [self] (std::string convUid,
                                                      uint64_t msgId,
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
                     [self](const std::string &contactUri) {
                         auto convIt = getConversationFromUid(convUid_, *accountInfo_->conversationModel.get());
                         if (convIt == accountInfo_->conversationModel->allFilteredConversations().end()) {
                             return;
                         }
                         if (convIt->participants.empty()) {
                             return;

                         }
                         auto& contact = accountInfo_->contactModel->getContact(convIt->participants[0]);
                         if (contact.profileInfo.type == lrc::api::profile::Type::RING && contact.profileInfo.uri == contactUri)
                             accountInfo_->conversationModel->makePermanent(convUid_);
                         [contactPhoto setImage: [self getContactImageOfSize:120.0 withDefaultAvatar:YES]];
                         [self.delegate conversationInfoUpdatedFor:convUid_];
                         [self setBackground];
                     });
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
        // first make sure everything is disconnected
        [self cleanUp];
//        if (currentCall_) {
//            [self animateIn];
//        }
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
    auto convIt = getConversationFromUid(convUid_, *accountInfo_->conversationModel.get());
    if (convIt != accountInfo_->conversationModel->allFilteredConversations().end()) {
        auto& contact = accountInfo_->contactModel->getContact(convIt->participants[0]);
        if (contact.profileInfo.type == lrc::api::profile::Type::PENDING)
            accountInfo_->conversationModel->makePermanent(convUid_);
    }

    auto* callModel = accountInfo_->callModel.get();

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
    auto currentCall = callModel->getCall(callUid_);

    callModel->togglePause(callUid_);
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

- (IBAction)muteAudio:(id)sender
{
    if (accountInfo_ == nil)
        return;

    auto* callModel = accountInfo_->callModel.get();
    auto currentCall = callModel->getCall(callUid_);
    if (currentCall.audioMuted) {
        muteAudioButton.image = [NSImage imageNamed:@"ic_action_audio.png"];
    } else {
       muteAudioButton.image = [NSImage imageNamed:@"ic_action_mute_audio.png"];
    }
    callModel->toggleMedia(callUid_, lrc::api::NewCallModel::Media::AUDIO);
}

- (IBAction)muteVideo:(id)sender
{
    if (accountInfo_ == nil)
        return;
    auto* callModel = accountInfo_->callModel.get();
    auto currentCall = callModel->getCall(callUid_);
    if(!currentCall.isAudioOnly) {
        if (currentCall.videoMuted) {
            muteVideoButton.image = [NSImage imageNamed:@"ic_action_video.png"];
        } else {
            muteVideoButton.image = [NSImage imageNamed:@"ic_action_mute_video.png"];
        }
    }
    callModel->toggleMedia(callUid_, lrc::api::NewCallModel::Media::VIDEO);
}

- (IBAction)toggleTransferView:(id)sender {

}

- (IBAction)toggleAddParticipantView:(id)sender {

}
- (IBAction)hidePreview:(id)sender {
    CGRect previewFrame = previewView.frame;
    CGRect newPreviewFrame, bcHidePreviewFrame;
    if (previewFrame.size.width > HIDE_PREVIEW_BUTTON_MAX_SIZE) {
        self.movableBaseForView.movable = false;
        newPreviewFrame = self.getVideoPreviewCollapsedSize;
        bcHidePreviewFrame = [self frameForExpendPreviewButton: true];
        hidePreviewButton.image = [NSImage imageNamed: NSImageNameTouchBarEnterFullScreenTemplate];
    } else {
        self.movableBaseForView.movable = true;
        newPreviewFrame = CGRectMake(0, 0, PREVIEW_WIDTH, PREVIEW_HEIGHT);
        bcHidePreviewFrame = [self frameForExpendPreviewButton: false];
        hidePreviewButton.image = [NSImage imageNamed: NSImageNameTouchBarExitFullScreenTemplate];
    }
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
        context.duration = 0.2f;
        context.timingFunction = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseOut];
        previewView.animator.frame = newPreviewFrame;
    } completionHandler: nil];
    hidePreviewBackground.frame = bcHidePreviewFrame;
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
}

-(void) mouseIsMoving:(BOOL) move
{
    [[controlsPanel animator] setAlphaValue:move]; // fade out
    [[headerContainer animator] setAlphaValue:move];
}

- (BOOL)splitView:(NSSplitView *)splitView shouldHideDividerAtIndex:(NSInteger)dividerIndex
{
    return YES;
}

-(void) screenShare {
    NSScreen *mainScreen = [NSScreen mainScreen];
    NSRect screenFrame = mainScreen.frame;
    QRect captureRect = QRect(screenFrame.origin.x, screenFrame.origin.y, screenFrame.size.width, screenFrame.size.height);
    mediaModel->setDisplay(0, screenFrame.origin.x, screenFrame.origin.y, screenFrame.size.width, screenFrame.size.height);
}
-(void) switchToDevice:(int)deviceID {
    auto devices = mediaModel->getDevices();
    auto device = devices[deviceID];
    mediaModel->switchInputTo(device);
}

-(std::vector<std::string>) getDeviceList {
    return mediaModel->getDevices();
}

-(void) switchToFile:(std::string)uri {
    mediaModel->setInputFile(QUrl::fromLocalFile(uri.c_str()).toLocalFile().toStdString());
}

-(CGRect) getVideoPreviewCollapsedSize {
    CGPoint origin;
    switch (movableBaseForView.closestCorner) {
        case TOP_LEFT:
            origin = CGPointMake(0, movableBaseForView.frame.size.height - HIDE_PREVIEW_BUTTON_MAX_SIZE);
            break;
        case BOTTOM_LEFT:
            origin = CGPointMake(0, 0);
            break;
        case TOP_RIGHT:
            origin = CGPointMake(movableBaseForView.frame.size.width - HIDE_PREVIEW_BUTTON_MAX_SIZE, movableBaseForView.frame.size.height - HIDE_PREVIEW_BUTTON_MAX_SIZE);
            break;
        case BOTTOM_RIGHT:
            origin = CGPointMake(movableBaseForView.frame.size.width - HIDE_PREVIEW_BUTTON_MAX_SIZE, 0);
            break;
    }
    return CGRectMake(origin.x, origin.y, HIDE_PREVIEW_BUTTON_MAX_SIZE, HIDE_PREVIEW_BUTTON_MAX_SIZE);
}

-(CGRect) frameForExpendPreviewButton:(BOOL)collapsed  {
    CGFloat size = collapsed ? HIDE_PREVIEW_BUTTON_MAX_SIZE : HIDE_PREVIEW_BUTTON_MIN_SIZE;
    CGPoint origin = CGPointMake(self.previewView.frame.size.width - size,
                                 self.previewView.frame.size.height - size);
    return CGRectMake(origin.x, origin.y, size, size);
}

@end
