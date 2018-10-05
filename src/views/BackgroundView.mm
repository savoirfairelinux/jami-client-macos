/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
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

#import "BackgroundView.h"

@interface BackgroundView()

@property __strong NSImage* centerImage;

@end

@implementation BackgroundView

//-(void) awakeFromNib
//{
//    switch (self.theme) {
//        case Dark:
//            self.centerImage = [NSImage imageNamed:@"background-dark.png"];
//            break;
//        case Light:
//        default:
//            self.centerImage = [NSImage imageNamed:@"background-light.png"];
//            break;
//    }
//}
//
//- (void) drawRect:(NSRect)dirtyRect
//{
//    NSDrawThreePartImage([self frame], nil, self.centerImage, nil, NO, NSCompositeSourceOver, 1.0, NO);
//}

@end
