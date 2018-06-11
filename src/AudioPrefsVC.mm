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
#import "AudioPrefsVC.h"

#import <audio/settings.h>
#import <media/recordingmodel.h>
#import <QUrl>
#import <audio/inputdevicemodel.h>
#import <audio/outputdevicemodel.h>
#import <qitemselectionmodel.h>
#import "utils.h"

@interface AudioPrefsVC ()

@property (assign) IBOutlet NSPathControl *recordingsPathControl;
@property (assign) IBOutlet NSPopUpButton *outputDeviceList;
@property (assign) IBOutlet NSPopUpButton *inputDeviceList;
@property (assign) IBOutlet NSButton *alwaysRecordingButton;
@property (assign) IBOutlet NSButton *muteDTMFButton;

@end

@implementation AudioPrefsVC
@synthesize recordingsPathControl;
@synthesize outputDeviceList;
@synthesize inputDeviceList;
@synthesize alwaysRecordingButton;
@synthesize muteDTMFButton;

- (void)loadView
{
    [super loadView];

    QModelIndex qInputIdx = Audio::Settings::instance().inputDeviceModel()->selectionModel()->currentIndex();
    QModelIndex qOutputIdx = Audio::Settings::instance().outputDeviceModel()->selectionModel()->currentIndex();
    
    [self.outputDeviceList addItemWithTitle:
            Audio::Settings::instance().outputDeviceModel()->data(qOutputIdx, Qt::DisplayRole).toString().toNSString()];

    [self.inputDeviceList addItemWithTitle:
            Audio::Settings::instance().inputDeviceModel()->data(qInputIdx, Qt::DisplayRole).toString().toNSString()];
    [self.alwaysRecordingButton setState:
            Media::RecordingModel::instance().isAlwaysRecording() ? NSOnState:NSOffState];

    [self.muteDTMFButton setState:
            Audio::Settings::instance().areDTMFMuted()?NSOnState:NSOffState];
    NSArray* pathComponentArray = [self pathComponentArrayWithCurrentUrl:Media::RecordingModel::instance().recordPath().toNSString()];
    [recordingsPathControl setPathComponentCells:pathComponentArray];
}

- (IBAction)toggleMuteDTMF:(NSButton *)sender
{
    Audio::Settings::instance().setDTMFMuted([sender state] == NSOnState);
}

- (IBAction)toggleAlwaysRecording:(NSButton *)sender
{
    Media::RecordingModel::instance().setAlwaysRecording([sender state] == NSOnState);
}

- (IBAction)pathControlSingleClick:(id)sender {
    // Select that chosen component of the path.
    NSArray* pathComponentArray = [self pathComponentArrayWithCurrentUrl:[[self.recordingsPathControl clickedPathComponentCell] URL].path];
    [recordingsPathControl setPathComponentCells:pathComponentArray];
 Media::RecordingModel::instance().setRecordPath(QString::fromNSString([self.recordingsPathControl.URL path]));
}

- (IBAction)chooseOutput:(id)sender {
    int index = [sender indexOfSelectedItem];
    QModelIndex qIdx = Audio::Settings::instance().outputDeviceModel()->index(index, 0);
    Audio::Settings::instance().outputDeviceModel()->selectionModel()->setCurrentIndex(
                                                    qIdx, QItemSelectionModel::ClearAndSelect);
}

- (IBAction)chooseInput:(id)sender {
    int index = [sender indexOfSelectedItem];
    QModelIndex qIdx = Audio::Settings::instance().inputDeviceModel()->index(index, 0);
    Audio::Settings::instance().inputDeviceModel()->selectionModel()->setCurrentIndex(
                                                    qIdx, QItemSelectionModel::ClearAndSelect);
}

#pragma mark - NSPathControl delegate methods

/*
 Assemble a set of custom cells to display into an array to pass to the path control.
 */
- (NSArray *)pathComponentArrayWithCurrentUrl:(NSString *) url
{

    NSMutableArray *pathComponentArray = [[NSMutableArray alloc] init];

    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSURL* downloadURL = [fileManager URLForDirectory:NSDownloadsDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];

    NSPathComponentCell *componentCell;
    componentCell = [self componentCellForType:kGenericFolderIcon withTitle:@"Downloads" URL:downloadURL];
    [pathComponentArray addObject:componentCell];
    NSString * downloads = [downloadURL path];
    if([url isEqualToString:downloads]) {
        return pathComponentArray;
    }
    if(![url isEqualToString:@""]) {
        NSString * name = [url componentsSeparatedByString:@"/"].lastObject;
        if(!name) {
            return pathComponentArray;
        }
        componentCell = [self componentCellForType:kGenericFolderIcon withTitle:name URL:[NSURL URLWithString: url]];
        [pathComponentArray addObject:componentCell];
    }
    return pathComponentArray;
}

/*
 This method is used by pathComponentArray to create a NSPathComponent cell based on icon, title and URL information.
 Each path component needs an icon, URL and title.
 */
- (NSPathComponentCell *)componentCellForType:(OSType)withIconType withTitle:(NSString *)title URL:(NSURL *)url
{
    NSPathComponentCell *componentCell = [[NSPathComponentCell alloc] init];

    NSImage *iconImage = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(withIconType)];
    [componentCell setImage:iconImage];
    [componentCell setURL:url];
    [componentCell setTitle:title];

    return componentCell;
}

/*
 Delegate method of NSPathControl to determine how the NSOpenPanel will look/behave.
 */
- (void)pathControl:(NSPathControl *)pathControl willDisplayOpenPanel:(NSOpenPanel *)openPanel
{
    NSLog(@"willDisplayOpenPanel");
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanChooseFiles:NO];
    [openPanel setResolvesAliases:YES];
    [openPanel setTitle:NSLocalizedString(@"Choose a directory", @"Open panel title")];
    [openPanel setPrompt:NSLocalizedString(@"Choose directory", @"Open panel prompt for 'Choose a directory'")];
    [openPanel setDelegate:self];
}

- (void)pathControl:(NSPathControl *)pathControl willPopUpMenu:(NSMenu *)menu
{

}

#pragma mark - NSOpenSavePanelDelegate delegate methods

- (BOOL)panel:(id)sender validateURL:(NSURL *)url error:(NSError **)outError
{
    [recordingsPathControl setURL:url];
    return YES;
}

- (BOOL) panel:(id)sender shouldEnableURL:(NSURL*)url {
    if(!appSandboxed()) {
        return YES;
    }
    return isUrlAccessibleFromSandbox(url);
}

#pragma mark - NSMenuDelegate methods

- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(NSInteger)index shouldCancel:(BOOL)shouldCancel
{
    QModelIndex qIdx;

    if (inputDeviceList.menu == menu) {
        qIdx = Audio::Settings::instance().inputDeviceModel()->index(index);
        [item setTitle:Audio::Settings::instance().inputDeviceModel()->data(qIdx, Qt::DisplayRole).toString().toNSString()];
    } else {
        qIdx = Audio::Settings::instance().outputDeviceModel()->index(index);
        [item setTitle:Audio::Settings::instance().outputDeviceModel()->data(qIdx, Qt::DisplayRole).toString().toNSString()];
    }

    return YES;
}

- (NSInteger)numberOfItemsInMenu:(NSMenu *)menu
{
    if (inputDeviceList.menu == menu)
        return Audio::Settings::instance().inputDeviceModel()->rowCount();
    else
        return Audio::Settings::instance().outputDeviceModel()->rowCount();
}

@end
