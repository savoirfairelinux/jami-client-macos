/*
 *  Copyright (C) 2018-2019 Savoir-faire Linux Inc.
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

#import "NSString+Extensions.h"

@implementation NSString (Extensions)

- (NSString *) removeAllNewLinesAtTheEnd {
    NSString *result = self;
    while ([result endedByEmptyLine]) {
        result = [result removeLastWhiteSpaceAndNewLineCharacter];
    }
    return result;
}

- (NSString *) removeAllNewLinesAtBegining {
    NSString *result = self;
    while ([result startByEmptyLine]) {
        result = [result removeFirstWhiteSpaceAndNewLineCharacter];
    }
    return result;
}

- (NSString *) removeEmptyLinesAtBorders {
    NSString *result = self;
    result = [result removeAllNewLinesAtBegining];
    result = [result removeAllNewLinesAtTheEnd];
    return result;
}

-(bool)endedByEmptyLine {
    if ([self length] < 1) {
        return false;
    }
    unichar last = [self characterAtIndex:[self length] - 1];
    return [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:last];
}

- (bool)startByEmptyLine {
    if ([self length] < 1) {
        return false;
    }
    unichar first = [self characterAtIndex:0];
    return [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:first];
}

- (NSString *) removeLastWhiteSpaceAndNewLineCharacter {
    if ([self endedByEmptyLine]) {
        return [self substringToIndex:[self length]-1];
    }
    return self;
}

- (NSString *) removeFirstWhiteSpaceAndNewLineCharacter {
    if ([self startByEmptyLine]) {
        return [self substringFromIndex:1];
    }
    return self;
}

+ (NSString *) formattedStringTimeFromSeconds:(int) totalSeconds {
    int seconds = totalSeconds % 60;
    int minutes = (totalSeconds / 60) % 60;
    return [NSString stringWithFormat:@"%02d:%02d",minutes, seconds];
}

@end
