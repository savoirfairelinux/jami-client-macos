//
//  CurrentCallVC.m
//  Ring
//
//  Created by Alexandre Lision on 2015-03-02.
//
//

#define SEGMENT_HANGUP_TAG 0
#define SEGMENT_RECORD_TAG 1
#define SEGMENT_HOLD_TAG 2
#define SEGMENT_MUTE_TAG 3

#import "CurrentCallVC.h"

#import <QuartzCore/QuartzCore.h>

#include <call.h>
#include <callmodel.h>
#include <useractionmodel.h>
#include <qabstractitemmodel.h>

@interface CurrentCallVC ()

@property Call* privateCall;
@property (assign) IBOutlet NSTextField *personLabel;
@property (assign) IBOutlet NSTextField *stateLabel;
@property (assign) IBOutlet NSView *buttonPanel;
@property (assign) IBOutlet NSSegmentedControl *incallControls;

@property QHash<int, int> actionHash;

@end

@implementation CurrentCallVC
@synthesize privateCall;
@synthesize personLabel;
@synthesize actionHash;
@synthesize stateLabel;
@synthesize buttonPanel;
@synthesize incallControls;

- (void) setupCall:(Call*) call
{
    privateCall = call;

    for(int i = 0 ; i <= CallModel::instance()->userActionModel()->rowCount() ; i++) {
        [self updateControlStateForQIndex:CallModel::instance()->userActionModel()->index(i,0)];
    }

    [self updateState];
}

- (void) updateControlStateForQIndex:(QModelIndex) idx
{
    int action = (int)qvariant_cast<UserActionModel::Action>(idx.data(UserActionModel::Role::ACTION));
    if (actionHash.contains(action)) {
        [incallControls setEnabled:(idx.flags() & Qt::ItemIsEnabled)];

        if((idx.flags() & Qt::ItemIsUserCheckable))
            [incallControls setSelected:(idx.data(Qt::CheckStateRole) == Qt::Checked) forSegment:actionHash[action]];
        else {
            [incallControls setSelected:NO forSegment:actionHash[action]];
        }
    }
}

- (void) updateState
{
    switch (privateCall->lifeCycleState()) {
        case Call::LifeCycleState::INITIALIZATION:
            [stateLabel setStringValue:@"Initializing"];
            [incallControls setHidden:YES];
            [buttonPanel setHidden:NO];
            break;
        case Call::LifeCycleState::PROGRESS:
            [buttonPanel setHidden:YES];
            [incallControls setHidden:NO];
            [stateLabel setStringValue:@"Current"];
            break;
        case Call::LifeCycleState::FINISHED:
            [buttonPanel setHidden:YES];
            [incallControls setHidden:NO];
            [stateLabel setStringValue:@"Finished"];
            break;
        default:
            break;
    }
}

- (void)awakeFromNib
{
    NSLog(@"INIT CurrentCall VC");
    CALayer *viewLayer = [CALayer layer];
    privateCall = nil;
    [self.view setWantsLayer:YES]; // view's backing store is using a Core Animation Layer
    [self.view setLayer:viewLayer];
    self.view.layerContentsRedrawPolicy = NSViewLayerContentsRedrawDuringViewResize;
    self.view.layer.backgroundColor = [NSColor whiteColor].CGColor;

    [[incallControls cell] setTag:SEGMENT_HANGUP_TAG forSegment:0];
    [[incallControls cell] setTag:SEGMENT_RECORD_TAG forSegment:1];
    [[incallControls cell] setTag:SEGMENT_HOLD_TAG forSegment:2];
    [[incallControls cell] setTag:SEGMENT_MUTE_TAG forSegment:3];

    QObject::connect(CallModel::instance()->userActionModel(),
                     &QAbstractItemModel::dataChanged,
                     [=](const QModelIndex &topLeft, const QModelIndex &bottomRight) {
                         NSLog(@"data changed");
                         const int first(topLeft.row()),last(bottomRight.row());
                         for(int i = first; i <= last;i++) {
                             [self updateControlStateForQIndex:CallModel::instance()->userActionModel()->index(i,0)];
                         }
                     });


    CallModel* callModel_ = CallModel::instance();
    QObject::connect(callModel_, &CallModel::callStateChanged, [self](Call* c, Call::State state) {
        NSLog(@"callStateChanged");
        if(c == privateCall)
            [self updateState];
    });

    actionHash[ (int)UserActionModel::Action::HANGUP        ] = SEGMENT_HANGUP_TAG;
    actionHash[ (int)UserActionModel::Action::RECORD        ] = SEGMENT_RECORD_TAG;
    actionHash[ (int)UserActionModel::Action::HOLD          ] = SEGMENT_HOLD_TAG;
    int segmentIdx = actionHash[(int)UserActionModel::Action::HANGUP];

    //actionHash[ (int)UserActionModel::Action::MUTE          ] = SEGMENT_MUTE_TAG;
    //actionHash[ (int)UserActionModel::Action::MUTE_AUDIO      ] = action_mute_capture;
    //actionHash[ (int)UserActionModel::Action::SERVER_TRANSFER ] = action_transfer;

}

