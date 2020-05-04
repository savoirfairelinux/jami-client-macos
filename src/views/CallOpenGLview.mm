/*
*  Copyright (C) 2020 Savoir-faire Linux Inc.
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

#import "CallOpenGLview.h"
#import "CallLayer.h"

@implementation CallOpenGLview

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
    }
    return self;
}

-(void)setCurrentFrame:(lrc::api::video::Frame)framePtr {
    CallLayer* callLayer = (CallLayer*)self.layer;
    if ([callLayer respondsToSelector:@selector(setCurrentFrame:)]) {
        [callLayer setCurrentFrame:framePtr];
    }
}
-(void)renderWithPixelBuffer:(CVPixelBufferRef)buffer size:(CGSize)size rotation: (float)rotation fillFrame: (bool)fill {
    CallLayer* callLayer = (CallLayer*)self.layer;
    [callLayer renderWithPixelBuffer:buffer size:size rotation:rotation fillFrame:fill];
}
-(void)fillWithBlack {
    [self.layer setBackgroundColor:[[NSColor blackColor] CGColor]];
}
-(void)setupView {
    if (![self.layer isKindOfClass:[CallLayer class]]) {
        [self setLayer:[[CallLayer alloc] init]];
        [self setWantsLayer:true];
    }
}
- (void)setVideoRunning:(BOOL)running {
    CallLayer* callLayer = (CallLayer*)self.layer;
    callLayer.videoRunning = running;
    if (!running) {
        [callLayer setCurrentFrame:{}];
    }
}

@end
