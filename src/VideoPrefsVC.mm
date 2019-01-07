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

#import <QuartzCore/QuartzCore.h>

#import <video/previewmanager.h>
#import <video/renderer.h>
#import <video/devicemodel.h>
#import "video/channel.h"
#import "video/resolution.h"
#import "video/rate.h"
#import <api/avmodel.h>

@interface VideoPrefsVC ()

@property (assign) IBOutlet NSView* previewView;
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
Video::DeviceModel *deviceModel;

-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil avModel:(lrc::api::AVModel*) avModel
{
    if (self =  [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.avModel = avModel;
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    deviceModel = &Video::DeviceModel::instance();
    auto device = deviceModel->activeDevice();
    [videoDevicesList removeAllItems];
    if (deviceModel->devices().size() > 0) {
        for (auto device : deviceModel->devices()) {
            [videoDevicesList addItemWithTitle: device->name().toNSString()];
        }
    }
    [videoDevicesList selectItemWithTitle: device->name().toNSString()];
    [self updateWhenDeviceChanged];
    QObject::connect(self.avModel,
                     &lrc::api::AVModel::deviceEvent,
                     [=]() {
                         [videoDevicesList removeAllItems];
                         if (deviceModel->devices().size() > 0) {
                             for (auto device : deviceModel->devices()) {
                                 [videoDevicesList addItemWithTitle: device->name().toNSString()];
                             }
                         }
                         [videoDevicesList selectItemWithTitle: device->name().toNSString()];
                         [self updateWhenDeviceChanged];
                     });
    
    [previewView setWantsLayer:YES];
    [previewView setLayer:[CALayer layer]];
    [previewView.layer setBackgroundColor:[NSColor blackColor].CGColor];
    [previewView.layer setContentsGravity:kCAGravityResizeAspect];
    [previewView.layer setFrame:previewView.frame];
    [previewView.layer setBounds:previewView.frame];
    
    [self.enableHardwareAccelerationButton setState: self.avModel->getDecodingAccelerated()];
}

-(void) updateWhenDeviceChanged {
    auto device = deviceModel->activeDevice();
    [sizesList removeAllItems];
    [ratesList removeAllItems];
    if (device->channelList().size() > 0) {
        for (auto resolution : device->channelList()[0]->validResolutions()) {
            [sizesList  addItemWithTitle: resolution->name().toNSString()];
        }
    }
    auto activeResolution = device->channelList()[0]->activeResolution();
    [sizesList selectItemWithTitle: activeResolution->name().toNSString()];
    
    if(activeResolution->validRates().size() > 0) {
        for (auto rate : activeResolution->validRates()) {
            [ratesList addItemWithTitle: rate->name().toNSString()];
        }
    }
    [ratesList selectItemWithTitle:activeResolution->activeRate()->name().toNSString()];
}

- (IBAction)chooseDevice:(id)sender {
    int index = [sender indexOfSelectedItem];
    deviceModel->setActive(index);
    [self updateWhenDeviceChanged];
}

- (IBAction)chooseSize:(id)sender {
    int index = [sender indexOfSelectedItem];
    auto device = Video::DeviceModel::instance().activeDevice();
    device->channelList()[0]->setActiveResolution(index);
    auto activeResolution = device->channelList()[0]->activeResolution();
    if(activeResolution->validRates().size() > 0) {
        for (auto rate : activeResolution->validRates()) {
            [ratesList addItemWithTitle: rate->name().toNSString()];
        }
    }
    [ratesList selectItemWithTitle:activeResolution->activeRate()->name().toNSString()];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        deviceModel->setActive([videoDevicesList indexOfSelectedItem]);
    });
}

- (IBAction)chooseRate:(id)sender {
    int index = [sender indexOfSelectedItem];
    Video::DeviceModel::instance().activeDevice()->channelList()[0]->activeResolution()->setActiveRate(index);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        deviceModel->setActive([videoDevicesList indexOfSelectedItem]);
    });
}

- (IBAction)toggleHardwareAcceleration:(NSButton *)sender {
    bool enabled = [sender state]==NSOnState;
    self.avModel->setDecodingAccelerated(enabled);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        deviceModel->setActive([videoDevicesList indexOfSelectedItem]);
    });
}

