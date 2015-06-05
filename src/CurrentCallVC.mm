/*
 *  Copyright (C) 2004-2015 Savoir-Faire Linux Inc.
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
 *
 *  Additional permission under GNU GPL version 3 section 7:
 *
 *  If you modify this program, or any covered work, by linking or
 *  combining it with the OpenSSL project's OpenSSL library (or a
 *  modified version of that library), containing parts covered by the
 *  terms of the OpenSSL or SSLeay licenses, Savoir-Faire Linux Inc.
 *  grants you additional permission to convey the resulting work.
 *  Corresponding Source for a non-source form of such a combination
 *  shall include the source code for the parts of OpenSSL used as well
 *  as that of the covered work.
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

#import "views/CallView.h"

/** FrameReceiver class - delegate for AVCaptureSession
 */
@interface RendererConnectionsHolder : NSObject

@property QMetaObject::Connection frameUpdated;
@property QMetaObject::Connection started;
@property QMetaObject::Connection stopped;

@end

@implementation RendererConnectionsHolder

@end

@interface CurrentCallVC ()

@property (unsafe_unretained) IBOutlet NSTextField *personLabel;
@property (unsafe_unretained) IBOutlet NSTextField *stateLabel;
@property (unsafe_unretained) IBOutlet NSButton *holdOnOffButton;
@property (unsafe_unretained) IBOutlet NSButton *hangUpButton;
@property (unsafe_unretained) IBOutlet NSButton *recordOnOffButton;
@property (unsafe_unretained) IBOutlet NSButton *pickUpButton;
@property (unsafe_unretained) IBOutlet NSTextField *timeSpentLabel;
@property (unsafe_unretained) IBOutlet NSView *controlsPanel;
@property (unsafe_unretained) IBOutlet NSSplitView *splitView;

@property QHash<int, NSButton*> actionHash;

// Video
@property (unsafe_unretained) IBOutlet CallView *videoView;
@property CALayer* videoLayer;
@property (unsafe_unretained) IBOutlet NSView *previewView;
@property CALayer* previewLayer;

@property RendererConnectionsHolder* previewHolder;
@property RendererConnectionsHolder* videoHolder;
@property QMetaObject::Connection videoStarted;

@end

@implementation CurrentCallVC
@synthesize personLabel;
@synthesize actionHash;
@synthesize stateLabel;
@synthesize holdOnOffButton;
@synthesize hangUpButton;
@synthesize recordOnOffButton;
@synthesize pickUpButton;
@synthesize timeSpentLabel;
@synthesize controlsPanel;
@synthesize videoView;
@synthesize videoLayer;
@synthesize previewLayer;
@synthesize previewView;
@synthesize splitView;

@synthesize previewHolder;
@synthesize videoHolder;

- (void) updateAllActions
{
    for(int i = 0 ; i <= CallModel::instance()->userActionModel()->rowCount() ; i++) {
        [self updateActionAtIndex:i];
    }
}

- (void) updateActionAtIndex:(int) row
{
    const QModelIndex& idx = CallModel::instance()->userActionModel()->index(row,0);
    UserActionModel::Action action = qvariant_cast<UserActionModel::Action>(idx.data(UserActionModel::Role::ACTION));
    NSButton* a = actionHash[(int) action];
    if (a != nil) {
        [a setEnabled:(idx.flags() & Qt::ItemIsEnabled)];
        [a setState:(idx.data(Qt::CheckStateRole) == Qt::Checked) ? NSOnState : NSOffState];

        if(action == UserActionModel::Action::HOLD) {
            [a setTitle:(a.state == NSOnState ? @"Hold off" : @"Hold")];
        }
        if(action == UserActionModel::Action::RECORD) {
            [a setTitle:(a.state == NSOnState ? @"Record off" : @"Record")];
        }
    }
}

