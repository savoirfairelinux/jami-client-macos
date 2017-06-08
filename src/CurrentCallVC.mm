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

#import <QuartzCore/QuartzCore.h>

///Qt
#import <QMimeData>
#import <QtMacExtras/qmacfunctions.h>
#import <QtCore/qabstractitemmodel.h>
#import <QItemSelectionModel>
#import <QItemSelection>
#import <QPixmap>

///LRC
#import <call.h>
#import <callmodel.h>
#import <recentmodel.h>
#import <useractionmodel.h>
#import <contactmethod.h>
#import <video/previewmanager.h>
#import <video/renderer.h>
#import <media/text.h>
#import <person.h>
#import <globalinstances.h>

#import "AppDelegate.h"
#import "views/ITProgressIndicator.h"
#import "views/CallView.h"
#import "delegates/ImageManipulationDelegate.h"
#import "PersonLinkerVC.h"
#import "ChatVC.h"
#import "BrokerVC.h"
#import "views/IconButton.h"
#import "views/CallLayer.h"

@interface RendererConnectionsHolder : NSObject

@property QMetaObject::Connection frameUpdated;
@property QMetaObject::Connection started;
@property QMetaObject::Connection stopped;

@end

@implementation RendererConnectionsHolder

@end

@interface CurrentCallVC () <NSPopoverDelegate, ContactLinkedDelegate>

// Main container
@property (unsafe_unretained) IBOutlet NSSplitView* splitView;

// Header info
@property (unsafe_unretained) IBOutlet NSView* headerContainer;
@property (unsafe_unretained) IBOutlet NSTextField* personLabel;
@property (unsafe_unretained) IBOutlet NSTextField* stateLabel;
@property (unsafe_unretained) IBOutlet NSTextField* timeSpentLabel;
@property (unsafe_unretained) IBOutlet NSImageView* personPhoto;

// Call Controls
@property (unsafe_unretained) IBOutlet NSView* controlsPanel;

@property QHash<int, IconButton*> actionHash;
@property (unsafe_unretained) IBOutlet IconButton* holdOnOffButton;
@property (unsafe_unretained) IBOutlet IconButton* hangUpButton;
@property (unsafe_unretained) IBOutlet IconButton* recordOnOffButton;
@property (unsafe_unretained) IBOutlet IconButton* pickUpButton;
@property (unsafe_unretained) IBOutlet IconButton* muteAudioButton;
@property (unsafe_unretained) IBOutlet IconButton* muteVideoButton;
@property (unsafe_unretained) IBOutlet IconButton* addContactButton;
@property (unsafe_unretained) IBOutlet IconButton* transferButton;
@property (unsafe_unretained) IBOutlet IconButton* addParticipantButton;
@property (unsafe_unretained) IBOutlet IconButton* chatButton;

@property (unsafe_unretained) IBOutlet NSView* advancedPanel;
@property (unsafe_unretained) IBOutlet IconButton* advancedButton;


// Join call panel
@property (unsafe_unretained) IBOutlet NSView* joinPanel;
@property (unsafe_unretained) IBOutlet NSButton* mergeCallsButton;

@property (strong) NSPopover* addToContactPopover;
@property (strong) NSPopover* brokerPopoverVC;
@property (strong) IBOutlet ChatVC* chatVC;

// Ringing call panel
@property (unsafe_unretained) IBOutlet NSView* ringingPanel;
@property (unsafe_unretained) IBOutlet NSImageView* incomingPersonPhoto;
@property (unsafe_unretained) IBOutlet NSTextField* incomingDisplayName;

// Outgoing call panel
@property (unsafe_unretained) IBOutlet NSView* outgoingPanel;
@property (unsafe_unretained) IBOutlet ITProgressIndicator *loadingIndicator;

// Video
@property (unsafe_unretained) IBOutlet CallView *videoView;
@property (unsafe_unretained) IBOutlet NSView *previewView;

@property RendererConnectionsHolder* previewHolder;
@property RendererConnectionsHolder* videoHolder;
@property QMetaObject::Connection videoStarted;
@property QMetaObject::Connection selectedCallChanged;
@property QMetaObject::Connection messageConnection;
@property QMetaObject::Connection mediaAddedConnection;

@end

