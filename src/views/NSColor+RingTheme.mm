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

#import "NSColor+RingTheme.h"

@implementation NSColor (RingTheme)

+ (NSColor*) ringBlue
{
    return [NSColor colorWithCalibratedRed:43/255.0 green:180/255.0 blue:201/255.0 alpha:1.0];
}

+ (NSColor*) ringBlueWithAlpha:(CGFloat) a
{
    return [NSColor colorWithCalibratedRed:43/255.0 green:180/255.0 blue:201/255.0 alpha:a];
}

+ (NSColor*) ringDarkBlue
{
    return [NSColor colorWithCalibratedRed:0/255.0 green:59/255.0 blue:78/255.0 alpha:1.0];
}

+ (NSColor*) ringGreyHighlight
{
    return [NSColor colorWithCalibratedRed:239/255.0 green:239/255.0 blue:239/255.0 alpha:1.0];
}

+ (NSColor*) ringGreyLight
{
    return [NSColor colorWithCalibratedRed:176/255.0 green:176/255.0 blue:176/255.0 alpha:1.0];
}

+ (NSColor*) ringDarkGrey
{
    return [NSColor colorWithCalibratedRed:41/255.0 green:41/255.0 blue:41/255.0 alpha:1.0];
}

+ (NSColor*) ringLightBlue
{
return [NSColor colorWithCalibratedRed:59/255.0 green:193/255.0 blue:211/255.0 alpha:0.3];
}

+ (NSColor*) errorColor
{
    return [NSColor colorWithCalibratedRed:255/255.0 green:102/255.0 blue:102/255.0 alpha:1];
}

+ (NSColor*) errorTransferColor
{
    return [NSColor colorWithCalibratedRed:204/255.0 green:51/255.0 blue:51/255.0 alpha:1];
}

+ (NSColor*) buttonBlinkColorColor {
    return [NSColor colorWithCalibratedRed:185/255.0 green:90/255.0 blue:35/255.0 alpha:1];
}

+ (NSColor*) unregisteredColor
{
    return [NSColor colorWithCalibratedRed:255/255.0 green:59/255.0 blue:40/255.0 alpha:1];
}

+ (NSColor*) greenSuccessColor
{
    return [NSColor colorWithCalibratedRed:0/255.0 green:178/255.0 blue:11/255.0 alpha:1];
}

+ (NSColor*) presenceColor
{
    return [NSColor colorWithCalibratedRed:76/255.0 green:217/255.0 blue:100/255.0 alpha:1];
}


- (NSColor *)lightenColorByValue:(float)value {
    if(![self isKindOfClass:[NSCalibratedRGBColorSpace class]]) {
        return self;
    }
    float red = [self redComponent];
    red += value;

    float green = [self greenComponent];
    green += value;

    float blue = [self blueComponent];
    blue += value;

    return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:1.0f];
}

- (NSColor *)darkenColorByValue:(float)value {
    if(![self isKindOfClass:[NSCalibratedRGBColorSpace class]]) {
        return self;
    }
    float red = [self redComponent];
    red -= value;

    float green = [self greenComponent];
    green -= value;

    float blue = [self blueComponent];
    blue -= value;

    return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:1.0f];
}

- (BOOL)isLightColor {
    NSInteger   totalComponents = [self numberOfComponents];
    bool  isGreyscale     = totalComponents == 2 ? YES : NO;

    CGFloat sum;

    if (isGreyscale) {
        sum = [self redComponent];
    } else {
        sum = ([self redComponent]+[self greenComponent]+[self blueComponent])/3.0;
    }

    return (sum > 0.8);
}

+ (NSImage*) image:(NSImage*) img tintedWithColor:(NSColor *)tint
{
    NSImage* image = [img copy];
    if (tint) {
        [image lockFocus];
        [tint set];
        NSRect imageRect = {NSZeroPoint, [image size]};
        NSRectFillUsingOperation(imageRect, NSCompositeSourceAtop);
        [image unlockFocus];
    }
    return image;
}

@end
