/*
 *  Copyright (C) 2018-2019 by Savoir-faire Linux Inc.
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
NSMutableDictionary *filesToSend;
std::string conversationUid;
lrc::api::ConversationModel* conversationModel;

- (void)loadView {
    [super loadView];
    [personPhoto setWantsLayer:YES];
    personPhoto.layer.masksToBounds =true;
    personPhoto.layer.cornerRadius = personPhoto.frame.size.width * 0.5;
    filesToSend = [[NSMutableDictionary alloc] init];
}

-(void) setAVModel: (lrc::api::AVModel*) avmodel {
    avModel = avmodel;
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
        [self clearData];
        avModel->startPreview();
        std::string file_name = avModel->startLocalRecorder(NO);
        if (file_name.empty()) {
            return;
        }
        filesToSend[@(conversationUid.c_str())] = @(file_name.c_str());
        isRecording = true;
        recordButton.image = [NSImage imageNamed:@"ic_stoprecord.png"];
        [timerBox setHidden:NO];
        if (refreshDurationTimer == nil)
            refreshDurationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                                    target:self
                                                                  selector:@selector(updateDurationLabel)
                                                                  userInfo:nil
                                                                   repeats:YES];
    } else {
        avModel->stopLocalRecorder([filesToSend[@(conversationUid.c_str())] UTF8String]);
        avModel->stopPreview();
        isRecording = false;
        recordButton.image = [NSImage imageNamed:@"ic_action_audio.png"];
        [refreshDurationTimer invalidate];
        refreshDurationTimer = nil;
        [timerBox setHidden:YES];
        [sendBox setHidden: NO];
        [sendFilename setStringValue:[self timeFormatted: recordingTime]];
    }
}

- (IBAction)sendMessage:(NSButton *)sender {
    NSArray* pathURL = [filesToSend[@(conversationUid.c_str())] componentsSeparatedByString: @"/"];
    if([pathURL count] < 1) {
        return;
    }
    NSString* name = [pathURL objectAtIndex: [pathURL count] - 1];
    conversationModel->sendFile(conversationUid, [filesToSend[@(conversationUid.c_str())] UTF8String], [name UTF8String]);
    [filesToSend removeObjectForKey: @(conversationUid.c_str())];
    [self exit];
}

- (void) exit {
    [self clearData];
    [self hide];
    [self.delegate messageCompleted];
}

- (void)clearData {
    recordButton.image = [NSImage imageNamed:@"ic_action_audio.png"];
    recordingTime = 0;
    [timerLabel setStringValue: [self timeFormatted: recordingTime]];
    isRecording = false;
    [timerBox setHidden:YES];
    [sendBox setHidden: YES];
    [refreshDurationTimer invalidate];
    refreshDurationTimer = nil;
    [sendFilename setStringValue:@""];
    [filesToSend removeObjectForKey: @(conversationUid.c_str())];
}

- (void)viewWillHide {
    recordButton.image = [NSImage imageNamed:@"ic_action_audio.png"];
    if(filesToSend[@(conversationUid.c_str())]) {
        [sendFilename setStringValue:[self timeFormatted: recordingTime]];
        [sendBox setHidden: NO];
    } else {
        [sendFilename setStringValue:@""];
        [sendBox setHidden: YES];
    }
    recordingTime = 0;
    [timerLabel setStringValue: [self timeFormatted: recordingTime]];
    isRecording = false;
    [timerBox setHidden:YES];
    [refreshDurationTimer invalidate];
    refreshDurationTimer = nil;
}

-(void) hide {
    if(self.view.frame.origin.x < 0) {
        return;
    }
    [self viewWillHide];
    [self.view setHidden:YES];
}

-(void) show {
    if(self.view.frame.origin.x < 0) {
        return;
    }
    [self.view setHidden:NO];
}

-(void)setConversationUID:(std::string) convUid conversationModel:(lrc::api::ConversationModel*) convModel {
    conversationUid = convUid;
    conversationModel = convModel;
    [self updateView];
}

-(void) updateView {
    auto it = getConversationFromUid(conversationUid, *conversationModel);
    if (it != conversationModel->allFilteredConversations().end()) {
        auto& imgManip = reinterpret_cast<Interfaces::ImageManipulationDelegate&>(GlobalInstances::pixmapManipulator());
        QVariant photo = imgManip.conversationPhoto(*it, conversationModel->owner, QSize(120, 120), NO);
        [personPhoto setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(photo))];
        NSString *name = bestNameForConversation(*it, *conversationModel);
        [infoLabel setStringValue:name];
    }
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
