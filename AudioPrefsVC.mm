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
#import "AudioPrefsVC.h"

#import <audio/settings.h>
#import <QUrl>
#import <audio/inputdevicemodel.h>
#import <audio/outputdevicemodel.h>
#import <qitemselectionmodel.h>

#import "QNSTreeController.h"

@interface AudioPrefsVC ()
@property (assign) IBOutlet NSPathControl *recordingsPathControl;

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

    QModelIndex qInputIdx = Audio::Settings::instance()->inputDeviceModel()->selectionModel()->currentIndex();
    QModelIndex qOutputIdx = Audio::Settings::instance()->outputDeviceModel()->selectionModel()->currentIndex();
    [self.outputDeviceList addItemWithTitle:Audio::Settings::instance()->outputDeviceModel()->data(qOutputIdx, Qt::DisplayRole).toString().toNSString()];
    [self.inputDeviceList addItemWithTitle:Audio::Settings::instance()->inputDeviceModel()->data(qInputIdx, Qt::DisplayRole).toString().toNSString()];
    [self.alwaysRecordingButton setState:
            Audio::Settings::instance()->isAlwaysRecording()?NSOnState:NSOffState];

    [self.muteDTMFButton setState:
            Audio::Settings::instance()->areDTMFMuted()?NSOnState:NSOffState];

    if([[Audio::Settings::instance()->recordPath().toNSURL() absoluteString] isEqualToString:@""]) {
        NSArray * pathComponentArray = [self pathComponentArray];
        [recordingsPathControl setPathComponentCells:pathComponentArray];
    }

}

- (IBAction)toggleMuteDTMF:(NSButton *)sender
{
    Audio::Settings::instance()->setDTMFMuted([sender state] == NSOnState);
}

- (IBAction)toggleAlwaysRecording:(NSButton *)sender
{
    Audio::Settings::instance()->setAlwaysRecording([sender state] == NSOnState);
}

- (IBAction)pathControlSingleClick:(id)sender {
    // Select that chosen component of the path.
    [self.recordingsPathControl setURL:[[self.recordingsPathControl clickedPathComponentCell] URL]];
    Audio::Settings::instance()->setRecordPath(QUrl::fromNSURL(self.recordingsPathControl.URL));
}

- (IBAction)chooseOutput:(id)sender {
    int index = [sender indexOfSelectedItem];
    QModelIndex qIdx = Audio::Settings::instance()->outputDeviceModel()->index(index, 0);
    Audio::Settings::instance()->outputDeviceModel()->selectionModel()->setCurrentIndex(
                                                    qIdx, QItemSelectionModel::ClearAndSelect);
}

- (IBAction)chooseInput:(id)sender {
    int index = [sender indexOfSelectedItem];
    QModelIndex qIdx = Audio::Settings::instance()->inputDeviceModel()->index(index, 0);
    Audio::Settings::instance()->inputDeviceModel()->selectionModel()->setCurrentIndex(
                                                    qIdx, QItemSelectionModel::ClearAndSelect);
}

#pragma mark - NSPathControl delegate methods

/*
 Assemble a set of custom cells to display into an array to pass to the path control.
 */
- (NSArray *)pathComponentArray
{
    NSMutableArray *pathComponentArray = [[NSMutableArray alloc] init];

    NSFileManager *fileManager = [[NSFileManager alloc] init];

    NSURL* desktopURL = [fileManager URLForDirectory:NSDesktopDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
    NSURL* documentsURL = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
    NSURL* userURL = [fileManager URLForDirectory:NSUserDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];

    NSPathComponentCell *componentCell;

    // Use utility method to obtain a NSPathComponentCell based on icon, title and URL.
    componentCell = [self componentCellForType:kGenericFolderIcon withTitle:@"Desktop" URL:desktopURL];
    [pathComponentArray addObject:componentCell];

    componentCell = [self componentCellForType:kGenericFolderIcon withTitle:@"Documents" URL:documentsURL];
    [pathComponentArray addObject:componentCell];

    componentCell = [self componentCellForType:kUserFolderIcon withTitle:NSUserName() URL:userURL];
    [pathComponentArray addObject:componentCell];

    return pathComponentArray;
}

/*
 This method is used by pathComponentArray to create a NSPathComponent cell based on icon, title and URL information. Each path component needs an icon, URL and title.
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
    [openPanel setTitle:NSLocalizedString(@"Choose a file", @"Open panel title")];
    [openPanel setPrompt:NSLocalizedString(@"Choose", @"Open panel prompt for 'Choose a directory'")];
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

#pragma mark - NSMenuDelegate methods

- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(NSInteger)index shouldCancel:(BOOL)shouldCancel
{
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

- (NSInteger)numberOfItemsInMenu:(NSMenu *)menu
{
    if([menu.title isEqualToString:@"inputlist"])
        return Audio::Settings::instance()->inputDeviceModel()->rowCount();
    else
        return Audio::Settings::instance()->outputDeviceModel()->rowCount();
}

@end
