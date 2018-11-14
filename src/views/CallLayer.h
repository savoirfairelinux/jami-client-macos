/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *  Author: Anthony Léonard <anthony.leonard@savoirfairelinux.com>
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

#import <Cocoa/Cocoa.h>
#import <QSize>
#import <video/renderer.h>
///LRC
#import <video/previewmanager.h>
#import <video/renderer.h>
#import <api/newcallmodel.h>
#import <api/call.h>
#import <api/conversationmodel.h>
#import <api/avmodel.h>
#import <api/newvideo.h>
#include <api/newcodecmodel.h>

@interface CallLayer : NSOpenGLLayer

@property BOOL videoRunning;

- (void) setCurrentFrame:(lrc::api::video::Frame)framePtr;

@end
