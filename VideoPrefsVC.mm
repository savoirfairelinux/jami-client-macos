/*
 *  Copyright (C) 2004-2015 Savoir-Faire Linux Inc.
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
 *
 *  Additional permission under GNU GPL version 3 section 7:
 *
 *  If you modify this program, or any covered work, by linking or
 *  combining it with the OpenSSL project's OpenSSL library (or a
 *  modified version of that library), containing parts covered by the
 *  terms of the OpenSSL or SSLeay licenses, Savoir-Faire Linux Inc.
 *  grants you additional permission to convey the resulting work.
 *  Corresponding Source for a non-source form of such a combination
 *  shall include the source code for the parts of OpenSSL used as well
 *  as that of the covered work.
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

@property (assign) IBOutlet NSView *previewView;
@property (assign) IBOutlet NSPopUpButton *videoDevicesList;
@property (assign) IBOutlet NSPopUpButton *sizesList;
@property (assign) IBOutlet NSPopUpButton *ratesList;

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

    Video::ConfigurationProxy::deviceModel()->rowCount();
    Video::ConfigurationProxy::resolutionModel()->rowCount();
    Video::ConfigurationProxy::rateModel()->rowCount();

    QModelIndex qDeviceIdx = Video::ConfigurationProxy::deviceSelectionModel()->currentIndex();
    qDeviceIdx = Video::ConfigurationProxy::deviceSelectionModel()->currentIndex();

    [videoDevicesList addItemWithTitle:Video::ConfigurationProxy::deviceModel()->data(qDeviceIdx, Qt::DisplayRole).toString().toNSString()];

    QModelIndex qSizeIdx = Video::ConfigurationProxy::resolutionSelectionModel()->currentIndex();
    [sizesList addItemWithTitle:Video::ConfigurationProxy::resolutionModel()->data(qSizeIdx, Qt::DisplayRole).toString().toNSString()];

    if(qobject_cast<QAbstractProxyModel*>(Video::ConfigurationProxy::resolutionModel())) {
        QObject::connect(qobject_cast<QAbstractProxyModel*>(Video::ConfigurationProxy::resolutionModel()),
                         &QAbstractProxyModel::modelReset,
                         [=]() {
                             NSLog(@"resolution Source model changed!!!");
                         });

    }

    QModelIndex qRate = Video::ConfigurationProxy::rateSelectionModel()->currentIndex();
    [ratesList addItemWithTitle:Video::ConfigurationProxy::rateModel()->data(qDeviceIdx, Qt::DisplayRole).toString().toNSString()];

    if(qobject_cast<QAbstractProxyModel*>(Video::ConfigurationProxy::rateModel())) {
        QObject::connect(qobject_cast<QAbstractProxyModel*>(Video::ConfigurationProxy::rateModel()),
                         &QAbstractProxyModel::modelReset,
                         [=]() {
                             NSLog(@"rates Source model changed!!!");
                         });

    }


    [previewView setWantsLayer:YES];
    [previewView setLayer:[CALayer layer]];
    [previewView.layer setBackgroundColor:[NSColor blackColor].CGColor];
    [previewView.layer setContentsGravity:kCAGravityResizeAspect];
    [previewView.layer setFrame:previewView.frame];
    [previewView.layer setBounds:previewView.frame];

    [self connectPreviewSignals];
}

- (IBAction)chooseDevice:(id)sender {
    int index = [sender indexOfSelectedItem];
    QModelIndex qIdx = Video::ConfigurationProxy::deviceModel()->index(index, 0);
    Video::ConfigurationProxy::deviceSelectionModel()->setCurrentIndex(qIdx, QItemSelectionModel::ClearAndSelect);
}

- (IBAction)chooseSize:(id)sender {
    int index = [sender indexOfSelectedItem];
    QModelIndex qIdx = Video::ConfigurationProxy::resolutionModel()->index(index, 0);
    Video::ConfigurationProxy::resolutionSelectionModel()->setCurrentIndex(qIdx, QItemSelectionModel::ClearAndSelect);
}

- (IBAction)chooseRate:(id)sender {
    int index = [sender indexOfSelectedItem];
    QModelIndex qIdx = Video::ConfigurationProxy::rateModel()->index(index, 0);
    Video::ConfigurationProxy::rateSelectionModel()->setCurrentIndex(qIdx, QItemSelectionModel::ClearAndSelect);
}

- (void) connectPreviewSignals
{
    QObject::disconnect(frameUpdated);
    QObject::disconnect(previewStopped);
    QObject::disconnect(previewStarted);
    previewStarted = QObject::connect(Video::PreviewManager::instance(),
                                             &Video::PreviewManager::previewStarted,
                                             [=](Video::Renderer* renderer) {
                                                 NSLog(@"Preview started");
                                                 QObject::disconnect(frameUpdated);
                                                 frameUpdated = QObject::connect(renderer,
                                                                                 &Video::Renderer::frameUpdated,
                                                                                 [=]() {
                                                                                     [self renderer:Video::PreviewManager::instance()->previewRenderer() renderFrameForView:previewView];
                                                                                 });
                                             });

    previewStopped = QObject::connect(Video::PreviewManager::instance(),
                                             &Video::PreviewManager::previewStopped,
                                             [=](Video::Renderer* renderer) {
                                                 NSLog(@"Preview stopped");
                                                 QObject::disconnect(frameUpdated);
                                                 [previewView.layer setContents:nil];
                                             });

    frameUpdated = QObject::connect(Video::PreviewManager::instance()->previewRenderer(),
                                                  &Video::Renderer::frameUpdated,
                                                  [=]() {
                                                      [self renderer:Video::PreviewManager::instance()->previewRenderer()
                                                  renderFrameForView:previewView];
                                                  });
}

-(void) renderer: (Video::Renderer*)renderer renderFrameForView:(NSView*) view
{
    const QByteArray& data = renderer->currentFrame();
    QSize res = renderer->size();

    auto buf = reinterpret_cast<const unsigned char*>(data.data());

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef newContext = CGBitmapContextCreate((void *)buf,
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

- (IBAction)togglePreview:(id)sender {
    if([sender state] == NSOnState)
        Video::PreviewManager::instance()->startPreview();
    else
        Video::PreviewManager::instance()->stopPreview();
}

- (void)viewWillDisappear
{
    Video::PreviewManager::instance()->stopPreview();
}

#pragma mark - NSMenuDelegate methods

- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(NSInteger)index shouldCancel:(BOOL)shouldCancel
{
    QModelIndex qIdx;
    if([menu.title isEqualToString:@"devices"]) {

        qIdx = Video::ConfigurationProxy::deviceModel()->index(index, 0);
        [item setTitle:Video::ConfigurationProxy::deviceModel()->data(qIdx, Qt::DisplayRole).toString().toNSString()];

    } else if([menu.title isEqualToString:@"sizes"]) {

        qIdx = Video::ConfigurationProxy::resolutionModel()->index(index, 0);
        [item setTitle:Video::ConfigurationProxy::resolutionModel()->data(qIdx, Qt::DisplayRole).toString().toNSString()];

    } else if([menu.title isEqualToString:@"rates"]) {

        qIdx = Video::ConfigurationProxy::rateModel()->index(index, 0);
        [item setTitle:Video::ConfigurationProxy::rateModel()->data(qIdx, Qt::DisplayRole).toString().toNSString()];

    }
    return YES;
}

- (NSInteger)numberOfItemsInMenu:(NSMenu *)menu
{
    if([menu.title isEqualToString:@"devices"]) {
        return Video::ConfigurationProxy::deviceModel()->rowCount();
    } else if([menu.title isEqualToString:@"sizes"]) {
        return Video::ConfigurationProxy::resolutionModel()->rowCount();
    } else if([menu.title isEqualToString:@"rates"]) {
        return Video::ConfigurationProxy::rateModel()->rowCount();
    }
}

@end
