//
//  AudioPrefsVC.m
//  Ring
//
//  Created by Alexandre Lision on 2015-02-19.
//
//

#import "AudioPrefsVC.h"

#include <audio/settings.h>
#include <audio/inputdevicemodel.h>
#include <audio/outputdevicemodel.h>

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

    [self.outputDeviceList addItemWithTitle:@"COUCOU"];
    [self.inputDeviceList addItemWithTitle:@"COUCOU"];
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
