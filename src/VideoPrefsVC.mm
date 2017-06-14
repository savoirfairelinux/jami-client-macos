/*
 *  Copyright (C) 2015-2016 Savoir-faire Linux Inc.
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
 */
#import "VideoPrefsVC.h"

#import <QuartzCore/QuartzCore.h>

#import <QItemSelectionModel>
#import <QAbstractProxyModel>

#import <video/configurationproxy.h>
#import <video/sourcemodel.h>
#import <video/previewmanager.h>
#import <video/renderer.h>
#import <video/device.h>
#import <video/devicemodel.h>

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

QMetaObject::Connection frameUpdated;
QMetaObject::Connection previewStarted;
QMetaObject::Connection previewStopped;

- (void)loadView
{
    [super loadView];

    // Make sure models are loaded
    Video::ConfigurationProxy::deviceModel().rowCount();
    Video::ConfigurationProxy::resolutionModel().rowCount();
    Video::ConfigurationProxy::rateModel().rowCount();

    // Prepopulate values
    QModelIndex qDeviceIdx = Video::ConfigurationProxy::deviceSelectionModel().currentIndex();
    [videoDevicesList addItemWithTitle:Video::ConfigurationProxy::deviceModel().data(qDeviceIdx, Qt::DisplayRole).toString().toNSString()];

    QModelIndex qSizeIdx = Video::ConfigurationProxy::resolutionSelectionModel().currentIndex();
    [sizesList addItemWithTitle:Video::ConfigurationProxy::resolutionModel().data(qSizeIdx, Qt::DisplayRole).toString().toNSString()];

    QModelIndex qRate = Video::ConfigurationProxy::rateSelectionModel().currentIndex();
    [ratesList addItemWithTitle:Video::ConfigurationProxy::rateModel().data(qDeviceIdx, Qt::DisplayRole).toString().toNSString()];

    // connect to model reset (device may have changed) and selection changed signals
    QObject::connect(qobject_cast<QAbstractProxyModel*>(&Video::ConfigurationProxy::resolutionModel()),
                     &QAbstractProxyModel::modelReset,
                     [=]() {
                         [sizesList removeAllItems];
                     });

    QObject::connect(&Video::ConfigurationProxy::resolutionSelectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {
                         if (!current.isValid()) {
                             return;
                         }
                         [sizesList removeAllItems];
                         [sizesList addItemWithTitle:Video::ConfigurationProxy::resolutionSelectionModel().currentIndex().data(Qt::DisplayRole).toString().toNSString()];

                     });

    QObject::connect(qobject_cast<QAbstractProxyModel*>(&Video::ConfigurationProxy::rateModel()),
                     &QAbstractProxyModel::modelReset,
                     [=]() {
                         [ratesList removeAllItems];
                     });

    QObject::connect(&Video::ConfigurationProxy::rateSelectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {
                         if (!current.isValid()) {
                             return;
                         }
                         [ratesList removeAllItems];
                         [ratesList addItemWithTitle:Video::ConfigurationProxy::rateSelectionModel().currentIndex().data(Qt::DisplayRole).toString().toNSString()];

                     });

    [previewView setWantsLayer:YES];
    [previewView setLayer:[CALayer layer]];
    [previewView.layer setBackgroundColor:[NSColor blackColor].CGColor];
    [previewView.layer setContentsGravity:kCAGravityResizeAspect];
    [previewView.layer setFrame:previewView.frame];
    [previewView.layer setBounds:previewView.frame];

    [self.enableHardwareAccelerationButton setState:Video::ConfigurationProxy::getDecodingAccelerated()];

}

- (IBAction)chooseDevice:(id)sender {
    int index = [sender indexOfSelectedItem];
    QModelIndex qIdx = Video::ConfigurationProxy::deviceModel().index(index, 0);
    Video::ConfigurationProxy::deviceSelectionModel().setCurrentIndex(qIdx, QItemSelectionModel::ClearAndSelect);
}

- (IBAction)chooseSize:(id)sender {
    int index = [sender indexOfSelectedItem];
    QModelIndex qIdx = Video::ConfigurationProxy::resolutionModel().index(index, 0);
    Video::ConfigurationProxy::resolutionSelectionModel().setCurrentIndex(qIdx, QItemSelectionModel::ClearAndSelect);
}

- (IBAction)chooseRate:(id)sender {
    int index = [sender indexOfSelectedItem];
    QModelIndex qIdx = Video::ConfigurationProxy::rateModel().index(index, 0);
    Video::ConfigurationProxy::rateSelectionModel().setCurrentIndex(qIdx, QItemSelectionModel::ClearAndSelect);
}

- (IBAction)toggleHardwareAcceleration:(NSButton *)sender {
    bool enabled = [sender state]==NSOnState;
    Video::ConfigurationProxy::setDecodingAccelerated(enabled);
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
    QModelIndex qIdx;
    if(self.videoDevicesList.menu == menu) {
        qIdx = Video::ConfigurationProxy::deviceModel().index(index, 0);
        [item setTitle:Video::ConfigurationProxy::deviceModel().data(qIdx, Qt::DisplayRole).toString().toNSString()];
        if (qIdx == Video::ConfigurationProxy::deviceSelectionModel().currentIndex()) {
            [videoDevicesList selectItem:item];
        }
    } else if(self.sizesList.menu == menu) {
        qIdx = Video::ConfigurationProxy::resolutionModel().index(index, 0);
        [item setTitle:Video::ConfigurationProxy::resolutionModel().data(qIdx, Qt::DisplayRole).toString().toNSString()];
        if (qIdx == Video::ConfigurationProxy::resolutionSelectionModel().currentIndex()) {
            [sizesList selectItem:item];
        }

    } else if(self.ratesList.menu == menu) {
        qIdx = Video::ConfigurationProxy::rateModel().index(index, 0);
        [item setTitle:Video::ConfigurationProxy::rateModel().data(qIdx, Qt::DisplayRole).toString().toNSString()];
        if (qIdx == Video::ConfigurationProxy::rateSelectionModel().currentIndex()) {
            [ratesList selectItem:item];
        }
    }
    return YES;
}

- (NSInteger)numberOfItemsInMenu:(NSMenu *)menu
{
    if(self.videoDevicesList.menu == menu) {
        return Video::ConfigurationProxy::deviceModel().rowCount();
    } else if(self.sizesList.menu == menu) {
        return Video::ConfigurationProxy::resolutionModel().rowCount();
    } else if(self.ratesList.menu == menu) {
        return Video::ConfigurationProxy::rateModel().rowCount();
    }
    return 0;
}

@end
