/*
 *  Copyright (C) 2018 Savoir-faire Linux Inc.
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

#import "LeaveMessageVC.h"
#import "views/NSColor+RingTheme.h"
#import "utils.h"

//lrc
#import <api/avmodel.h>
#import <api/conversationmodel.h>

#import <QuartzCore/QuartzCore.h>
#import "delegates/ImageManipulationDelegate.h"

//Qt
#import <QtMacExtras/qmacfunctions.h>
#import <QPixmap>
#import <globalinstances.h>

@interface LeaveMessageVC () {
    __unsafe_unretained IBOutlet NSImageView* personPhoto;
    __unsafe_unretained IBOutlet NSTextField* infoLabel;
    __unsafe_unretained IBOutlet NSBox* timerBox;
    __unsafe_unretained IBOutlet NSTextField* timerLabel;
    __unsafe_unretained IBOutlet NSBox* sendBox;
    __unsafe_unretained IBOutlet NSTextField* sendFilename;
    __unsafe_unretained IBOutlet NSButton* recordButton;
}

@end

@implementation LeaveMessageVC

bool isRecording = false;
int recordingTime = 0;
NSTimer* refreshDurationTimer;
lrc::api::AVModel* avModel;
std::string fileName;
std::string conversationUid;
lrc::api::ConversationModel* conversationModel;

- (void)loadView {
    [super loadView];
    [self.view setWantsLayer:YES];
    [self.view setLayer:[CALayer layer]];
    [self.view.layer setBackgroundColor:[NSColor ringGreyHighlight ].CGColor];
}

-(void) initFrame {
    [self.view setFrame:self.view.superview.bounds];
    [self.view setHidden:YES];
    self.view.layer.position = self.view.frame.origin;
}

- (IBAction)cancel:(id)sender {
    [self exit];
}

- (IBAction)recordMessage:(NSButton *)sender {
    if (!isRecording) {
        [self clearSetUp];
        std::string file_name = avModel->startLocalRecorder(true);
        if (file_name.empty()) {
            return;
        }
        fileName = file_name;
        isRecording = true;
        [timerBox setHidden:NO];
        if (refreshDurationTimer == nil)
            refreshDurationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                                    target:self
                                                                  selector:@selector(updateDurationLabel)
                                                                  userInfo:nil
                                                                   repeats:YES];
    } else {
        avModel->stopLocalRecorder(fileName);
        isRecording = false;
        recordButton.image = [NSImage imageNamed:@"ic_action_holdoff.png"];
        [refreshDurationTimer invalidate];
        refreshDurationTimer = nil;
        [timerBox setHidden:YES];
        [sendBox setHidden: NO];
        [sendFilename setStringValue:[self timeFormatted: recordingTime]];
    }
}

- (IBAction)sendMessage:(NSButton *)sender {
    NSArray* pathURL = [@(fileName.c_str()) componentsSeparatedByString: @"/"];
    if([pathURL count] < 1) {
        return;
    }
    NSString* name = [pathURL objectAtIndex: [pathURL count] - 1];
    conversationModel->sendFile(conversationUid, fileName, [name UTF8String]);
    [self exit];
}

- (void)exit {
    [self clearSetUp];
    [self hide];
}

- (void)clearSetUp {
    recordButton.image = [NSImage imageNamed:@"ic_action_holdoff.png"];
    recordingTime = 0;
    [sendFilename setStringValue:[self timeFormatted: recordingTime]];
    [timerLabel setStringValue: [self timeFormatted: recordingTime]];
    isRecording = false;
    [timerBox setHidden:YES];
    [sendBox setHidden: YES];
    [refreshDurationTimer invalidate];
    refreshDurationTimer = nil;
    [sendFilename setStringValue:@""];
}

-(void) hide {
    if(self.view.frame.origin.x < 0) {
        return;
    }
    [self.view setHidden:YES];
}

-(void) show {
    if(self.view.frame.origin.x < 0) {
        return;
    }
    [self.view setHidden:NO];
}

-(void)setConversationUID:(std::string) convUid conversationModel:(lrc::api::ConversationModel*) convModel andAVModel: (lrc::api::AVModel*) avmodel {
    conversationUid = convUid;
    conversationModel = convModel;
    avModel = avmodel;
    [self initView];
}

-(void)initView {
    auto it = getConversationFromUid(conversationUid, *conversationModel);
    if (it != conversationModel->allFilteredConversations().end()) {
        auto& imgManip = reinterpret_cast<Interfaces::ImageManipulationDelegate&>(GlobalInstances::pixmapManipulator());
        QVariant photo = imgManip.conversationPhoto(*it, conversationModel->owner);
        [personPhoto setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(photo))];
        NSString *name = bestNameForConversation(*it, *conversationModel);
        name = [[@"Unable to reach " stringByAppendingString:name] stringByAppendingString:@". Would you like to record and send audio message?"];
        [infoLabel setStringValue:name];
    }
    [timerBox setHidden: YES];
    [sendBox setHidden: YES];
    [self show];
}

-(void) updateDurationLabel
{
    recordingTime++;
    [timerLabel setStringValue: [self timeFormatted: recordingTime]];
}

- (NSString *)timeFormatted:(int)totalSeconds
{
    int seconds = totalSeconds % 60;
    int minutes = (totalSeconds / 60) % 60;
    return [NSString stringWithFormat:@"%02d:%02d",minutes, seconds];
}

@end