- (void) connectPreviewSignals
{
    QObject::disconnect(frameUpdated);
    QObject::disconnect(previewStopped);
    QObject::disconnect(previewStarted);
    
    previewStarted = QObject::connect(&Video::PreviewManager::instance(),
                                      &Video::PreviewManager::previewStarted,
                                      [=](Video::Renderer* renderer) {
                                          NSLog(@"Preview started");
                                          QObject::disconnect(frameUpdated);
                                          frameUpdated = QObject::connect(renderer,
                                                                          &Video::Renderer::frameUpdated,
                                                                          [=]() {
                                                                              [self renderer:Video::PreviewManager::instance().previewRenderer() renderFrameForView:previewView];
                                                                          });
                                      });
    
    previewStopped = QObject::connect(&Video::PreviewManager::instance(),
                                      &Video::PreviewManager::previewStopped,
                                      [=](Video::Renderer* renderer) {
                                          NSLog(@"Preview stopped");
                                          QObject::disconnect(frameUpdated);
                                          [previewView.layer setContents:nil];
                                      });
    
    frameUpdated = QObject::connect(Video::PreviewManager::instance().previewRenderer(),
                                    &Video::Renderer::frameUpdated,
                                    [=]() {
                                        [self renderer:Video::PreviewManager::instance().previewRenderer()
                                    renderFrameForView:previewView];
                                    });
}

-(void) renderer: (Video::Renderer*)renderer renderFrameForView:(NSView*) view
{
    QSize res = renderer->size();
    
    auto frame_ptr = renderer->currentFrame();
    auto frame_data = frame_ptr.ptr;
    if (!frame_data)
        return;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef newContext = CGBitmapContextCreate(frame_data,
                                                    res.width(),
                                                    res.height(),
                                                    8,
                                                    4*res.width(),
                                                    colorSpace,
                                                    kCGImageAlphaPremultipliedLast);
    
    
    CGImageRef newImage = CGBitmapContextCreateImage(newContext);
    
    /*We release some components*/
    CGContextRelease(newContext);
    CGColorSpaceRelease(colorSpace);
    
    [CATransaction begin];
    view.layer.contents = (__bridge id)newImage;
    [CATransaction commit];
    
    CFRelease(newImage);
}

- (void) viewWillAppear
{
    // check if preview has to be started/stopped by this controller
    self.shouldHandlePreview = !Video::PreviewManager::instance().previewRenderer()->isRendering();
    
    [self connectPreviewSignals];
    if (self.shouldHandlePreview) {
        Video::PreviewManager::instance().stopPreview();
        Video::PreviewManager::instance().startPreview();
    }
}

- (void)viewWillDisappear
{
    QObject::disconnect(frameUpdated);
    QObject::disconnect(previewStopped);
    QObject::disconnect(previewStarted);
    if (self.shouldHandlePreview) {
        Video::PreviewManager::instance().stopPreview();
    }
}

#pragma mark - NSMenuDelegate methods

- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(NSInteger)index shouldCancel:(BOOL)shouldCancel
{
    if(self.videoDevicesList.menu == menu) {
        auto device = deviceModel->devices()[index];
        [item setTitle: device->name().toNSString()];
        if (index == deviceModel->activeIndex()) {
            [videoDevicesList selectItem:item];
        }
    } else if(self.sizesList.menu == menu) {
        auto resolution = deviceModel->activeDevice()->channelList()[0]->validResolutions()[index];
        [item setTitle: resolution->name().toNSString()];
        if (resolution == deviceModel->activeDevice()->channelList()[0]->activeResolution()) {
            [sizesList selectItem:item];
        }
    } else if(self.ratesList.menu == menu) {
        auto rate = deviceModel->activeDevice()->channelList()[0]->activeResolution()->validRates()[index];
        [item setTitle: rate->name().toNSString()];
        if (rate == deviceModel->activeDevice()->channelList()[0]->activeResolution()->activeRate()) {
            [ratesList selectItem:item];
        }
    }
    return YES;
}

@end