-(void) updateCall
{
    QModelIndex callIdx = CallModel::instance()->selectionModel()->currentIndex();
    [personLabel setStringValue:CallModel::instance()->data(callIdx, Qt::DisplayRole).toString().toNSString()];
    [timeSpentLabel setStringValue:CallModel::instance()->data(callIdx, (int)Call::Role::Length).toString().toNSString()];

    Call::State state = CallModel::instance()->data(callIdx, (int)Call::Role::State).value<Call::State>();

    switch (state) {
        case Call::State::DIALING:
            [stateLabel setStringValue:@"Dialing"];
            break;
        case Call::State::NEW:
            [stateLabel setStringValue:@"New"];
            break;
        case Call::State::INITIALIZATION:
            [stateLabel setStringValue:@"Initializing"];
            [videoView setShouldAcceptInteractions:NO];
            break;
        case Call::State::RINGING:
            [stateLabel setStringValue:@"Ringing"];
            [videoView setShouldAcceptInteractions:NO];
            break;
        case Call::State::CURRENT:
            [stateLabel setStringValue:@"Current"];
            [videoView setShouldAcceptInteractions:YES];
            break;
        case Call::State::HOLD:
            [stateLabel setStringValue:@"On Hold"];
            [videoView setShouldAcceptInteractions:NO];
            break;
        case Call::State::BUSY:
            [stateLabel setStringValue:@"Busy"];
            [videoView setShouldAcceptInteractions:NO];
            break;
        case Call::State::OVER:
            [stateLabel setStringValue:@"Finished"];
            [videoView setShouldAcceptInteractions:NO];
            if(videoView.isInFullScreenMode)
                [videoView exitFullScreenModeWithOptions:nil];
            break;
        case Call::State::ABORTED:
            [stateLabel setStringValue:@"Aborted"];
            break;
        case Call::State::FAILURE:
            [stateLabel setStringValue:@"Failure"];
            [videoView setShouldAcceptInteractions:NO];
            break;
        case Call::State::INCOMING:
            [stateLabel setStringValue:@"Incoming"];
            break;
        default:
            [stateLabel setStringValue:@""];
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

    [self connect];
    [self collapseRightView];
}

- (void) connect
{
    QObject::connect(CallModel::instance()->selectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {
                         if(!current.isValid()) {
                             [self animateOut];
                             return;
                         }
                         [self updateCall];
                         [self updateAllActions];
                         [self animateOut];
                     });

    QObject::connect(CallModel::instance(),
                     &QAbstractItemModel::dataChanged,
                     [=](const QModelIndex &topLeft, const QModelIndex &bottomRight) {
                         [self updateCall];
                     });

    QObject::connect(CallModel::instance()->userActionModel(),
                     &QAbstractItemModel::dataChanged,
                     [=](const QModelIndex &topLeft, const QModelIndex &bottomRight) {
                         const int first(topLeft.row()),last(bottomRight.row());
                         for(int i = first; i <= last;i++) {
                             [self updateActionAtIndex:i];
                         }
                     });

    QObject::connect(CallModel::instance(),
                     &CallModel::callStateChanged,
                     [self](Call* c, Call::State state) {
                         [self updateCall];
    });
}

-(void) connectVideoSignals
{
    QModelIndex idx = CallModel::instance()->selectionModel()->currentIndex();
    Call* call = CallModel::instance()->getCall(idx);
    QObject::connect(call,
                     &Call::videoStarted,
                     [=](Video::Renderer* renderer) {
                         NSLog(@"Video started!");
                         QObject::disconnect(self.videoStarted);
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
    previewHolder.started = QObject::connect(Video::PreviewManager::instance(),
                     &Video::PreviewManager::previewStarted,
                     [=](Video::Renderer* renderer) {
                         QObject::disconnect(previewHolder.frameUpdated);
                         previewHolder.frameUpdated = QObject::connect(renderer,
                                                                       &Video::Renderer::frameUpdated,
                                                                       [=]() {
                                                                           [self renderer:Video::PreviewManager::instance()->previewRenderer()
                                                                       renderFrameForView:previewView];
                                                                       });
                     });

    previewHolder.stopped = QObject::connect(Video::PreviewManager::instance(),
                     &Video::PreviewManager::previewStopped,
                     [=](Video::Renderer* renderer) {
                         QObject::disconnect(previewHolder.frameUpdated);
                        [previewView.layer setContents:nil];
                     });

    previewHolder.frameUpdated = QObject::connect(Video::PreviewManager::instance()->previewRenderer(),
                                                 &Video::Renderer::frameUpdated,
                                                 [=]() {
                                                     [self renderer:Video::PreviewManager::instance()->previewRenderer()
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
    const QByteArray& data = renderer->currentFrame();
    QSize res = renderer->size();

    auto buf = reinterpret_cast<const unsigned char*>(data.data());

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef newContext = CGBitmapContextCreate((void *)buf,
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
        [self connectVideoSignals];
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
}

-(void) animateOut
{
    NSLog(@"animateOut");
    if(self.view.frame.origin.x < 0) {
        NSLog(@"Already hidden");
        if (CallModel::instance()->selectionModel()->currentIndex().isValid()) {
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
        if (CallModel::instance()->selectionModel()->currentIndex().isValid()) {
            [self animateIn];
        }
    }];
    [self.view.layer addAnimation:animation forKey:animation.keyPath];
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
    //NSRect overallFrame = [splitView frame]; //???
    [right setHidden:YES];
    //[left setFrameSize:NSMakeSize(leftFrame.size.width,leftFrame.size.height)];
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
}


#pragma mark - Button methods

- (IBAction)hangUp:(id)sender {
    CallModel::instance()->getCall(CallModel::instance()->selectionModel()->currentIndex()) << Call::Action::REFUSE;
}

- (IBAction)accept:(id)sender {
    CallModel::instance()->getCall(CallModel::instance()->selectionModel()->currentIndex()) << Call::Action::ACCEPT;
}

- (IBAction)toggleRecording:(id)sender {
    CallModel::instance()->getCall(CallModel::instance()->selectionModel()->currentIndex()) << Call::Action::RECORD_AUDIO;
}

- (IBAction)toggleHold:(id)sender {
    CallModel::instance()->getCall(CallModel::instance()->selectionModel()->currentIndex()) << Call::Action::HOLD;
}

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview;
{
    NSView* rightView = [[splitView subviews] objectAtIndex:1];
    NSLog(@"%@:%s returning %@",[self class], _cmd, ([subview isEqual:rightView])?@"YES":@"NO");
    return ([subview isEqual:rightView]);
}

-(IBAction)toggleRightView:(id)sender;
{
    BOOL rightViewCollapsed = [[self splitView] isSubviewCollapsed:[[[self splitView] subviews] objectAtIndex: 1]];
    NSLog(@"%@:%s toggleInspector isCollapsed: %@",[self class], _cmd, rightViewCollapsed?@"YES":@"NO");
    if (rightViewCollapsed) {
        [self uncollapseRightView];
    } else {
        [self collapseRightView];
    }
}

#pragma mark - NSSplitViewDelegate

/* Return YES if the subview should be collapsed because the user has double-clicked on an adjacent divider. If a split view has a delegate, and the delegate responds to this message, it will be sent once for the subview before a divider when the user double-clicks on that divider, and again for the subview after the divider, but only if the delegate returned YES when sent -splitView:canCollapseSubview: for the subview in question. When the delegate indicates that both subviews should be collapsed NSSplitView's behavior is undefined.
 */
- (BOOL)splitView:(NSSplitView *)splitView shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex;
{
    NSView* rightView = [[splitView subviews] objectAtIndex:1];
    NSLog(@"%@:%s returning %@",[self class], _cmd, ([subview isEqual:rightView])?@"YES":@"NO");
    return ([subview isEqual:rightView]);
}

//- (BOOL)splitView:(NSSplitView *)splitView shouldHideDividerAtIndex:(NSInteger)dividerIndex;
//{
//    NSLog(@"%@:%s returning NO",[self class], _cmd);
//    return YES;
//}

//- (BOOL)splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView *)view;
//{
//    NSLog(@"%@:%s returning NO",[self class], _cmd);
//    return NO;
//}
//

/* From the header doc
 * Delegates that respond to this message and return a number larger than the proposed minimum position effectively declare a minimum size for the subview above or to the left of the divider in question,
 the minimum size being the difference between the proposed and returned minimum positions. This minimum size is only effective for the divider-dragging operation during which the
 -splitView:constrainMinCoordinate:ofSubviewAt: message is sent. NSSplitView's behavior is undefined when a delegate responds to this message by returning a number smaller than the proposed minimum.

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex;
{
    NSLog(@"%@:%s proposedMinimum: %f",[self class], _cmd, proposedMinimumPosition);
    return proposedMinimumPosition + 200;
}
*/
/*  Delegates that respond to this message and return a number smaller than the proposed maximum position effectively declare a minimum size for the subview below or to the right of the divider in question,
 the minimum size being the difference between the proposed and returned maximum positions. This minimum size is only effective for the divider-dragging operation during which the
 -splitView:constrainMaxCoordinate:ofSubviewAt: message is sent. NSSplitView's behavior is undefined when a delegate responds to this message by returning a number larger than the proposed maximum.

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex;
{
    NSLog(@"%@:%s proposedMaximum: %f",[self class], _cmd, proposedMaximumPosition);
    return proposedMaximumPosition - 100;
}
*/
@end
