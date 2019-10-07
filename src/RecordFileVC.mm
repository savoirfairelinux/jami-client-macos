/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
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

#import "RecordFileVC.h"
#import "views/CallMTKView.h"
#import "AppDelegate.h"
#import "VideoCommon.h"
#import "views/HoverButton.h"

//lrc
#import <video/renderer.h>
#import <api/avmodel.h>

#import "views/NSColor+RingTheme.h"

//Qt
#import <QUrl>
#import "string"

#import <AVFoundation/AVFoundation.h>

@interface RecordFileVC ()
@property (unsafe_unretained) IBOutlet CallMTKView* previewView;
@property (unsafe_unretained) IBOutlet NSTextField* timeLabel;
@property (unsafe_unretained) IBOutlet NSTextField* infoLabel;
@property (unsafe_unretained) IBOutlet HoverButton* recordOnOffButton;
@property (unsafe_unretained) IBOutlet NSButton *cancelButton;
@property (unsafe_unretained) IBOutlet NSButton *sendButton;
@property (unsafe_unretained) IBOutlet HoverButton *fileImage;
@property (assign) IBOutlet NSLayoutConstraint* timeRightConstraint;
@property (assign) IBOutlet NSLayoutConstraint* timeTopConstraint;
@property (assign) IBOutlet NSLayoutConstraint* timeCenterX;
@property (assign) IBOutlet NSLayoutConstraint* timeCenterY;

@end

@implementation RecordFileVC

QMetaObject::Connection frameUpdated1;
QMetaObject::Connection previewStarted1;
QMetaObject::Connection previewStopped1;
CVPixelBufferPoolRef pixelBufferPool1;
CVPixelBufferRef pixelBuffer1;
BOOL recording;
NSString *fileName;
NSTimer* durationTimer;
int timePassing = 0;
bool isAudio = NO;

@synthesize avModel, previewView, timeLabel, recordOnOffButton, sendButton, fileImage, infoLabel, timeRightConstraint,timeTopConstraint, timeCenterX, timeCenterY;

-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil avModel:(lrc::api::AVModel*) avModel
{
    if (self =  [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.avModel = avModel;
    }
    return self;
}

- (void)loadView {
    [super loadView];
    [[self view] setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    [self.previewView setupView];
}

- (void) connectPreviewSignals {
    QObject::disconnect(previewStarted1);
    [previewView fillWithBlack];
    previewStarted1 =
    QObject::connect(avModel,
                     &lrc::api::AVModel::rendererStarted,
                     [=](const std::string& id) {
                         if (id != lrc::api::video::PREVIEW_RENDERER_ID) {
                             return;
                         }
                         self.previewView.stopRendering = false;
                         QObject::disconnect(frameUpdated1);
                         QObject::disconnect(previewStarted1);
                         QObject::disconnect(previewStopped1);
                         frameUpdated1 =
                         QObject::connect(avModel,
                                          &lrc::api::AVModel::frameUpdated,
                                          [=](const std::string& id) {
                                              if (id != lrc::api::video::PREVIEW_RENDERER_ID) {
                                                  return;
                                              }
                                              auto renderer = &avModel->getRenderer(id);
                                              if(!renderer->isRendering()) {
                                                  return;
                                              }
                                              [self renderer:renderer
                                          renderFrameForView: self.previewView];
                                          });
                         previewStopped1 = QObject::connect(avModel,
                                                           &lrc::api::AVModel::rendererStopped,
                                                           [=](const std::string& id) {
                                                               if (id != lrc::api::video
                                                                   ::PREVIEW_RENDERER_ID) {
                                                                   return;
                                                               }
                                                               self.previewView.stopRendering = true;
                                                               QObject::disconnect(previewStopped1);
                                                               QObject::disconnect(frameUpdated1);
                                                           });
                     });
}

#pragma mark - dispaly

-(void) renderer: (const lrc::api::video::Renderer*)renderer renderFrameForView:(CallMTKView*) view
{
    @autoreleasepool {
        auto frameSize = [VideoCommon fillPixelBuffr:&pixelBuffer1 fromRenderer:renderer bufferPool:&pixelBufferPool1];
        CVPixelBufferRef buffer  = pixelBuffer1;
        [view renderWithPixelBuffer: buffer
                               size: frameSize
                           rotation: 0
                          fillFrame: false];
    }
}

- (IBAction)cancell:(NSButton *)sender {
    avModel->stopPreview();
    [self clean];
    self.delegate.closeRecordingView;
}

- (IBAction)sendMessage:(NSButton *)sender {
    NSArray* pathURL = [fileName componentsSeparatedByString: @"/"];
    if([pathURL count] < 1) {
        return;
    }
    NSString* name = [pathURL objectAtIndex: [pathURL count] - 1];
    [self.delegate sendFile:name withFilePath:fileName];
    self.delegate.closeRecordingView;
    [self clean];
}

- (IBAction)record:(NSButton *)sender {
    if (recording) {
        avModel->stopLocalRecorder([fileName UTF8String]);
        recording = false;
        [recordOnOffButton stopBlinkAnimation];
        [durationTimer invalidate];
        durationTimer = nil;
        std::string uri = [[@"file:///" stringByAppendingString: fileName] UTF8String];
        avModel->setInputFile(uri);
        [sendButton setHidden:NO];
        [fileImage setHidden:NO];
        timeCenterX.constant = 15;
    } else {
        
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 101400
        if (@available(macOS 10.14, *)) {
            AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
            if(authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    infoLabel.stringValue = @"audio permission not granted";
                });
                return;
            }
            
            if(authStatus == AVAuthorizationStatusNotDetermined)
            {
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                    if(!granted){
                        dispatch_async(dispatch_get_main_queue(), ^{
                            infoLabel.stringValue = @"audio permission not granted";
                        });
                        return;
                    }
                    [self startRecord];
                    
                }];
                return;
            }
            if (!isAudio) {
                AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
                if(authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        infoLabel.stringValue = @"video permission not granted";
                    });
                    return;
                }
                
                if(authStatus == AVAuthorizationStatusNotDetermined)
                {
                    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                        if(!granted){
                            dispatch_async(dispatch_get_main_queue(), ^{
                                infoLabel.stringValue = @"audio permission not granted";
                            });
                            return;
                        }
                        [self startRecord];
                    }];
                    return;
                }
            }
        }
