/*
 *  Copyright (C) 2015 Savoir-faire Linux Inc.
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

#import <call.h>
#import <callmodel.h>
#import <useractionmodel.h>
#import <contactmethod.h>
#import <qabstractitemmodel.h>
#import <QItemSelectionModel>
#import <QItemSelection>
#import <video/previewmanager.h>
#import <video/renderer.h>
#import <media/text.h>
#import <person.h>

#import "views/ITProgressIndicator.h"
#import "views/CallView.h"
#import "PersonLinkerVC.h"
#import "ChatVC.h"
#import "BrokerVC.h"

@interface RendererConnectionsHolder : NSObject

@property QMetaObject::Connection frameUpdated;
@property QMetaObject::Connection started;
@property QMetaObject::Connection stopped;

@end

@implementation RendererConnectionsHolder

@end

@interface CurrentCallVC () <NSPopoverDelegate, ContactLinkedDelegate>

@property (unsafe_unretained) IBOutlet NSTextField* personLabel;
@property (unsafe_unretained) IBOutlet NSTextField* stateLabel;
@property (unsafe_unretained) IBOutlet NSButton* holdOnOffButton;
@property (unsafe_unretained) IBOutlet NSButton* hangUpButton;
@property (unsafe_unretained) IBOutlet NSButton* recordOnOffButton;
@property (unsafe_unretained) IBOutlet NSButton* pickUpButton;
@property (unsafe_unretained) IBOutlet NSButton* muteAudioButton;
@property (unsafe_unretained) IBOutlet NSButton* muteVideoButton;
@property (unsafe_unretained) IBOutlet NSButton* addContactButton;
@property (unsafe_unretained) IBOutlet NSButton* transferButton;
@property (unsafe_unretained) IBOutlet NSView* headerContainer;

@property (unsafe_unretained) IBOutlet ITProgressIndicator *loadingIndicator;

@property (unsafe_unretained) IBOutlet NSTextField* timeSpentLabel;
@property (unsafe_unretained) IBOutlet NSView* controlsPanel;
@property (unsafe_unretained) IBOutlet NSSplitView* splitView;
@property (unsafe_unretained) IBOutlet NSButton* chatButton;

@property (strong) NSPopover* addToContactPopover;
@property (strong) NSPopover* transferPopoverVC;
@property (strong) IBOutlet ChatVC* chatVC;

@property QHash<int, NSButton*> actionHash;

// Video
@property (unsafe_unretained) IBOutlet CallView *videoView;
@property CALayer* videoLayer;
@property (unsafe_unretained) IBOutlet NSView *previewView;
@property CALayer* previewLayer;

@property RendererConnectionsHolder* previewHolder;
@property RendererConnectionsHolder* videoHolder;
@property QMetaObject::Connection videoStarted;
@property QMetaObject::Connection messageConnection;
@property QMetaObject::Connection mediaAddedConnection;

@end

@implementation CurrentCallVC
@synthesize personLabel, actionHash, stateLabel, holdOnOffButton, hangUpButton,
            recordOnOffButton, pickUpButton, chatButton, transferButton, timeSpentLabel,
            muteVideoButton, muteAudioButton, controlsPanel, headerContainer, videoView,
            videoLayer, previewLayer, previewView, splitView, loadingIndicator;

@synthesize previewHolder;
@synthesize videoHolder;

- (void) updateAllActions
{
    for(int i = 0 ; i <= CallModel::instance().userActionModel()->rowCount() ; i++) {
        [self updateActionAtIndex:i];
    }
}

- (void) updateActionAtIndex:(int) row
{
    const QModelIndex& idx = CallModel::instance().userActionModel()->index(row,0);
    UserActionModel::Action action = qvariant_cast<UserActionModel::Action>(idx.data(UserActionModel::Role::ACTION));
    NSButton* a = actionHash[(int) action];
    if (a) {
        [a setHidden:!(idx.flags() & Qt::ItemIsEnabled)];
        [a setState:(idx.data(Qt::CheckStateRole) == Qt::Checked) ? NSOnState : NSOffState];
    }
}

-(void) updateCall
{
    QModelIndex callIdx = CallModel::instance().selectionModel()->currentIndex();
    if (!callIdx.isValid()) {
        return;
    }
    [personLabel setStringValue:callIdx.data(Qt::DisplayRole).toString().toNSString()];
    [timeSpentLabel setStringValue:callIdx.data((int)Call::Role::Length).toString().toNSString()];

    auto contactmethod = qvariant_cast<Call*>(callIdx.data(static_cast<int>(Call::Role::Object)))->peerContactMethod();
    BOOL shouldShow = (!contactmethod->contact() || contactmethod->contact()->isPlaceHolder());
    [self.addContactButton setHidden:!shouldShow];

    Call::State state = callIdx.data((int)Call::Role::State).value<Call::State>();

    // Default values for this views
    [loadingIndicator setHidden:YES];
    [self.chatButton setHidden:YES];
    [videoView setShouldAcceptInteractions:NO];


    [stateLabel setStringValue:callIdx.data((int)Call::Role::HumanStateName).toString().toNSString()];
    switch (state) {
        case Call::State::DIALING:
            [loadingIndicator setHidden:NO];
            break;
        case Call::State::NEW:
            break;
        case Call::State::INITIALIZATION:
            [loadingIndicator setHidden:NO];
            break;
        case Call::State::CONNECTED:
            [loadingIndicator setHidden:NO];
            break;
        case Call::State::RINGING:
            break;
        case Call::State::CURRENT:
            [videoView setShouldAcceptInteractions:YES];
            [self.chatButton setHidden:NO];
            break;
        case Call::State::HOLD:
            break;
        case Call::State::BUSY:
            break;
        case Call::State::OVER:
        case Call::State::FAILURE:
            if(self.splitView.isInFullScreenMode)
                [self.splitView exitFullScreenModeWithOptions:nil];
            break;
    }

}

- (void)awakeFromNib
{
    NSLog(@"INIT CurrentCall VC");
    [self.view setWantsLayer:YES];
    [self.view setLayer:[CALayer layer]];

    [controlsPanel setWantsLayer:YES];
    [controlsPanel setLayer:[CALayer layer]];
    [controlsPanel.layer setZPosition:2.0];
    [controlsPanel.layer setBackgroundColor:[NSColor whiteColor].CGColor];

    actionHash[ (int)UserActionModel::Action::ACCEPT] = pickUpButton;
    actionHash[ (int)UserActionModel::Action::HOLD  ] = holdOnOffButton;
    actionHash[ (int)UserActionModel::Action::RECORD] = recordOnOffButton;
    actionHash[ (int)UserActionModel::Action::HANGUP] = hangUpButton;
    actionHash[ (int)UserActionModel::Action::MUTE_AUDIO] = muteAudioButton;
    actionHash[ (int)UserActionModel::Action::MUTE_VIDEO] = muteVideoButton;
    actionHash[ (int)UserActionModel::Action::SERVER_TRANSFER] = transferButton;

    videoLayer = [CALayer layer];
    [videoView setWantsLayer:YES];
    [videoView setLayer:videoLayer];
    [videoView.layer setBackgroundColor:[NSColor blackColor].CGColor];
    [videoView.layer setFrame:videoView.frame];
    [videoView.layer setContentsGravity:kCAGravityResizeAspect];

    previewLayer = [CALayer layer];
    [previewView setWantsLayer:YES];
    [previewView setLayer:previewLayer];
    [previewLayer setBackgroundColor:[NSColor blackColor].CGColor];
    [previewLayer setContentsGravity:kCAGravityResizeAspectFill];
    [previewLayer setFrame:previewView.frame];

    [controlsPanel setWantsLayer:YES];
    [controlsPanel setLayer:[CALayer layer]];
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
    QObject::connect(CallModel::instance().selectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {
                         if(!current.isValid()) {
                             [self animateOut];
                             return;
                         }

                         auto call = CallModel::instance().getCall(current);
                         if (call->state() == Call::State::HOLD) {
                             call << Call::Action::HOLD;
                         }

                         [self collapseRightView];
                         [self updateCall];
                         [self updateAllActions];
                         [self animateOut];
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
                         [self updateCall];
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
                                                                       renderFrameForView:previewView];
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
                                                            renderFrameForView:previewView];
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
                         [self renderer:renderer renderFrameForView:videoView];
                     });

    videoHolder.started = QObject::connect(renderer,
                     &Video::Renderer::started,
                     [=]() {
                         QObject::disconnect(videoHolder.frameUpdated);
                         videoHolder.frameUpdated = QObject::connect(renderer,
                                                                     &Video::Renderer::frameUpdated,
                                                                     [=]() {
                                                                         [self renderer:renderer renderFrameForView:videoView];
                                                                     });
                     });

    videoHolder.stopped = QObject::connect(renderer,
                     &Video::Renderer::stopped,
                     [=]() {
                         QObject::disconnect(videoHolder.frameUpdated);
                        [videoView.layer setContents:nil];
                     });
}

-(void) renderer: (Video::Renderer*)renderer renderFrameForView:(NSView*) view
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
    NSLog(@"animateIn");
    CGRect frame = CGRectOffset(self.view.superview.bounds, -self.view.superview.bounds.size.width, 0);
    [self.view setHidden:NO];

    [CATransaction begin];
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
    [animation setFromValue:[NSValue valueWithPoint:frame.origin]];
    [animation setToValue:[NSValue valueWithPoint:self.view.superview.bounds.origin]];
    [animation setDuration:0.2f];
    [animation setTimingFunction:[CAMediaTimingFunction functionWithControlPoints:.7 :0.9 :1 :1]];
    [CATransaction setCompletionBlock:^{

        // when call comes in we want to show the controls/header
        [self mouseIsMoving:YES];

        [self connectVideoSignals];
        /* check if text media is already present */
        if(!CallModel::instance().selectedCall())
            return;

        QObject::connect(CallModel::instance().selectedCall(),
                            &Call::changed,
                            [=]() {
                                [self updateCall];
                            });
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
    [videoView.layer setContents:nil];
    [previewView.layer setContents:nil];

    [self.transferPopoverVC performClose:self];
    [self.addToContactPopover performClose:self];

    [self.chatButton setState:NSOffState];
    [self collapseRightView];
}