@implementation CurrentCallVC
@synthesize personLabel, personPhoto, actionHash, stateLabel, holdOnOffButton, hangUpButton,
            recordOnOffButton, pickUpButton, chatButton, transferButton, addParticipantButton, timeSpentLabel,
            muteVideoButton, muteAudioButton, controlsPanel, advancedPanel, advancedButton, headerContainer, videoView, incomingDisplayName, incomingPersonPhoto,
            previewView, splitView, loadingIndicator, ringingPanel, joinPanel, outgoingPanel;

@synthesize previewHolder;
@synthesize videoHolder;

- (void) updateAllActions
{
    for (int i = 0 ; i < CallModel::instance().userActionModel()->rowCount() ; i++) {
        [self updateActionAtIndex:i];
    }
}

- (void) updateActionAtIndex:(int) row
{
    const QModelIndex& idx = CallModel::instance().userActionModel()->index(row,0);
    UserActionModel::Action action = qvariant_cast<UserActionModel::Action>(idx.data(UserActionModel::Role::ACTION));
    if (auto a = actionHash[(int) action]) {
        [a setHidden:!(idx.flags() & Qt::ItemIsEnabled)];
        [a setPressed:(idx.data(Qt::CheckStateRole) == Qt::Checked) ? YES : NO];
    }
}

-(void) updateCall:(BOOL) firstRun
{
    QModelIndex callIdx = CallModel::instance().selectionModel()->currentIndex();
    if (!callIdx.isValid()) {
        return;
    }
    auto current = CallModel::instance().selectedCall();

    [personLabel setStringValue:callIdx.data(Qt::DisplayRole).toString().toNSString()];
    [timeSpentLabel setStringValue:callIdx.data((int)Call::Role::Length).toString().toNSString()];
    [stateLabel setStringValue:callIdx.data((int)Call::Role::HumanStateName).toString().toNSString()];

    if (firstRun) {
        QVariant photo = GlobalInstances::pixmapManipulator().callPhoto(current, QSize(100,100));
        [personPhoto setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(photo))];
    }

    auto contactmethod = qvariant_cast<Call*>(callIdx.data(static_cast<int>(Call::Role::Object)))->peerContactMethod();
    BOOL shouldShow = (!contactmethod->contact() || contactmethod->contact()->isPlaceHolder());
    [self.addContactButton setHidden:!shouldShow];

    // Default values for this views
    [loadingIndicator setHidden:YES];
    [videoView setShouldAcceptInteractions:NO];
    [ringingPanel setHidden:YES];
    [outgoingPanel setHidden:YES];
    [controlsPanel setHidden:NO];
    [headerContainer setHidden:NO];

    auto state = callIdx.data((int)Call::Role::State).value<Call::State>();
    switch (state) {
        case Call::State::NEW:
            break;
        case Call::State::DIALING:
        case Call::State::INITIALIZATION:
        case Call::State::CONNECTED:
            [loadingIndicator setHidden:NO];
        case Call::State::RINGING:
            [controlsPanel setHidden:YES];
            [outgoingPanel setHidden:NO];
            break;
        case Call::State::INCOMING:
            [self setupIncoming:current];
            break;
        case Call::State::CONFERENCE:
            [self setupConference:current];
            break;
        case Call::State::CURRENT:
            [self setupCurrent:current];
            break;
        case Call::State::HOLD:
            break;
        case Call::State::BUSY:
            break;
        case Call::State::OVER:
        case Call::State::FAILURE:
            [controlsPanel setHidden:YES];
            [outgoingPanel setHidden:NO];
            if(self.splitView.isInFullScreenMode)
                [self.splitView exitFullScreenModeWithOptions:nil];
            break;
    }

}

-(void) setupIncoming:(Call*) c
{
    [ringingPanel setHidden:NO];
    [controlsPanel setHidden:YES];
    [headerContainer setHidden:YES];
    QVariant photo = GlobalInstances::pixmapManipulator().callPhoto(c, QSize(100,100));
    [incomingPersonPhoto setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(photo))];
    [incomingDisplayName setStringValue:c->formattedName().toNSString()];
}

-(void) setupCurrent:(Call*) c
{
    [joinPanel setHidden:!c->hasParentCall()];
    [controlsPanel setHidden:c->hasParentCall()];
    [videoView setShouldAcceptInteractions:YES];
    [self.chatButton setHidden:NO];
    [self.addParticipantButton setHidden:NO];
    [self.transferButton setHidden:NO];
}

-(void) setupConference:(Call*) c
{
    [videoView setShouldAcceptInteractions:YES];
    [self.chatButton setHidden:NO];
    [joinPanel setHidden:YES];
    [self.addParticipantButton setHidden:NO];
    [self.transferButton setHidden:YES];
}


