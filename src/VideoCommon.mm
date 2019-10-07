/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
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

#import "VideoCommon.h"

#import <video/renderer.h>

#import <QSize>

extern "C" {
#import <libavutil/frame.h>
}

@implementation RendererConnectionsHolder

@end

@implementation VideoCommon

+ (void)copyLineByLineSrc:(uint8_t*)src
                   toDest:(uint8_t*)dest
              srcLinesize:(size_t)srcLinesize
             destLinesize:(size_t)destLinesize
                   height:(size_t)height {
    for (size_t i = 0; i < height ; i++) {
        memcpy(dest, src, srcLinesize);
        dest = dest + destLinesize;
        src = src + srcLinesize;
    }
}

+ (void) fillPixelBuffr:(CVPixelBufferRef &)pixelBuffer
              fromFrame:(const AVFrame*)frame
             bufferPool:(CVPixelBufferPoolRef &)pixelBufferPool {

    if(!frame || !frame->data[0] || !frame->data[1]) {
        return;
    }
    CVReturn theError;
    bool createPool = false;
    if (!pixelBufferPool) {
        createPool = true;
    } else {
        NSDictionary* atributes = (__bridge NSDictionary*)CVPixelBufferPoolGetAttributes(pixelBufferPool);
        if(!atributes)
            atributes = (__bridge NSDictionary*)CVPixelBufferPoolGetPixelBufferAttributes(pixelBufferPool);
        int width = [[atributes objectForKey:(NSString*)kCVPixelBufferWidthKey] intValue];
        int height = [[atributes objectForKey:(NSString*)kCVPixelBufferHeightKey] intValue];
        if (width != frame->width || height != frame->height) {
            createPool = true;
        }
    }
    if (createPool) {
        CVPixelBufferPoolRelease(pixelBufferPool);
        CVPixelBufferRelease(pixelBuffer);
        pixelBuffer = nil;
        pixelBufferPool = nil;
        NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
        [attributes setObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
        [attributes setObject:[NSNumber numberWithInt:frame->width] forKey: (NSString*)kCVPixelBufferWidthKey];
        [attributes setObject:[NSNumber numberWithInt:frame->height] forKey: (NSString*)kCVPixelBufferHeightKey];
        [attributes setObject:@(frame->linesize[0]) forKey:(NSString*)kCVPixelBufferBytesPerRowAlignmentKey];
        [attributes setObject:[NSDictionary dictionary] forKey:(NSString*)kCVPixelBufferIOSurfacePropertiesKey];
        theError = CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef) attributes, &pixelBufferPool);
        if (theError != kCVReturnSuccess) {
            NSLog(@"CVPixelBufferPoolCreate Failed");
            return;
        }
    }
    if(!pixelBuffer) {
        theError = CVPixelBufferPoolCreatePixelBuffer(NULL, pixelBufferPool, &pixelBuffer);
        if(theError != kCVReturnSuccess) {
            NSLog(@"CVPixelBufferPoolCreatePixelBuffer Failed");
            return;
        }
    }
    theError = CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    if (theError != kCVReturnSuccess) {
        NSLog(@"lock error");
        return;
    }
    size_t bytePerRowY = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    size_t bytesPerRowUV = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
    uint8_t*  base = static_cast<uint8_t*>(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0));
    if (bytePerRowY == frame->linesize[0]) {
        memcpy(base, frame->data[0], bytePerRowY * frame->height);
    } else {
        [VideoCommon copyLineByLineSrc: frame->data[0]
                                toDest: base
                           srcLinesize: frame->linesize[0]
                          destLinesize: bytePerRowY
                                height: frame->height];
    }
    if ((AVPixelFormat)frame->format == AV_PIX_FMT_NV12) {
        base = static_cast<uint8_t*>(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1));
        if (bytesPerRowUV == frame->linesize[0]) {
            memcpy(base, frame->data[1], bytesPerRowUV * frame->height/2);
        } else {
            [VideoCommon copyLineByLineSrc: frame->data[1]
                                    toDest: base
                               srcLinesize: frame->linesize[0]
                              destLinesize: bytesPerRowUV
                                    height: frame->height/2];
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return;
    }
    base = static_cast<uint8_t*>(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1));
    for(size_t i = 0; i < frame->height / 2 * bytesPerRowUV / 2; i++ ){
        *base++ = frame->data[1][i];
        *base++ = frame->data[2][i];
   }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

+ (CGSize) fillPixelBuffr:(CVPixelBufferRef &)pixelBuffer
           fromRenderer:(const lrc::api::video::Renderer*)renderer
             bufferPool:(CVPixelBufferPoolRef &)pixelBufferPool{
    auto framePtr = renderer->currentAVFrame();
    auto frame = framePtr.get();
    if(!frame || !frame->width || !frame->height) {
        return;
    }
    auto frameSize = CGSizeMake(frame->width, frame->height);
    if (frame->data[3] != NULL && (CVPixelBufferRef)frame->data[3]) {
        pixelBuffer = (CVPixelBufferRef)frame->data[3];
        return frameSize;
    }
    [VideoCommon fillPixelBuffr:&pixelBuffer fromFrame:frame bufferPool:&pixelBufferPool];
    return frameSize;
}

@end