- (void) initFrame
{
    privateCall = nil;
    [self.view setFrame:self.view.superview.bounds];
    CGRect frame = CGRectOffset(self.view.frame, -self.view.frame.size.width, 0);
    [self.view setFrame:frame];
    self.view.layer.position = self.view.frame.origin;
    [self dumpFrame:self.view.frame WithName:@"START"];
    NSLog(@"layer position : %f %f", self.view.layer.position.x, self.view.layer.position.y);
}

- (void) displayCall:(Call*) call
{
    if(call == nil) {
        [NSError errorWithDomain:@"Call to display is nil" code:0 userInfo:nil];
        return;
    }

    if(call == privateCall)
        return;

    [self setupCall:call];

    if(privateCall != nil) {
        privateCall = call;
        [self animateOut];
    } else if(call != nil) {
        privateCall = call;
        [self animateIn];
    }
}

- (void) hideWithAnimation:(BOOL) shouldAnimate
{
    if(shouldAnimate) {
        privateCall = nil;
        [self animateOut];
    }
}

# pragma private IN/OUT animations

-(void) animateIn
{
    NSLog(@"animateIn");
    [CATransaction begin];
    self.view.layer.position = self.view.frame.origin;

    [self dumpFrame:self.view.frame WithName:@"START"];
    NSLog(@"layer position : %f %f", self.view.layer.position.x, self.view.layer.position.y);
    [self dumpFrame:self.view.superview.frame WithName:@"END"];

    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
    animation.fromValue = [NSValue valueWithPoint:self.view.frame.origin];
    animation.toValue = [NSValue valueWithPoint:self.view.superview.frame.origin];
    animation.duration = 0.2f;
    [animation setTimingFunction:[CAMediaTimingFunction functionWithControlPoints:.7 :0.9 :1 :1]];
    [CATransaction setCompletionBlock:^{
        NSLog(@"COMPLETION IN");
        [self.view setFrame:self.view.superview.frame];
        self.view.layer.position = self.view.frame.origin;
        //[self dumpFrame:self.view.frame WithName:@"SELF.VIEW.FRAME"];
        //[self dumpFrame:self.view.layer.frame WithName:@"LAYER.FRAME"];
        //NSLog(@"layer position : %f %f", self.view.layer.position.x, self.view.layer.position.y);
    }];
    [self.view.layer addAnimation:animation forKey:animation.keyPath];

    [CATransaction commit];

    QByteArray test;
}

-(void) animateOut
{
    NSLog(@"animateOut");
    CGRect frame = CGRectOffset(self.view.superview.frame, -self.view.frame.size.width, 0);

    [self dumpFrame:self.view.frame WithName:@"START"];
    [self dumpFrame:frame WithName:@"END"];

    [CATransaction begin];
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
    [animation setFromValue:[NSValue valueWithPoint:self.view.frame.origin]];
    [animation setToValue:[NSValue valueWithPoint:frame.origin]];
    [animation setDuration:0.2f];
    [animation setTimingFunction:[CAMediaTimingFunction functionWithControlPoints:.7 :0.9 :1 :1]];

    [CATransaction setCompletionBlock:^{
        NSLog(@"COMPLETION OUT");
        [self.view setFrame:frame];
        self.view.layer.position = self.view.frame.origin;
        if(privateCall != nil) {
            [self animateIn];
        }
    }];
    [self.view.layer addAnimation:animation forKey:animation.keyPath];
    [CATransaction commit];
}

-(void) dumpFrame:(CGRect) frame WithName:(NSString*) name
{
    NSLog(@"frame %@ : %f %f %f %f",name ,frame.origin.x, frame.origin.y, frame.size.width, frame.size.height);
}

- (IBAction)inCallsButtonClicked:(id)sender {
    int clickedSegment = [sender selectedSegment];
    int clickedSegmentTag = [[sender cell] tagForSegment:clickedSegment];
    NSLog(@"clickedSegmentTag %d", clickedSegmentTag);
    switch (clickedSegmentTag) {
        case SEGMENT_HANGUP_TAG:
            privateCall << Call::Action::REFUSE;
            break;
        case SEGMENT_RECORD_TAG:
            privateCall << Call::Action::RECORD;
            break;
        case SEGMENT_HOLD_TAG:
            privateCall << Call::Action::HOLD;
            break;
        case SEGMENT_MUTE_TAG:
            break;
        default:
            break;
    }

}

#pragma button methods
- (IBAction)hangUp:(id)sender {
    privateCall << Call::Action::REFUSE;
}

- (IBAction)accept:(id)sender {
    privateCall << Call::Action::ACCEPT;
}

@end