#endif
        [self startRecord];
    }
}

-(void) startRecord {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self clean];
        [infoLabel setHidden:YES];
        [recordOnOffButton startBlinkAnimationfrom:[NSColor buttonBlinkColorColor]
                                                to:[NSColor whiteColor]
                                       scaleFactor: 1
                                          duration: 1.5];
        if (!isAudio) {
            avModel->startPreview();
        }
        timeCenterX.constant = 0;
        std::string file_name = avModel->startLocalRecorder(isAudio);
        if (file_name.empty()) {
            return;
        }
        fileName = @(file_name.c_str());
        recording = true;
        if (durationTimer == nil)
            durationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                             target:self
                                                           selector:@selector(updateDurationLabel)
                                                           userInfo:nil
                                                            repeats:YES];
    });
}

-(void) updateDurationLabel
{
    timePassing++;
    [timeLabel setStringValue: [self timeFormatted: timePassing]];
}
- (NSString *)timeFormatted:(int)totalSeconds
{
    int seconds = totalSeconds % 60;
    int minutes = (totalSeconds / 60) % 60;
    return [NSString stringWithFormat:@"%02d:%02d",minutes, seconds];
}

-(void) stopRecordingView {
    [self clean];
    avModel->stopLocalRecorder("");
    avModel->stopPreview();
}

-(void) prepareRecordingView:(BOOL)audioOnly {
    [self clean];
    [infoLabel setHidden:NO];
    isAudio = audioOnly;
    NSColor *color = isAudio ? [NSColor labelColor] : [NSColor whiteColor];
    recordOnOffButton.moiuseOutsideImageColor = color;
    fileImage.buttonDisableColor = color;
    fileImage.imageColor = color;
    timeLabel.textColor = color;
    infoLabel.textColor = color;
    NSString *title = @"Send";
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    [style setAlignment:NSCenterTextAlignment];
    NSDictionary *attrsDictionary = [NSDictionary dictionaryWithObjectsAndKeys:color, NSForegroundColorAttributeName, style, NSParagraphStyleAttributeName, nil];
    NSAttributedString *attrString = [[NSAttributedString alloc]initWithString:title attributes:attrsDictionary];
    [sendButton setAttributedTitle:attrString];
    [previewView setHidden:isAudio];
    auto frame = self.view.frame;
    if (isAudio) {
        self.view.frame = CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, 170);
        timeRightConstraint.priority = 200;
        timeTopConstraint.priority = 200;
        timeCenterX.priority = 900;
        timeCenterY.priority = 900;
        timeCenterX.constant = 0;
        return;
    }
    timeRightConstraint.priority = 900;
    timeTopConstraint.priority = 900;
    timeCenterX.priority = 200;
    timeCenterY.priority = 200;
    self.view.frame = CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, 270);
    previewView.frame = self.view.bounds;
    [previewView fillWithBlack];
    AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
    if (![appDelegate getActiveCalls].size()) {
        self.previewView.stopRendering = false;
        [self connectPreviewSignals];
        avModel->stopPreview();
        avModel->startPreview();
    }
}

-(void) clean {
    fileName = @"";
    [sendButton setHidden:YES];
    timePassing = 0;
    [timeLabel setStringValue: @""];
    [fileImage setHidden:YES];
}

@end
