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
#import "AppDelegate.h"
#import "VideoCommon.h"
#import "views/HoverButton.h"
#import "views/NSColor+RingTheme.h"
#import "views/RenderingView.h"
#import "NSString+Extensions.h"

//lrc
#import <video/renderer.h>
#import <api/avmodel.h>

#import <AVFoundation/AVFoundation.h>

@interface RecordFileVC ()
@property (unsafe_unretained) IBOutlet RenderingView* previewView;

@property (unsafe_unretained) IBOutlet NSTextField* timeLabel;
@property (unsafe_unretained) IBOutlet NSTextField* infoLabel;

@property (unsafe_unretained) IBOutlet HoverButton* recordOnOffButton;
@property (unsafe_unretained) IBOutlet NSButton *sendButton;
@property (unsafe_unretained) IBOutlet HoverButton *fileImage;

@property (assign) IBOutlet NSLayoutConstraint* timeRightConstraint;
@property (assign) IBOutlet NSLayoutConstraint* timeTopConstraint;
@property (assign) IBOutlet NSLayoutConstraint* timeCenterX;
@property (assign) IBOutlet NSLayoutConstraint* timeCenterY;

@property RendererConnectionsHolder* renderConnections;

@end

@implementation RecordFileVC

CVPixelBufferPoolRef pool;
CVPixelBufferRef pixBuf;
BOOL recording;
NSString *fileName;
NSTimer* durationTimer;
int timePassing = 0;
bool isAudio = NO;

@synthesize avModel, renderConnections,
previewView, timeLabel, recordOnOffButton, sendButton, fileImage, infoLabel, timeRightConstraint,timeTopConstraint, timeCenterX, timeCenterY;

