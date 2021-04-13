/*
*  Copyright (C) 2021 Savoir-faire Linux Inc.
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

#import "FileToSendCollectionItem.h"
#import "NSColor+RingTheme.h"

@interface FileToSendCollectionItem ()

@end

@implementation FileToSendCollectionItem

- (void)viewDidLoad {
    [super viewDidLoad];
    self.placeholderPreview.image = [NSColor image: [NSImage imageNamed:@"ic_file.png"] tintedWithColor: [NSColor windowFrameTextColor]];
    self.closeButton.image = [NSColor image: [NSImage imageNamed:@"ic_action_cancel.png"] tintedWithColor: [NSColor windowFrameTextColor]];
    [NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(themeChanged:) name:@"AppleInterfaceThemeChangedNotification" object: nil];
}

-(void) deinit {
    [NSDistributedNotificationCenter.defaultCenter removeObserver:self];
}

-(void)themeChanged:(NSNotification *) notification {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        self.placeholderPreview.image = [NSColor image: [NSImage imageNamed:@"ic_file.png"] tintedWithColor: [NSColor windowFrameTextColor]];
        self.closeButton.image = [NSColor image: [NSImage imageNamed:@"ic_action_cancel.png"] tintedWithColor: [NSColor windowFrameTextColor]];
    });
}

@end