- (void)awakeFromNib
{
    NSLog(@"INIT CurrentCall VC");
    [self.view setWantsLayer:YES];

    actionHash[ (int)UserActionModel::Action::ACCEPT] = pickUpButton;
    actionHash[ (int)UserActionModel::Action::HOLD  ] = holdOnOffButton;
    actionHash[ (int)UserActionModel::Action::RECORD] = recordOnOffButton;
    actionHash[ (int)UserActionModel::Action::HANGUP] = hangUpButton;
    actionHash[ (int)UserActionModel::Action::MUTE_AUDIO] = muteAudioButton;
    actionHash[ (int)UserActionModel::Action::MUTE_VIDEO] = muteVideoButton;

    [previewView setWantsLayer:YES];
    [previewView.layer setBackgroundColor:[NSColor blackColor].CGColor];
    [previewView.layer setContentsGravity:kCAGravityResizeAspectFill];
    [previewView.layer setFrame:previewView.frame];

    [controlsPanel setWantsLayer:YES];
    [controlsPanel.layer setBackgroundColor:[NSColor clearColor].CGColor];
    [controlsPanel.layer setFrame:controlsPanel.frame];

    previewHolder = [[RendererConnectionsHolder alloc] init];
    videoHolder = [[RendererConnectionsHolder alloc] init];

    [loadingIndicator setColor:[NSColor whiteColor]];
    [loadingIndicator setNumberOfLines:100];
    [loadingIndicator setWidthOfLine:2];
    [loadingIndicator setLengthOfLine:2];
    [loadingIndicator setInnerMargin:30];

    [self.videoView setCallDelegate:self];

    [self connect];
}

- (void) connect
{
    QObject::connect(RecentModel::instance().selectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {
                         auto call = RecentModel::instance().getActiveCall(current);
                         if(!current.isValid() || !call) {
                             return;
                         }

                         [self changeCallSelection:call];

                         if (call->state() == Call::State::HOLD) {
                             call << Call::Action::HOLD;
                         }

                         [self collapseRightView];
                         [self updateCall:YES];
                         [self updateAllActions];
                     });

    QObject::connect(CallModel::instance().userActionModel(),
                     &QAbstractItemModel::dataChanged,
                     [=](const QModelIndex &topLeft, const QModelIndex &bottomRight) {
                         const int first(topLeft.row()),last(bottomRight.row());
                         for(int i = first; i <= last;i++) {
                             [self updateActionAtIndex:i];
                         }
                     });

    QObject::connect(&CallModel::instance(),
                     &CallModel::callStateChanged,
                     [self](Call* c, Call::State state) {
                         auto current = CallModel::instance().selectionModel()->currentIndex();
                         if (!current.isValid())
                             [self animateOut];
                         else if (CallModel::instance().getIndex(c) == current) {
                             if (c->state() == Call::State::OVER) {
                                 RecentModel::instance().selectionModel()->clearCurrentIndex();
                             } else {
                                 [self updateCall:NO];
                             }
                         }
                     });

    QObject::connect(&CallModel::instance(),
                     &CallModel::incomingCall,
                     [self](Call* c) {
                         [self changeCallSelection:c];
                     });
}

- (void) changeCallSelection:(Call* )c
{
    QObject::disconnect(self.selectedCallChanged);
    CallModel::instance().selectCall(c);
    self.selectedCallChanged = QObject::connect(CallModel::instance().selectedCall(),
                                                &Call::changed,
                                                [=]() {
                                                    [self updateCall:NO];
                                                });
}

- (void) monitorIncomingTextMessages:(Media::Text*) media
{
    /* connect to incoming chat messages to open the chat view */
    QObject::disconnect(self.messageConnection);
    self.messageConnection = QObject::connect(media,
                                              &Media::Text::messageReceived,
                                              [self] (const QMap<QString,QString>& m) {
                                                  if([[self splitView] isSubviewCollapsed:[[[self splitView] subviews] objectAtIndex: 1]])
                                                      [self uncollapseRightView];
                                              });
}

-(void) connectVideoSignals
{
    QModelIndex idx = CallModel::instance().selectionModel()->currentIndex();
    Call* call = CallModel::instance().getCall(idx);
    QObject::disconnect(self.videoStarted);
    self.videoStarted = QObject::connect(call,
                     &Call::videoStarted,
                     [=](Video::Renderer* renderer) {
                         NSLog(@"Video started!");
                         [self connectVideoRenderer:renderer];
                     });

    if(call->videoRenderer())
    {
        [self connectVideoRenderer:call->videoRenderer()];
    }

    [self connectPreviewRenderer];

}

