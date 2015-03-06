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
@property CALayer *videoLayer;
@property CGImageRef newImage;

@property QHash<int, int> actionHash;

@end

@implementation CurrentCallVC
@synthesize privateCall;
@synthesize personLabel;
@synthesize actionHash;
@synthesize stateLabel;
@synthesize buttonPanel;
@synthesize incallControls;
@synthesize videoLayer;
@synthesize newImage;

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

-(void) setupUI
{
    [[incallControls cell] setTag:SEGMENT_HANGUP_TAG forSegment:0];
    [[incallControls cell] setTag:SEGMENT_RECORD_TAG forSegment:1];
    [[incallControls cell] setTag:SEGMENT_HOLD_TAG forSegment:2];
    [[incallControls cell] setTag:SEGMENT_MUTE_TAG forSegment:3];

    actionHash[ (int)UserActionModel::Action::HANGUP        ] = SEGMENT_HANGUP_TAG;
    actionHash[ (int)UserActionModel::Action::RECORD        ] = SEGMENT_RECORD_TAG;
    actionHash[ (int)UserActionModel::Action::HOLD          ] = SEGMENT_HOLD_TAG;
    //actionHash[ (int)UserActionModel::Action::MUTE          ] = SEGMENT_MUTE_TAG;
    //actionHash[ (int)UserActionModel::Action::MUTE_AUDIO      ] = action_mute_capture;
    //actionHash[ (int)UserActionModel::Action::SERVER_TRANSFER ] = action_transfer;

}

-(void) connect
{
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
}

- (void)awakeFromNib
{
    NSLog(@"INIT CurrentCall VC");
    privateCall = nil;
    [self.view setWantsLayer:YES]; // view's backing store is using a Core Animation Layer
    [self.view setLayer:[CALayer layer]];
    self.view.layerContentsRedrawPolicy = NSViewLayerContentsRedrawDuringViewResize;
    //self.view.layer.backgroundColor = [NSColor whiteColor].CGColor;
    //self.view.layer.zPosition = 3.0;

    // NOW THE VIDEO VIEW
    //videoLayer = [CALayer layer];
    //videoLayer.backgroundColor = [NSColor blackColor].CGColor;
    //videoLayer.zPosition = 5.0;
    //[self.view.layer addSublayer:videoLayer];

    [self setupUI];
    [self connect];

}

- (void) initFrame
{
    privateCall = nil;
    CGRect frame = CGRectOffset(self.view.superview.bounds, -self.view.superview.bounds.size.width, 0);
    [self.view setFrame:frame];
    self.view.layer.position = self.view.frame.origin;

    [self dumpFrame:self.view.frame WithName:@"START"];
    NSLog(@"layer position : %f %f", self.view.layer.position.x, self.view.layer.position.y);

    //[videoLayer setFrame:self.view.frame];
    //videoLayer.bounds = CGRectMake(0, 0, self.view.frame.size.height, self.view.frame.size.width);
    //[videoLayer setContentsRect:videoLayer.bounds];
    //videoLayer.affineTransform = CGAffineTransformMakeRotation(M_PI/2);

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
