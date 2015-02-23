/************************************************************************************
 *   Copyright (C) 2014-2015 by Savoir-Faire Linux                                  *
 *   Author : Alexandre Lision <alexandre.lision@savoirfairelinux.com>              *
 *                                                                                  *
 *   This library is free software; you can redistribute it and/or                  *
 *   modify it under the terms of the GNU Lesser General Public                     *
 *   License as published by the Free Software Foundation; either                   *
 *   version 2.1 of the License, or (at your option) any later version.             *
 *                                                                                  *
 *   This library is distributed in the hope that it will be useful,                *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of                 *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU              *
 *   Lesser General Public License for more details.                                *
 *                                                                                  *
 *   You should have received a copy of the GNU Lesser General Public               *
 *   License along with this library; if not, write to the Free Software            *
 *   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA *
 ***********************************************************************************/
#import "AudioPrefsVC.h"

#include <audio/settings.h>
#include <audio/inputdevicemodel.h>
#include <audio/outputdevicemodel.h>
#include <qitemselectionmodel.h>

#import "QNSTreeController.h"

@interface AudioPrefsVC ()

@end

@implementation AudioPrefsVC
@synthesize outputDeviceList;
@synthesize inputDeviceList;
@synthesize alwaysRecordingButton;
@synthesize muteDTMFButton;

- (void)loadView
{
    [super loadView];

    QModelIndex qInputIdx = Audio::Settings::instance()->inputDeviceModel()->selectionModel()->currentIndex();
    QModelIndex qOutputIdx = Audio::Settings::instance()->outputDeviceModel()->selectionModel()->currentIndex();
    [self.outputDeviceList addItemWithTitle:Audio::Settings::instance()->outputDeviceModel()->data(qOutputIdx, Qt::DisplayRole).toString().toNSString()];
    [self.inputDeviceList addItemWithTitle:Audio::Settings::instance()->inputDeviceModel()->data(qInputIdx, Qt::DisplayRole).toString().toNSString()];
    [self.alwaysRecordingButton setState:
            Audio::Settings::instance()->isAlwaysRecording()?NSOnState:NSOffState];

    [self.muteDTMFButton setState:
            Audio::Settings::instance()->areDTMFMuted()?NSOnState:NSOffState];

}

- (IBAction)toggleMuteDTMF:(NSButton *)sender
{
    Audio::Settings::instance()->setDTMFMuted([sender state] == NSOnState);
}

- (IBAction)toggleAlwaysRecording:(NSButton *)sender
{
    Audio::Settings::instance()->setAlwaysRecording([sender state] == NSOnState);
}

- (IBAction)chooseDirectory:(id)sender {
    NSOpenPanel *openPanel = [[NSOpenPanel alloc] init];

    if ([openPanel runModal] == NSOKButton)
    {
        NSString *selectedFileName = [openPanel filename];
    }
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

    if([menu.title isEqualToString:@"inputlist"])
    {
        qIdx = Audio::Settings::instance()->inputDeviceModel()->index(index);
        [item setTitle:Audio::Settings::instance()->inputDeviceModel()->data(qIdx, Qt::DisplayRole).toString().toNSString()];
    } else
    {
        qIdx = Audio::Settings::instance()->outputDeviceModel()->index(index);
        [item setTitle:Audio::Settings::instance()->outputDeviceModel()->data(qIdx, Qt::DisplayRole).toString().toNSString()];
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
    if([menu.title isEqualToString:@"inputlist"])
        return Audio::Settings::instance()->inputDeviceModel()->rowCount();
    else
        return Audio::Settings::instance()->outputDeviceModel()->rowCount();
}

@end
