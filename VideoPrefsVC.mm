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

#import <video/sourcesmodel.h>

@interface VideoPrefsVC ()

@end

@implementation VideoPrefsVC
@synthesize videoDevicesButton;
@synthesize channelsButton;
@synthesize sizesButton;
@synthesize ratesButton;

- (void)loadView
{
    [super loadView];

    [self.videoDevicesButton addItemWithTitle:@"COUCOU"];

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