-(void) connectPreviewRenderer
{
    QObject::disconnect(previewHolder.frameUpdated);
    QObject::disconnect(previewHolder.stopped);
    QObject::disconnect(previewHolder.started);
    previewHolder.started = QObject::connect(&Video::PreviewManager::instance(),
                     &Video::PreviewManager::previewStarted,
                     [=](Video::Renderer* renderer) {
                         QObject::disconnect(previewHolder.frameUpdated);
                         previewHolder.frameUpdated = QObject::connect(renderer,
                                                                       &Video::Renderer::frameUpdated,
                                                                       [=]() {
                                                                           [self renderer:Video::PreviewManager::instance().previewRenderer()
                                                                       renderFrameForPreviewView:previewView];
                                                                       });
                     });

    previewHolder.stopped = QObject::connect(&Video::PreviewManager::instance(),
                     &Video::PreviewManager::previewStopped,
                     [=](Video::Renderer* renderer) {
                         QObject::disconnect(previewHolder.frameUpdated);
                        [previewView.layer setContents:nil];
                     });

    previewHolder.frameUpdated = QObject::connect(Video::PreviewManager::instance().previewRenderer(),
                                                 &Video::Renderer::frameUpdated,
                                                 [=]() {
                                                     [self renderer:Video::PreviewManager::instance().previewRenderer()
                                                            renderFrameForPreviewView:previewView];
                                                 });
}

-(void) connectVideoRenderer: (Video::Renderer*)renderer
{
    QObject::disconnect(videoHolder.frameUpdated);
    QObject::disconnect(videoHolder.started);
    QObject::disconnect(videoHolder.stopped);
    videoHolder.frameUpdated = QObject::connect(renderer,
                     &Video::Renderer::frameUpdated,
                     [=]() {
                         [self renderer:renderer renderFrameForDistantView:videoView];
                     });

    videoHolder.started = QObject::connect(renderer,
                     &Video::Renderer::started,
                     [=]() {
                         QObject::disconnect(videoHolder.frameUpdated);
                         videoHolder.frameUpdated = QObject::connect(renderer,
                                                                     &Video::Renderer::frameUpdated,
                                                                     [=]() {
                                                                         [self renderer:renderer renderFrameForDistantView:videoView];
                                                                     });
                     });

    videoHolder.stopped = QObject::connect(renderer,
                     &Video::Renderer::stopped,
                     [=]() {
                         QObject::disconnect(videoHolder.frameUpdated);
                        [videoView.layer setContents:nil];
                     });
}

-(void) renderer: (Video::Renderer*)renderer renderFrameForPreviewView:(NSView*) view
{
    QSize res = renderer->size();

    auto frame_ptr = renderer->currentFrame();
    auto frame_data = frame_ptr.ptr;
    if (!frame_data)
        return;

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef newContext = CGBitmapContextCreate(frame_data,
                                                    res.width(),
                                                    res.height(),
                                                    8,
                                                    4*res.width(),
                                                    colorSpace,
                                                    kCGImageAlphaPremultipliedLast);


    CGImageRef newImage = CGBitmapContextCreateImage(newContext);

    /*We release some components*/
    CGContextRelease(newContext);
    CGColorSpaceRelease(colorSpace);

    [CATransaction begin];
    view.layer.contents = (__bridge id)newImage;
    [CATransaction commit];

    CFRelease(newImage);
}

-(void) renderer: (Video::Renderer*)renderer renderFrameForDistantView:(CallView*) view
{
    QSize res = renderer->size();

    auto frame_ptr = renderer->currentFrame();
    if (!frame_ptr.ptr)
        return;

    CallLayer* callLayer = (CallLayer*) view.layer;

    [callLayer setCurrentFrame:std::move(frame_ptr) ofSize:res];
}

- (void) initFrame
{
    [self.view setFrame:self.view.superview.bounds];
    [self.view setHidden:YES];
    self.view.layer.position = self.view.frame.origin;
    [self collapseRightView];
}

# pragma private IN/OUT animations