-(void) animateOut
{
    NSLog(@"animateOut");
    if(self.view.frame.origin.x < 0) {
        NSLog(@"Already hidden");
        if (CallModel::instance().selectionModel()->currentIndex().isValid()) {
            [self animateIn];
        }
        return;
    }

    CGRect frame = CGRectOffset(self.view.frame, -self.view.frame.size.width, 0);
    [CATransaction begin];
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
    [animation setFromValue:[NSValue valueWithPoint:self.view.frame.origin]];
    [animation setToValue:[NSValue valueWithPoint:frame.origin]];
    [animation setDuration:0.2f];
    [animation setTimingFunction:[CAMediaTimingFunction functionWithControlPoints:.7 :0.9 :1 :1]];

    [CATransaction setCompletionBlock:^{
        [self.view setHidden:YES];
        // first make sure everything is disconnected
        [self cleanUp];
        if (CallModel::instance().selectionModel()->currentIndex().isValid()) {
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

-(IBAction)toggleChat:(id)sender;
{
    BOOL rightViewCollapsed = [[self splitView] isSubviewCollapsed:[[[self splitView] subviews] objectAtIndex: 1]];
    if (rightViewCollapsed) {
        [self uncollapseRightView];
        CallModel::instance().getCall(CallModel::instance().selectionModel()->currentIndex())->addOutgoingMedia<Media::Text>();
    } else {
        [self collapseRightView];
    }
    [chatButton setState:rightViewCollapsed];
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
    if (self.transferPopoverVC != nullptr) {
        [self.transferPopoverVC performClose:self];
        self.transferPopoverVC = NULL;
        [self.transferButton setState:NSOffState];
    } else {
        auto* transferVC = [[BrokerVC alloc] initWithMode:BrokerMode::TRANSFER];
        self.transferPopoverVC = [[NSPopover alloc] init];
        [self.transferPopoverVC setContentSize:transferVC.view.frame.size];
        [self.transferPopoverVC setContentViewController:transferVC];
        [self.transferPopoverVC setAnimates:YES];
        [self.transferPopoverVC setBehavior:NSPopoverBehaviorTransient];
        [self.transferPopoverVC setDelegate:self];
        [self.transferPopoverVC showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSMinYEdge];
        [videoView setCallDelegate:nil];
    }
}

#pragma mark - NSPopOverDelegate

- (void)popoverWillClose:(NSNotification *)notification
{
    if (self.transferPopoverVC != nullptr) {
        [self.transferPopoverVC performClose:self];
        self.transferPopoverVC = NULL;
    }

    if (self.addToContactPopover != nullptr) {
        [self.addToContactPopover performClose:self];
        self.addToContactPopover = NULL;
    }

    [self.addContactButton setState:NSOffState];
    [self.transferButton setState:NSOffState];
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
