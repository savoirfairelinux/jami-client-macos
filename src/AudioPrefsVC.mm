/*
 *  Copyright (C) 2015-2016 Savoir-faire Linux Inc.
 *  Author: Alexandre Lision <alexandre.lision@savoirfairelinux.com>
 *  Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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
#import "AudioPrefsVC.h"

//LRC
#import <api/avmodel.h>

@interface AudioPrefsVC ()

@property (assign) IBOutlet NSPopUpButton *outputDeviceList;
@property (assign) IBOutlet NSPopUpButton *inputDeviceList;
@end

@implementation AudioPrefsVC
@synthesize outputDeviceList;
@synthesize inputDeviceList;
@synthesize avModel;
QMetaObject::Connection audioDeviceEvent;

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
    [self connectdDeviceEvent];
    [self addDevices];
}

-(void) addDevices {
    [inputDeviceList removeAllItems];
    [outputDeviceList removeAllItems];
    auto inputDevices = avModel->getAudioInputDevices();
    auto inputDevice = avModel->getInputDevice();
    for (auto device : inputDevices) {
        [inputDeviceList addItemWithTitle: @(device.c_str())];
    }
    [inputDeviceList selectItemWithTitle:@(inputDevice.c_str())];
    auto outputDevices = avModel->getAudioOutputDevices();
    auto outputDevice = avModel->getOutputDevice();
    for (auto device : outputDevices) {
        [outputDeviceList addItemWithTitle: @(device.c_str())];
    }
    [outputDeviceList selectItemWithTitle:@(outputDevice.c_str())];
}

-(void)connectdDeviceEvent {
    QObject::disconnect(audioDeviceEvent);
    audioDeviceEvent = QObject::connect(avModel,
                                   &lrc::api::AVModel::deviceEvent,
                                   [=]() {
                                       [self addDevices];
                                   });
}

- (IBAction)chooseOutput:(id)sender {
    int index = [sender indexOfSelectedItem];
    auto output = [self.outputDeviceList itemTitleAtIndex:index];
    avModel->setOutputDevice([output UTF8String]);
}

- (IBAction)chooseInput:(id)sender {
    int index = [sender indexOfSelectedItem];
    auto input = [self.inputDeviceList itemTitleAtIndex:index];
    avModel->setInputDevice([input UTF8String]);
}

@end