-(void) animateIn
{
    CGRect frame = CGRectOffset(self.view.superview.bounds, -self.view.superview.bounds.size.width, 0);
    [self.view setHidden:NO];

    [CATransaction begin];
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
    [animation setFromValue:[NSValue valueWithPoint:frame.origin]];
    [animation setToValue:[NSValue valueWithPoint:self.view.superview.bounds.origin]];
    [animation setDuration:0.2f];
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn]];
    [CATransaction setCompletionBlock:^{

        // when call comes in we want to show the controls/header
        [self mouseIsMoving:YES];

        [self connectVideoSignals];
        /* check if text media is already present */
        if(!CallModel::instance().selectedCall())
            return;

        [loadingIndicator setAnimates:YES];
        [self updateCall:YES];

        if (CallModel::instance().selectedCall()->hasMedia(Media::Media::Type::TEXT, Media::Media::Direction::IN)) {
            Media::Text *text = CallModel::instance().selectedCall()->firstMedia<Media::Text>(Media::Media::Direction::IN);
            [self monitorIncomingTextMessages:text];
        } else if (CallModel::instance().selectedCall()->hasMedia(Media::Media::Type::TEXT, Media::Media::Direction::OUT)) {
            Media::Text *text = CallModel::instance().selectedCall()->firstMedia<Media::Text>(Media::Media::Direction::OUT);
            [self monitorIncomingTextMessages:text];
        } else {
            /* monitor media for messaging text messaging */
            self.mediaAddedConnection = QObject::connect(CallModel::instance().selectedCall(),
                                                         &Call::mediaAdded,
                                                         [self] (Media::Media* media) {
                                                             if (media->type() == Media::Media::Type::TEXT) {                                                                     [self monitorIncomingTextMessages:(Media::Text*)media];
                                                                 QObject::disconnect(self.mediaAddedConnection);
                                                             }
                                                         });
        }
    }];
    [self.view.layer addAnimation:animation forKey:animation.keyPath];

    [CATransaction commit];
}

-(void) cleanUp
{
    QObject::disconnect(videoHolder.frameUpdated);
    QObject::disconnect(videoHolder.started);
    QObject::disconnect(videoHolder.stopped);
    QObject::disconnect(previewHolder.frameUpdated);
    QObject::disconnect(previewHolder.stopped);
    QObject::disconnect(previewHolder.started);
    [previewView.layer setContents:nil];

    [_brokerPopoverVC performClose:self];
    [self.addToContactPopover performClose:self];

    [self.chatButton setHidden:YES];
    [self.addParticipantButton setHidden:YES];
    [self.transferButton setHidden:YES];

    [self.chatButton setPressed:NO];
    [self.mergeCallsButton setState:NSOffState];
    [self collapseRightView];

    [personLabel setStringValue:@""];
    [timeSpentLabel setStringValue:@""];
    [stateLabel setStringValue:@""];
    [self.addContactButton setHidden:YES];

    [advancedButton setPressed:NO];
    [advancedPanel setHidden:YES];
}