-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil avModel:(lrc::api::AVModel*) avModel
{
    if (self =  [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.avModel = avModel;
        renderConnections = [[RendererConnectionsHolder alloc] init];
    }
    return self;
}

- (void)loadView {
    [super loadView];
    [[self view] setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    [self.previewView setupView];
    AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
    if ([appDelegate getActiveCalls].size()) {
        [self setErrorState];
        return;
    }
    [self setInitialState];
}

- (void) connectPreviewSignals {
    [previewView fillWithBlack];
    QObject::disconnect(renderConnections.frameUpdated);
    renderConnections.frameUpdated =
    QObject::connect(avModel,
                     &lrc::api::AVModel::frameUpdated,
                     [=](const QString& id) {
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
}

#pragma mark - dispaly

-(void) renderer: (const lrc::api::video::Renderer*)renderer renderFrameForView:(RenderingView*) view
{
    @autoreleasepool {
        const CGSize frameSize = [VideoCommon fillPixelBuffr:&pixBuf
                                        fromRenderer:renderer
                                          bufferPool:&pool];
        if(frameSize.width == 0 || frameSize.height == 0) {
            return;
        }
        CVPixelBufferRef buffer  = pixBuf;
        [view renderWithPixelBuffer: buffer
                               size: frameSize
                           rotation: 0
                          fillFrame: true];
    }
}

#pragma mark - actions

- (IBAction)cancell:(NSButton *)sender {
    [self disconnectVideo];
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
}

- (IBAction)togleRecord:(NSButton *)sender {
    if (recording) {
        [self stopRecord];
        return;
    }

    NSString *info = NSLocalizedString(@"Press to start recording", @"Recording view explanation label");
    infoLabel.stringValue = info;

#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 101400
    if (@available(macOS 10.14, *)) {
        NSString *noVideoPermission = NSLocalizedString(@"Video permission not granted", @"Error video permission");
        NSString *noAudioPermission = NSLocalizedString(@"Audio permission not granted", @"Error audio permission");

        AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
        if(authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                infoLabel.stringValue = noAudioPermission;
            });
            return;
        }

        if(authStatus == AVAuthorizationStatusNotDetermined)
        {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
                if(!granted){
                    dispatch_async(dispatch_get_main_queue(), ^{
                        infoLabel.stringValue = noAudioPermission;
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
                    infoLabel.stringValue = noVideoPermission;
                });
                return;
            }

            if(authStatus == AVAuthorizationStatusNotDetermined)
            {
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                    if(!granted){
                        dispatch_async(dispatch_get_main_queue(), ^{
                            infoLabel.stringValue = noVideoPermission;
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

-(void) stopRecord {
    avModel->stopLocalRecorder(QString::fromNSString(fileName));
    recording = false;
    [durationTimer invalidate];
    durationTimer = nil;
    [self setRecordedState];
}

-(void) startRecord {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!isAudio) {
            avModel->startPreview();
        }
        [self setRecordingState];
        QString file_name = avModel->startLocalRecorder(isAudio);
        if (file_name.isEmpty()) {
            return;
        }
        fileName = file_name.toNSString();
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
    [timeLabel setStringValue: [NSString formattedStringTimeFromSeconds: timePassing]];
}

-(void) stopRecordingView {
    [self disconnectVideo];
    recording = false;
    [durationTimer invalidate];
    durationTimer = nil;
    [recordOnOffButton stopBlinkAnimation];
}

-(void) disconnectVideo {
    AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
    if (![appDelegate getActiveCalls].size()) {
        avModel->stopPreview();
        QObject::disconnect(renderConnections.frameUpdated);
        avModel->stopLocalRecorder(QString::fromNSString(fileName));
    }
}

-(void) prepareRecordingView:(BOOL)audioOnly {
    AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
    if ([appDelegate getActiveCalls].size()) {
        [self setErrorState];
        return;
    }
    isAudio = audioOnly;
    [self setInitialState];
    if (isAudio) {
        return;
    }
    [previewView fillWithBlack];

    self.previewView.videoRunning = true;
    [self connectPreviewSignals];
    avModel->stopPreview();
    avModel->startPreview();
}

-(void) setInitialState {
    [recordOnOffButton setHidden:NO];
    [infoLabel setHidden:NO];
    [sendButton setHidden:YES];
    [sendButton setHidden:YES];
    [fileImage setHidden:YES];
    [timeLabel setStringValue: @""];

    fileName = @"";
    timePassing = 0;

    NSColor *color = isAudio ? [NSColor labelColor] : [NSColor whiteColor];
    recordOnOffButton.moiuseOutsideImageColor = color;
    recordOnOffButton.imageColor = color;
    fileImage.buttonDisableColor = color;
    fileImage.imageColor = color;
    timeLabel.textColor = color;
    infoLabel.textColor = color;
    NSString *title = NSLocalizedString(@"Send", @"Send button title");
    NSString *info = NSLocalizedString(@"Press to start recording", @"Recording view explanation label");
    infoLabel.stringValue = info;
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    [style setAlignment:NSCenterTextAlignment];
    NSDictionary *attrsDictionary = [NSDictionary dictionaryWithObjectsAndKeys:color, NSForegroundColorAttributeName, style, NSParagraphStyleAttributeName, nil];
    NSAttributedString *attrString = [[NSAttributedString alloc]initWithString:title attributes:attrsDictionary];
    [sendButton setAttributedTitle:attrString];

    [previewView setHidden:isAudio];
    auto frame = self.view.frame;
    if (isAudio) {
        [self.view setFrameSize: CGSizeMake(370, 160)];
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
    [self.view setFrameSize: CGSizeMake(480, 270)];
    previewView.frame = self.view.bounds;
}

-(void) setRecordingState {
    fileName = @"";
    timePassing = 0;
    [recordOnOffButton setHidden:NO];
    [sendButton setHidden:YES];
    [fileImage setHidden:YES];
    [infoLabel setHidden:YES];
    [timeLabel setStringValue: @""];
    NSString *info = NSLocalizedString(@"Press to start recording", @"Recording view explanation label");
    infoLabel.stringValue = info;
    [recordOnOffButton startBlinkAnimationfrom:[NSColor buttonBlinkColorColor]
                                            to:[NSColor whiteColor]
                                   scaleFactor: 1
                                      duration: 1.5];
    timeCenterX.constant = 0;
}

-(void) setRecordedState {
    [recordOnOffButton stopBlinkAnimation];
    [recordOnOffButton setHidden:NO];
    [sendButton setHidden:NO];
    [fileImage setHidden:NO];
    timeCenterX.constant = 15;
    [infoLabel setHidden:YES];
}

//when open during call
-(void) setErrorState {
    NSString *info = NSLocalizedString(@"Could not record message during call", @"Recording view explanation label");
    infoLabel.stringValue = info;
    [infoLabel setHidden:NO];
    [recordOnOffButton setHidden:YES];
    infoLabel.textColor = [NSColor textColor];
    [previewView setHidden:YES];
    [sendButton setHidden:YES];
    [fileImage setHidden:YES];
    [timeLabel setStringValue: @""];
    [self.view setFrameSize: CGSizeMake(370, 160)];
}

@end
