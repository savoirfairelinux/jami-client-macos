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

#include <call.h>
#include <callmodel.h>
#include <useractionmodel.h>
#import <qabstractitemmodel.h>

@interface CurrentCallVC ()

@property Call* privateCall;
@property (assign) IBOutlet NSTextField *personLabel;
@property (assign) IBOutlet NSView *buttonsPanel;
@property (assign) IBOutlet NSTextField *stateLabel;
@property (assign) IBOutlet NSButton *holdOnOffButton;
@property (assign) IBOutlet NSButton *hangUpButton;
@property (assign) IBOutlet NSButton *recordOnOffButton;
@property (assign) IBOutlet NSButton *pickUpButton;

@property QHash<int, NSButton*> actionHash;

@end

@implementation CurrentCallVC
@synthesize privateCall;
@synthesize personLabel;
@synthesize buttonsPanel;
@synthesize actionHash;
@synthesize stateLabel;
@synthesize holdOnOffButton;
@synthesize hangUpButton;
@synthesize recordOnOffButton;
@synthesize pickUpButton;



- (void) setupCall:(Call*) call
{
    privateCall = call;

    //DO UI POSITIONING HERE

    [self updateState];
}

- (void) updateState
{
    NSLog(@"updateState, %d items ", CallModel::instance()->userActionModel()->rowCount());
    for(int i = 0 ; i <= CallModel::instance()->userActionModel()->rowCount() ; i++) {
        const QModelIndex& idx = CallModel::instance()->userActionModel()->index(i,0);
        NSLog(@"updateState for item %d", (int)qvariant_cast<UserActionModel::Action>(idx.data(UserActionModel::Role::ACTION)));
        NSButton* a = actionHash[(int)qvariant_cast<UserActionModel::Action>(idx.data(UserActionModel::Role::ACTION))];
        if (a != nil) {
            NSLog(@"updateState");
            [a setTitle:idx.data(Qt::DisplayRole).toString().toNSString()];
            [a setEnabled:(idx.flags() & Qt::ItemIsEnabled)];
            [a setState:(idx.data(Qt::CheckStateRole) == Qt::Checked) ? NSOnState : NSOffState];
        }
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
    self.view.layer.backgroundColor = [NSColor darkGrayColor].CGColor;

    QObject::connect(CallModel::instance()->userActionModel(),
                     &QAbstractItemModel::dataChanged,
                     [=](const QModelIndex &topLeft, const QModelIndex &bottomRight) {
                         NSLog(@"data changed");
                         const int first(topLeft.row()),last(bottomRight.row());
                         for(int i = first; i <= last;i++) {
                             const QModelIndex& idx = CallModel::instance()->userActionModel()->index(i,0);
                             NSButton* a = actionHash[(int)qvariant_cast<UserActionModel::Action>(idx.data(UserActionModel::Role::ACTION))];
                             if (a) {
                                 [a setTitle:idx.data(Qt::DisplayRole).toString().toNSString()];
                                 [a setEnabled:(idx.flags() & Qt::ItemIsEnabled)];
                                 [a setState:(idx.data(Qt::CheckStateRole) == Qt::Checked) ? NSOnState : NSOffState];
                             }
                         }
                     });


    NSLog(@"Adding for item %d", (int)UserActionModel::Action::ACCEPT);
    actionHash[ (int)UserActionModel::Action::ACCEPT          ] = pickUpButton;
    actionHash[ (int)UserActionModel::Action::HOLD            ] = holdOnOffButton;
    actionHash[ (int)UserActionModel::Action::RECORD          ] = recordOnOffButton;
    actionHash[ (int)UserActionModel::Action::HANGUP          ] = hangUpButton;
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
        [self dumpFrame:self.view.frame WithName:@"SELF.VIEW.FRAME"];
        [self dumpFrame:self.view.layer.frame WithName:@"LAYER.FRAME"];
        NSLog(@"layer position : %f %f", self.view.layer.position.x, self.view.layer.position.y);
    }];
    [self.view.layer addAnimation:animation forKey:animation.keyPath];

    [CATransaction commit];
}

-(void) animateOut
{
    NSLog(@"animateOut");
    CGRect frame = CGRectOffset(self.view.frame, -self.view.frame.size.width, 0);

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


#pragma button methods
- (IBAction)hangUp:(id)sender {
    privateCall << Call::Action::REFUSE;
}

- (IBAction)accept:(id)sender {
    privateCall << Call::Action::ACCEPT;
}

- (IBAction)toggleRecording:(id)sender {
    privateCall << Call::Action::RECORD;
}

- (IBAction)toggleHold:(id)sender {
    privateCall << Call::Action::HOLD;
}

@end
