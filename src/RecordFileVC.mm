//
//  RecordFileVC.m
//  Jami
//
//  Created by kate on 2019-09-27.
//

#import "RecordFileVC.h"
#import "views/CallMTKView.h"
#import "AppDelegate.h"
#import "VideoCommon.h"
#import "views/IconButton.h"

//lrc
#import <video/renderer.h>
#import <api/avmodel.h>

//Qt
#import <QSize>

extern "C" {
#import "libavutil/frame.h"
}

@interface RecordFileVC ()
@property  IBOutlet CallMTKView* previewView;
@property (unsafe_unretained) IBOutlet IconButton* recordOnOffButton;


@end

@implementation RecordFileVC

QMetaObject::Connection frameUpdated1;
QMetaObject::Connection previewStarted1;
QMetaObject::Connection previewStopped1;
CVPixelBufferPoolRef pixelBufferPool1;
CVPixelBufferRef pixelBuffer1;
BOOL isRecording;

@synthesize avModel, previewView;

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
    [self.previewView setupView];
}

-(void)startPreview {
    [previewView fillWithBlack];
    AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
    if (![appDelegate getActiveCalls].size()) {
        self.previewView.stopRendering = false;
        [self connectPreviewSignals];
        avModel->stopPreview();
        avModel->startPreview();
    }
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
        auto framePtr = renderer->currentAVFrame();
        auto frame = framePtr.get();
        if(!frame || !frame->width || !frame->height) {
            return;
        }
        auto rendSize = renderer->size();
        auto frameSize = CGSizeMake(frame->width, frame->height);
        auto rotation = 0;
        if (frame->data[3] != NULL && (CVPixelBufferRef)frame->data[3]) {
            [view renderWithPixelBuffer:(CVPixelBufferRef)frame->data[3]
                                   size: frameSize
                               rotation: rotation
                              fillFrame: false];
            return;
        }
        else if (CVPixelBufferRef pixBuffer = [self getBufferForPreviewFromFrame:frame]) {
            [view renderWithPixelBuffer: pixBuffer
                                   size: frameSize
                               rotation: rotation
                              fillFrame: false];
        }
    }
}


-(CVPixelBufferRef) getBufferForPreviewFromFrame:(const AVFrame*)frame {
    [VideoCommon fillPixelBuffr:&pixelBuffer1 fromFrame:frame bufferPool:&pixelBufferPool1];
    CVPixelBufferRef buffer  = pixelBuffer1;
    return buffer;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self startPreview];
    // Do view setup here.
}

- (IBAction)cancell:(NSButton *)sender {
    avModel->stopPreview();
    self.delegate.closeRecordingView;
   // [self.parentViewController dismissController:self];
    //[self.parentViewController.parentViewController dismissController:self.parentViewController];
}

-(void) stopMedia {
    avModel->stopPreview();
}

//- (IBAction)sendMessage:(NSButton *)sender {
//    NSArray* pathURL = [filesToSend[@(conversationUid.c_str())] componentsSeparatedByString: @"/"];
//    if([pathURL count] < 1) {
//        return;
//    }
//    NSString* name = [pathURL objectAtIndex: [pathURL count] - 1];
//    conversationModel->sendFile(conversationUid, [filesToSend[@(conversationUid.c_str())] UTF8String], [name UTF8String]);
//    [filesToSend removeObjectForKey: @(conversationUid.c_str())];
//    [self exit];
//}

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


@end
