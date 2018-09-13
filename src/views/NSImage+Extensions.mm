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

#import "NSImage+Extensions.h"

@implementation NSImage (Extensions)

+ (NSImage *)imageResize:(NSImage*)anImage
                 newSize:(NSSize)newSize
{
    auto sourceImage = anImage;
    NSSize size = anImage.size;
    // Report an error if the source isn't a valid image
    if (![sourceImage isValid]) {
        NSLog(@"Invalid Image");
    } else {
        auto smallImage = [[NSImage alloc] initWithSize: newSize];
        [smallImage lockFocus];
        [sourceImage setSize: newSize];
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
        [sourceImage drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.];
        [smallImage unlockFocus];
        return smallImage;
    }
    return nil;
}

- (NSImage *) roundCorners:(CGFloat)radius {
   // NSImage *existingImage = self;
    NSSize existingSize = [self size];
    NSSize newSize = NSMakeSize(existingSize.width, existingSize.height);
    NSImage *composedImage = [[NSImage alloc] initWithSize:newSize];

    [composedImage lockFocus];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];

    NSRect imageFrame = NSRectFromCGRect(CGRectMake(0, 0, existingSize.width, existingSize.height));
    NSBezierPath *clipPath = [NSBezierPath bezierPathWithRoundedRect:imageFrame xRadius:radius yRadius:radius];
    [clipPath setWindingRule:NSEvenOddWindingRule];
    [clipPath addClip];

    [self drawAtPoint:NSZeroPoint fromRect:NSMakeRect(0, 0, newSize.width, newSize.height) operation:NSCompositeSourceOver fraction:1];
    [self drawInRect:imageFrame fromRect:NSMakeRect(0, 0, 0, 0) operation:NSCompositeSourceIn fraction:1.0];

    [composedImage unlockFocus];

    return composedImage;
}

- (NSImage *)roundCornersImageCornerRadius:(NSInteger)radius {
    int w = (int) self.size.width;
    int h = (int) self.size.height;

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, w, h, 8, 4 * w, colorSpace, kCGImageAlphaPremultipliedFirst);

    CGContextBeginPath(context);
    CGRect rect = CGRectMake(0, 0, w, h);
    addRoundedRectToPath(context, rect, radius, radius);
    CGContextClosePath(context);
    CGContextClip(context);

    CGImageRef cgImage = [[NSBitmapImageRep imageRepWithData:[self TIFFRepresentation]] CGImage];

    CGContextDrawImage(context, CGRectMake(0, 0, w, h), cgImage);

    CGImageRef imageMasked = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);

    NSImage *tmpImage = [[NSImage alloc] initWithCGImage:imageMasked size:self.size];
    NSData *imageData = [tmpImage TIFFRepresentation];
    NSImage *image = [[NSImage alloc] initWithData:imageData];

    return image;
}

void addRoundedRectToPath(CGContextRef context, CGRect rect, float ovalWidth, float ovalHeight)
{
    float fw, fh;
    if (ovalWidth == 0 || ovalHeight == 0) {
        CGContextAddRect(context, rect);
        return;
    }
    CGContextSaveGState(context);
    CGContextTranslateCTM (context, CGRectGetMinX(rect), CGRectGetMinY(rect));
    CGContextScaleCTM (context, ovalWidth, ovalHeight);
    fw = CGRectGetWidth (rect) / ovalWidth;
    fh = CGRectGetHeight (rect) / ovalHeight;
    CGContextMoveToPoint(context, fw, fh/2);
    CGContextAddArcToPoint(context, fw, fh, fw/2, fh, 1);
    CGContextAddArcToPoint(context, 0, fh, 0, fh/2, 1);
    CGContextAddArcToPoint(context, 0, 0, fw/2, 0, 1);
    CGContextAddArcToPoint(context, fw, 0, fw, fh/2, 1);
    CGContextClosePath(context);
    CGContextRestoreGState(context);
}

- (NSImage*) imageResizeInsideMax:(CGFloat) dimension {
    if (self.size.width < dimension && self.size.height < dimension) {
        return self;
    }
    CGFloat widthScaleFactor = dimension / self.size.width;
    CGFloat heightScaleFactor = dimension / self.size.height;
    CGFloat scale = MIN(widthScaleFactor, heightScaleFactor);
    NSSize size = NSZeroSize;
    size.width = self.size.width * scale;
    size.height = self.size.height * scale;
    return [NSImage imageResize:self newSize:size];
}

- (NSImage *) cropImageToSize:(NSSize)newSize {
    CGImageSourceRef source;
    NSPoint origin = CGPointMake((self.size.width - newSize.width) * 0.5, (self.size.height - newSize.height) * 0.5);

    source = CGImageSourceCreateWithData((CFDataRef)[self TIFFRepresentation], NULL);
    CGImageRef imageRef =  CGImageSourceCreateImageAtIndex(source, 0, NULL);

    CGRect sizeToBe = CGRectMake(origin.x, origin.y, newSize.width, newSize.height);
    CGImageRef croppedImage = CGImageCreateWithImageInRect(imageRef, sizeToBe);
    NSImage *finalImage = [[NSImage alloc] initWithCGImage:croppedImage size:NSZeroSize];
    CFRelease(imageRef);
    CFRelease(croppedImage);

    return finalImage;

}

@end
