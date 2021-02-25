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

#import <Cocoa/Cocoa.h>
#import "GradientView.h"
#import "IconButton.h"
#import "CustomBackgroundView.h"

NS_ASSUME_NONNULL_BEGIN

@protocol ConferenceLayoutDelegate
-(void)hangUpParticipant:(NSString*)uri;
-(void)minimizeParticipant;
-(void)maximizeParticipant:(NSString*)uri active:(BOOL)isActive;
-(void)muteParticipantAudio:(NSString*)uri state:(BOOL)state;
-(void)setModerator:(NSString*)uri state:(BOOL)state;
-(int)getCurrentLayout;
-(BOOL)isMasterCall;
-(BOOL)isCallModerator;
-(BOOL)isParticipantHost:(NSString*)uri;
@end

struct ConferenceParticipant {
    CGFloat hight;
    CGFloat width;
    CGFloat x;
    CGFloat y;
    NSString* uri;
    NSString* bestName;
    bool active;
    bool isLocal;
    bool isModerator;
    bool audioLocalMuted;
    bool audioModeratorMuted;
    bool videoMuted;
};

@interface ConferenceOverlayView: NSView {
@private
    NSTrackingArea *trackingArea;
}
@property ConferenceParticipant participant;
@property NSSize framesize;
@property (nonatomic, weak) NSLayoutConstraint* widthConstraint;
@property (nonatomic, weak) NSLayoutConstraint* heightConstraint;
@property (nonatomic, weak) NSLayoutConstraint* centerXConstraint;
@property (nonatomic, weak) NSLayoutConstraint* centerYConstraint;
@property NSView* backgroundView;
@property NSView* increasedBackgroundView;
@property NSStackView* states;
@property NSStackView* buttonsContainer;
@property NSStackView* infoContainer;
@property NSTextField* usernameLabel;
@property (retain, nonatomic) id <ConferenceLayoutDelegate> delegate;
@property (nonatomic, weak) NSTimer* timeoutTimer;
@property BOOL mouseInside;

//actions
@property IconButton* maximize;
@property IconButton* minimize;
@property IconButton* hangup;
@property IconButton* setModerator;
@property IconButton* muteAudio;

//state
@property CustomBackgroundView* moderatorState;
@property CustomBackgroundView* audioState;
@property CustomBackgroundView* hostState;


- (void)configureView;
- (void)updateViewWithParticipant:(ConferenceParticipant) participant;
- (void)sizeChanged;

@end

NS_ASSUME_NONNULL_END
