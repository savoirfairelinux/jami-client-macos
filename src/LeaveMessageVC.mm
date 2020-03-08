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
#import "NSString+Extensions.h"

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
    __unsafe_unretained IBOutlet NSButton* sendButton;
    __unsafe_unretained IBOutlet NSButton* recordButton;
    __unsafe_unretained IBOutlet NSButton* exitButton;
}

@end

@implementation LeaveMessageVC

bool isRecording = false;
int recordingTime = 0;
NSTimer* refreshDurationTimer;
lrc::api::AVModel* avModel;
NSMutableDictionary *filesToSend;
QString conversationUid;
lrc::api::ConversationModel* conversationModel;

- (void)loadView {
    [super loadView];
    [personPhoto setWantsLayer:YES];
    personPhoto.layer.masksToBounds =true;
    personPhoto.layer.cornerRadius = personPhoto.frame.size.width * 0.5;
    filesToSend = [[NSMutableDictionary alloc] init];
    [self setButtonShadow:sendButton];
    [self setButtonShadow:exitButton];
    [self setButtonShadow:recordButton];
}

-(void) setButtonShadow:(NSButton*) button {
    button.wantsLayer = YES;
    button.layer.masksToBounds = NO;
    button.shadow = [[NSShadow alloc] init];
    button.layer.shadowOpacity = 0.8;
    button.layer.shadowColor = [[NSColor grayColor] CGColor];
    button.layer.shadowOffset = NSMakeSize(-0.5, 1);
    button.layer.shadowRadius = 1;
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
        QString file_name = avModel->startLocalRecorder(true);
        if (file_name.isEmpty()) {
            return;
        }
        filesToSend[conversationUid.toNSString()] = file_name.toNSString();
        isRecording = true;
        recordButton.image = [NSImage imageNamed:@"ic_stoprecord.png"];
        recordButton.title = NSLocalizedString(@"Stop recording", @"Record message title");
        [timerBox setHidden:NO];
        if (refreshDurationTimer == nil)
            refreshDurationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                                    target:self
                                                                  selector:@selector(updateDurationLabel)
                                                                  userInfo:nil
                                                                   repeats:YES];
    } else {
        avModel->stopLocalRecorder(QString::fromNSString(filesToSend[conversationUid.toNSString()]));
        isRecording = false;
        recordButton.image = [NSImage imageNamed:@"ic_action_audio.png"];
        recordButton.title = NSLocalizedString(@"Record a message", @"Record message title");
        [refreshDurationTimer invalidate];
        refreshDurationTimer = nil;
        [timerBox setHidden:YES];
        [sendButton setHidden: NO];
    }
}

- (IBAction)sendMessage:(NSButton *)sender {
    NSArray* pathURL = [filesToSend[conversationUid.toNSString()] componentsSeparatedByString: @"/"];
    if([pathURL count] < 1) {
        return;
    }
    NSString* name = [pathURL objectAtIndex: [pathURL count] - 1];
    conversationModel->sendFile(conversationUid, QString::fromNSString(filesToSend[conversationUid.toNSString()]), QString::fromNSString(name));
    [filesToSend removeObjectForKey: conversationUid.toNSString()];
    [self exit];
}

- (void) exit {
    [self clearData];
    [self hide];
    [self.delegate messageCompleted];
}

- (void)clearData {
    recordButton.image = [NSImage imageNamed:@"ic_action_audio.png"];
    recordButton.title = NSLocalizedString(@"Record a message", @"Record message title");
    recordingTime = 0;
    [timerLabel setStringValue: [NSString formattedStringTimeFromSeconds: recordingTime]];
    isRecording = false;
    [timerBox setHidden:YES];
    [sendButton setHidden: YES];
    [refreshDurationTimer invalidate];
    refreshDurationTimer = nil;
    [filesToSend removeObjectForKey: conversationUid.toNSString()];
}

- (void)viewWillHide {
    recordButton.image = [NSImage imageNamed:@"ic_action_audio.png"];
    recordButton.title = NSLocalizedString(@"Record a message", @"Record message title");
    if(filesToSend[conversationUid.toNSString()]) {
        [sendButton setHidden: NO];
    } else {
        [sendButton setHidden: YES];
    }
    recordingTime = 0;
    [timerLabel setStringValue: [NSString formattedStringTimeFromSeconds: recordingTime]];
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

-(void)setConversationUID:(const QString&) convUid conversationModel:(lrc::api::ConversationModel*) convModel {
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

        NSFont *fontName = [NSFont systemFontOfSize: 20.0 weight: NSFontWeightSemibold];
        NSFont *otherFont = [NSFont systemFontOfSize: 20.0 weight: NSFontWeightThin];
        NSColor *color = [NSColor textColor];
        NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [style setLineBreakMode:NSLineBreakByWordWrapping];
        [style setAlignment:NSCenterTextAlignment];
        NSDictionary *nameAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
                                   fontName, NSFontAttributeName,
                                   style, NSParagraphStyleAttributeName,
                                   color, NSForegroundColorAttributeName,
                                   nil];
        NSDictionary *otherAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
                                    otherFont, NSFontAttributeName,
                                    style, NSParagraphStyleAttributeName,
                                    color, NSForegroundColorAttributeName,
                                    nil];
        NSAttributedString* attributedName = [[NSAttributedString alloc] initWithString:name attributes:nameAttrs];
        NSString *str = [NSString stringWithFormat: @"%@%@\n%@",
                          @" ",
                          NSLocalizedString(@"appears to be busy.", @"Peer busy message"),
                          NSLocalizedString(@"Would you like to leave a message?", @"Peer busy message")];
        NSAttributedString* attributedOther= [[NSAttributedString alloc] initWithString: str attributes: otherAttrs];
        NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
        [result appendAttributedString:attributedName];
        [result appendAttributedString:attributedOther];
        NSRange range = NSMakeRange(0, [result length]);
        [result addAttribute:NSParagraphStyleAttributeName value:style range: range];
        [infoLabel setAttributedStringValue: result];
    }
    [self show];
}

-(void) updateDurationLabel
{
    recordingTime++;
    [timerLabel setStringValue: [NSString formattedStringTimeFromSeconds: recordingTime]];
}

@end
