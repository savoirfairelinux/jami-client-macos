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

#import <video/sourcesmodel.h>
#import <video/previewmanager.h>
#import <video/renderer.h>

@interface VideoPrefsVC ()

@property (assign) IBOutlet NSView *previewView;
@property (assign) IBOutlet NSPopUpButton *videoDevicesButton;
@property (assign) IBOutlet NSPopUpButton *channelsButton;
@property (assign) IBOutlet NSPopUpButton *sizesButton;
@property (assign) IBOutlet NSPopUpButton *ratesButton;

@end

@implementation VideoPrefsVC
@synthesize previewView;
@synthesize videoDevicesButton;
@synthesize channelsButton;
@synthesize sizesButton;
@synthesize ratesButton;

QMetaObject::Connection frameUpdated;
QMetaObject::Connection previewStarted;
QMetaObject::Connection previewStopped;

- (void)loadView
{
    [super loadView];

    [self.videoDevicesButton addItemWithTitle:@"COUCOU"];

    [previewView setWantsLayer:YES];
    [previewView setLayer:[CALayer layer]];
    [previewView.layer setBackgroundColor:[NSColor blackColor].CGColor];
    [previewView.layer setContentsGravity:kCAGravityResizeAspect];
    [previewView.layer setFrame:previewView.frame];

    [self connectPreviewSignals];

}

- (void) connectPreviewSignals
{
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

#pragma mark - NSMenuDelegate methods

- (BOOL)menuHasKeyEquivalent:(NSMenu *)menu
                    forEvent:(NSEvent *)event
                      target:(id *)target
                      action:(SEL *)action
{
    NSLog(@"menuHasKeyEquivalent");
    return YES;
}

- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(NSInteger)index shouldCancel:(BOOL)shouldCancel
{
    NSLog(@"updateItem");
    QModelIndex qIdx;

    if([menu.title isEqualToString:@"devices"])
    {
        qIdx = Video::SourcesModel::instance()->index(index);
        [item setTitle:Video::SourcesModel::instance()->data(qIdx, Qt::DisplayRole).toString().toNSString()];
    }
    return YES;
}

- (void)menu:(NSMenu *)menu willHighlightItem:(NSMenuItem *)item
{
    NSLog(@"willHighlightItem");
}

- (void)menuWillOpen:(NSMenu *)menu
{
    NSLog(@"menuWillOpen");
}

- (void)menuDidClose:(NSMenu *)menu
{
    NSLog(@"menuDidClose");
}

- (NSInteger)numberOfItemsInMenu:(NSMenu *)menu
{
    if([menu.title isEqualToString:@"devices"])
        return Video::SourcesModel::instance()->rowCount();
}

@end