-(void) animateOut
{
    if(self.view.frame.origin.x < 0) {
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
        if (RecentModel::instance().getActiveCall(RecentModel::instance().selectionModel()->currentIndex())) {
            [self animateIn];
        }
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

-(void)collapseRightView
{
    NSView *right = [[splitView subviews] objectAtIndex:1];
    NSView *left  = [[splitView subviews] objectAtIndex:0];
    NSRect leftFrame = [left frame];
    [right setHidden:YES];
    [splitView display];
}

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


#pragma mark - Button methods

- (IBAction)addToContact:(NSButton*) sender {
    auto contactmethod = CallModel::instance().getCall(CallModel::instance().selectionModel()->currentIndex())->peerContactMethod();

    if (self.addToContactPopover != nullptr) {
        [self.addToContactPopover performClose:self];
        self.addToContactPopover = NULL;
    } else if (!contactmethod->contact() || contactmethod->contact()->isPlaceHolder()) {
        auto* editorVC = [[PersonLinkerVC alloc] initWithNibName:@"PersonLinker" bundle:nil];
        [editorVC setMethodToLink:contactmethod];
        [editorVC setContactLinkedDelegate:self];
        self.addToContactPopover = [[NSPopover alloc] init];
        [self.addToContactPopover setContentSize:editorVC.view.frame.size];
        [self.addToContactPopover setContentViewController:editorVC];
        [self.addToContactPopover setAnimates:YES];
        [self.addToContactPopover setBehavior:NSPopoverBehaviorTransient];
        [self.addToContactPopover setDelegate:self];

        [self.addToContactPopover showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSMaxXEdge];
    }

    [videoView setCallDelegate:nil];
}

- (IBAction)hangUp:(id)sender {
    CallModel::instance().getCall(CallModel::instance().selectionModel()->currentIndex()) << Call::Action::REFUSE;
}

- (IBAction)accept:(id)sender {
    CallModel::instance().getCall(CallModel::instance().selectionModel()->currentIndex()) << Call::Action::ACCEPT;
}

- (IBAction)toggleRecording:(id)sender {
    CallModel::instance().getCall(CallModel::instance().selectionModel()->currentIndex()) << Call::Action::RECORD_AUDIO;
}

- (IBAction)toggleHold:(id)sender {
    CallModel::instance().getCall(CallModel::instance().selectionModel()->currentIndex()) << Call::Action::HOLD;
}

- (IBAction)toggleAdvancedControls:(id)sender {
    [advancedButton setPressed:!advancedButton.isPressed];
    [advancedPanel setHidden:![advancedButton isPressed]];
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
        CallModel::instance().getCall(CallModel::instance().selectionModel()->currentIndex())->addOutgoingMedia<Media::Text>();
    } else {
        [self collapseRightView];
    }
    [chatButton setPressed:rightViewCollapsed];
}

- (IBAction)muteAudio:(id)sender
{
    UserActionModel* uam = CallModel::instance().userActionModel();
    uam << UserActionModel::Action::MUTE_AUDIO;
}

- (IBAction)muteVideo:(id)sender
{
    UserActionModel* uam = CallModel::instance().userActionModel();
    uam << UserActionModel::Action::MUTE_VIDEO;
}

- (IBAction)toggleTransferView:(id)sender {
    if (_brokerPopoverVC != nullptr) {
        [_brokerPopoverVC performClose:self];
        _brokerPopoverVC = NULL;
        [self.transferButton setPressed:NO];
    } else {
        auto* brokerVC = [[BrokerVC alloc] initWithMode:BrokerMode::TRANSFER];
        _brokerPopoverVC = [[NSPopover alloc] init];
        [_brokerPopoverVC setContentSize:brokerVC.view.frame.size];
        [_brokerPopoverVC setContentViewController:brokerVC];
        [_brokerPopoverVC setAnimates:YES];
        [_brokerPopoverVC setBehavior:NSPopoverBehaviorTransient];
        [_brokerPopoverVC setDelegate:self];
        [_brokerPopoverVC showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSMinYEdge];
        [videoView setCallDelegate:nil];
    }
}

- (IBAction)toggleAddParticipantView:(id)sender {
    if (_brokerPopoverVC != nullptr) {
        [_brokerPopoverVC performClose:self];
        _brokerPopoverVC = NULL;
        [self.addParticipantButton setPressed:NO];
    } else {
        auto* brokerVC = [[BrokerVC alloc] initWithMode:BrokerMode::CONFERENCE];
        _brokerPopoverVC = [[NSPopover alloc] init];
        [_brokerPopoverVC setContentSize:brokerVC.view.frame.size];
        [_brokerPopoverVC setContentViewController:brokerVC];
        [_brokerPopoverVC setAnimates:YES];
        [_brokerPopoverVC setBehavior:NSPopoverBehaviorTransient];
        [_brokerPopoverVC setDelegate:self];
        [_brokerPopoverVC showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSMinYEdge];
        [videoView setCallDelegate:nil];
    }
}

/**
 *  Merge current call with its parent call
 */
- (IBAction)mergeCalls:(id)sender
{
    auto current = CallModel::instance().selectedCall();
    current->joinToParent();
}

#pragma mark - NSPopOverDelegate

- (void)popoverWillClose:(NSNotification *)notification
{
    if (_brokerPopoverVC != nullptr) {
        [_brokerPopoverVC performClose:self];
        _brokerPopoverVC = NULL;
    }

    if (self.addToContactPopover != nullptr) {
        [self.addToContactPopover performClose:self];
        self.addToContactPopover = NULL;
    }

    [self.addContactButton setPressed:NO];
    [self.transferButton setPressed:NO];
    [self.addParticipantButton setState:NSOffState];
}

- (void)popoverDidClose:(NSNotification *)notification
{
    [videoView setCallDelegate:self];
}

#pragma mark - ContactLinkedDelegate

- (void)contactLinked
{
    if (self.addToContactPopover != nullptr) {
        [self.addToContactPopover performClose:self];
        self.addToContactPopover = NULL;
    }
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

@end
