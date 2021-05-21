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

#import "ChangeAudioVolumeVC.h"
#import "views/NSColor+RingTheme.h"

#import <api/avmodel.h>

@interface ChangeAudioVolumeVC () {
    __unsafe_unretained IBOutlet NSSlider* volumeSlider;
    __unsafe_unretained IBOutlet NSButton* muteButton;
}

@end

@implementation ChangeAudioVolumeVC

QString audioDevice;
lrc::api::AVModel *mModel;
AudioType audioType;

-(void)setMediaDevice:(const QString&)device avModel:(lrc::api::AVModel *)avModel andType:(AudioType)type {
    audioDevice = device;
    mModel = avModel;
    audioType = type;
    muteButton.image = [self buttonImage];
}

-(NSImage* )buttonImage {
    auto muted = [self.delegate isAudioMuted: audioType];
    switch (audioType) {
        case input:
            if (muted) {
                return [NSColor image: [NSImage imageNamed:@"micro_off.png"] tintedWithColor: [NSColor whiteColor]];

            }
            return [NSColor image: [NSImage imageNamed:@"micro_on.png"] tintedWithColor: [NSColor whiteColor]];
        case output:
            if (muted) {
                return [NSColor image: [NSImage imageNamed:@"sound_off.png"] tintedWithColor: [NSColor whiteColor]];
            }
            return [NSColor image: [NSImage imageNamed:@"sound_on.png"] tintedWithColor: [NSColor whiteColor]];
    }
}

- (IBAction)setDeviceVolume:(NSSlider*)sender {
}

- (IBAction)muteDevice:(id)sender {
    self.onMuted();
    muteButton.image = [self buttonImage];
}

@end
