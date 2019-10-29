/*
 *  Copyright (C) 2015-2016 Savoir-faire Linux Inc.
 *  Author: Alexandre Lision <alexandre.lision@savoirfairelinux.com>
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
#import "VideoPrefsVC.h"
#import "views/CallMTKView.h"
#import "AppDelegate.h"
#import "VideoCommon.h"

#import <QuartzCore/QuartzCore.h>

#import <video/renderer.h>
#import <api/avmodel.h>

//Qt
#import <QSize>

extern "C" {
#import "libavutil/frame.h"
}

@interface VideoPrefsVC ()

@property  IBOutlet CallMTKView* previewView;
@property (assign) IBOutlet NSPopUpButton* videoDevicesList;
@property (assign) IBOutlet NSPopUpButton* sizesList;
@property (assign) IBOutlet NSPopUpButton* ratesList;
@property (assign) IBOutlet NSButton *enableHardwareAccelerationButton;

@property BOOL shouldHandlePreview;

@end

@implementation VideoPrefsVC
@synthesize previewView;
@synthesize videoDevicesList;
@synthesize sizesList;
@synthesize ratesList;
@synthesize avModel;

QMetaObject::Connection frameUpdated;
QMetaObject::Connection previewStarted;
QMetaObject::Connection previewStopped;
QMetaObject::Connection deviceEvent;
CVPixelBufferPoolRef pixelBufferPool;
CVPixelBufferRef pixelBuffer;
std::string currentVideoDevice;

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
    [self addDevices];
    [self.enableHardwareAccelerationButton setState: self.avModel->getDecodingAccelerated()];
    [self.previewView setupView];
}

- (void)viewWillDisappear {
    [super viewWillDisappear];
    QObject::disconnect(frameUpdated);
    QObject::disconnect(previewStopped);
    QObject::disconnect(previewStarted);
    QObject::disconnect(deviceEvent);
    AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
    if (![appDelegate getActiveCalls].size()) {
        self.previewView.stopRendering = true;
        avModel->stopPreview();
        [previewView fillWithBlack];
    }
}

- (void)viewWillAppear {
    [super viewWillAppear];
    [self startPreview];
}

#pragma mark - actions

- (IBAction)chooseDevice:(id)sender {
    int index = [sender indexOfSelectedItem];
    auto devices = avModel->getDevices();
    auto newDevice = devices.at(index);
    auto deviceString = @(newDevice.c_str());
    avModel->setDefaultDevice(newDevice);
    [self devicesChanged];
    [self startPreview];
}

- (IBAction)chooseSize:(id)sender {
    int index = [sender indexOfSelectedItem];
    auto resolution = [[sizesList itemTitleAtIndex:index] UTF8String];
    auto device = avModel->getDefaultDevice();
    try {
        auto currentSettings = avModel->getDeviceSettings(device);
        currentSettings.size = resolution;
        avModel->setDeviceSettings(currentSettings);
        [ratesList removeAllItems];
        currentSettings = avModel->getDeviceSettings(device);
        auto currentChannel = currentSettings.channel;
        currentChannel = currentChannel.empty() ? "default" : currentChannel;
        auto deviceCapabilities = avModel->getDeviceCapabilities(device);
        auto channelCaps = deviceCapabilities.at(currentChannel);
        for (auto [resolution, frameRateList] : channelCaps) {
            for (auto rate : frameRateList) {
                [ratesList addItemWithTitle: [NSString stringWithFormat:@"%f", rate]];
            }
        }
        [self connectPreviewSignals];
        [sizesList selectItemWithTitle: @(currentSettings.size.c_str())];
        [ratesList selectItemWithTitle:[NSString stringWithFormat:@"%f", currentSettings.rate]];
    } catch (...) {}
}

- (IBAction)chooseRate:(id)sender {
    int index = [sender indexOfSelectedItem];
    auto rate = [[ratesList itemTitleAtIndex:index] floatValue];
    auto device = avModel->getDefaultDevice();
    try {
        auto settings = avModel->getDeviceSettings(device);
        settings.rate = rate;
        [self connectPreviewSignals];
        avModel->setDeviceSettings(settings);
    } catch (...) {}
}

- (IBAction)toggleHardwareAcceleration:(NSButton *)sender {
    bool enabled = [sender state]==NSOnState;
    self.avModel->setDecodingAccelerated(enabled);
}

#pragma mark - signals

- (void) connectPreviewSignals {
    QObject::disconnect(previewStarted);
    [previewView fillWithBlack];
    previewStarted =
    QObject::connect(avModel,
                     &lrc::api::AVModel::rendererStarted,
                     [=](const std::string& id) {
                         if (id != lrc::api::video::PREVIEW_RENDERER_ID) {
                             return;
                         }
                        self.previewView.stopRendering = false;
                        QObject::disconnect(frameUpdated);
                        QObject::disconnect(previewStarted);
                        QObject::disconnect(previewStopped);
                        frameUpdated =
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
                         previewStopped = QObject::connect(avModel,
                                                           &lrc::api::AVModel::rendererStopped,
                                                           [=](const std::string& id) {
                                                               if (id != lrc::api::video
                                                                   ::PREVIEW_RENDERER_ID) {
                                                                   return;
                                                               }
                                                               self.previewView.stopRendering = true;
                                                               QObject::disconnect(previewStopped);
                                                               QObject::disconnect(frameUpdated);
                         });
    });
}

-(void)connectdDeviceEvent {
    QObject::disconnect(deviceEvent);
    deviceEvent = QObject::connect(avModel,
                                   &lrc::api::AVModel::deviceEvent,
                                   [=]() {
                                       auto defaultDevice = avModel->getDefaultDevice();
                                       bool updatePreview = avModel->getRenderer(lrc::api ::video::PREVIEW_RENDERER_ID).isRendering() && (defaultDevice != currentVideoDevice);
                                       if (updatePreview) {
                                           [previewView fillWithBlack];
                                           self.previewView.stopRendering = true;
                                           [self startPreview];
                                       }
                                       [self addDevices];
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
    [VideoCommon fillPixelBuffr:&pixelBuffer fromFrame:frame bufferPool:&pixelBufferPool];
    CVPixelBufferRef buffer  = pixelBuffer;
    return buffer;
}

-(void)addDevices {
    [videoDevicesList removeAllItems];
    auto devices = avModel->getDevices();
    auto defaultDevice = avModel->getDefaultDevice();
    if (devices.size() <= 0) {
        return;
    }
    for (auto device : devices) {
        try {
            auto settings = avModel->getDeviceSettings(device);
            [videoDevicesList addItemWithTitle: @(settings.name.c_str())];
        } catch (...) {}
    }
    currentVideoDevice = defaultDevice;
    try {
        auto settings = avModel->getDeviceSettings(defaultDevice);
        [videoDevicesList selectItemWithTitle: @(settings.name.c_str())];
    } catch (...) {}
    [self devicesChanged];
}

-(void)startPreview {
    [self connectdDeviceEvent];
    [previewView fillWithBlack];
    AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
    if (![appDelegate getActiveCalls].size()) {
        self.previewView.stopRendering = false;
        [self connectPreviewSignals];
        avModel->stopPreview();
        avModel->startPreview();
   }
}

-(void) devicesChanged {
    [sizesList removeAllItems];
    [ratesList removeAllItems];
    auto device = avModel->getDefaultDevice();
    auto deviceCapabilities = avModel->getDeviceCapabilities(device);
    if (deviceCapabilities.size() <= 0) {
        return;
    }
    try {
        auto currentSettings = avModel->getDeviceSettings(device);
        auto currentChannel = currentSettings.channel;
        currentChannel = currentChannel.empty() ? "default" : currentChannel;
        auto channelCaps = deviceCapabilities.at(currentChannel);
        for (auto [resolution, frameRateList] : channelCaps) {
            [sizesList  addItemWithTitle: @(resolution.c_str())];
            for (auto rate : frameRateList) {
                [ratesList addItemWithTitle: [NSString stringWithFormat:@"%f", rate]];
            }
        }
        [sizesList selectItemWithTitle: @(currentSettings.size.c_str())];
        [ratesList selectItemWithTitle:[NSString stringWithFormat:@"%f", currentSettings.rate]];
    } catch (...) {}
}

@end
