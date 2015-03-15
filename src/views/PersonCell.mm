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

#import "PersonCell.h"

#define kImageOriginXOffset     3
#define kImageOriginYOffset     1

#define kTextOriginXOffset      2
#define kTextOriginYOffset      2
#define kTextHeightAdjust       4

@implementation PersonCell

// -------------------------------------------------------------------------------
//	initTextCell:aString
// -------------------------------------------------------------------------------
- (instancetype)initTextCell:(NSString *)aString
{
    self = [super initTextCell:aString];
    if (self != nil)
    {
        // we want a smaller font
        [self setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
    }
    return self;
}

// -------------------------------------------------------------------------------
//	copyWithZone:zone
// -------------------------------------------------------------------------------
- (id)copyWithZone:(NSZone *)zone
{
    PersonCell *cell = (PersonCell *)[super copyWithZone:zone];
    cell.personImage = self.personImage;
    return cell;
}

// -------------------------------------------------------------------------------
//	titleRectForBounds:cellRect
//
//	Returns the proper bound for the cell's title while being edited
// -------------------------------------------------------------------------------
- (NSRect)titleRectForBounds:(NSRect)cellRect
{
    // the cell has an image: draw the normal item cell
    NSSize imageSize;
    NSRect imageFrame;

    imageSize = [self.personImage size];
    NSDivideRect(cellRect, &imageFrame, &cellRect, 3 + imageSize.width, NSMinXEdge);

    imageFrame.origin.x += kImageOriginXOffset;
    imageFrame.origin.y -= kImageOriginYOffset;
    imageFrame.size = imageSize;

    imageFrame.origin.y += ceil((cellRect.size.height - imageFrame.size.height) / 2);

    NSRect newFrame = cellRect;
    newFrame.origin.x += kTextOriginXOffset;
    newFrame.origin.y += kTextOriginYOffset;
    newFrame.size.height -= kTextHeightAdjust;

    return newFrame;
}

// -------------------------------------------------------------------------------
//	editWithFrame:inView:editor:delegate:event
// -------------------------------------------------------------------------------
- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent
{
    NSRect textFrame = [self titleRectForBounds:aRect];
    [super editWithFrame:textFrame inView:controlView editor:textObj delegate:anObject event:theEvent];
}

// -------------------------------------------------------------------------------
//	selectWithFrame:inView:editor:delegate:event:start:length
// -------------------------------------------------------------------------------
- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength
{
    NSRect textFrame = [self titleRectForBounds:aRect];
    [super selectWithFrame:textFrame inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

// -------------------------------------------------------------------------------
//	drawWithFrame:cellFrame:controlView
// -------------------------------------------------------------------------------
- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    NSRect newCellFrame = cellFrame;

    if (self.personImage != nil)
    {
        NSSize imageSize;
        NSRect imageFrame;

        imageSize = [self.personImage size];
        NSDivideRect(newCellFrame, &imageFrame, &newCellFrame, imageSize.width, NSMinXEdge);
        if ([self drawsBackground])
        {
            [[self backgroundColor] set];
            NSRectFill(imageFrame);
        }

        imageFrame.origin.y += 2;
        imageFrame.size = imageSize;

        [self.personImage drawInRect:imageFrame
                        fromRect:NSZeroRect
                       operation:NSCompositeSourceOver
                        fraction:1.0
                  respectFlipped:YES
                           hints:nil];
    }

    [super drawWithFrame:newCellFrame inView:controlView];
}

- (NSRect)drawingRectForBounds:(NSRect)theRect
{
    // Get the parent's idea of where we should draw
    NSRect newRect = [super drawingRectForBounds:theRect];

    // When the text field is being
    // edited or selected, we have to turn off the magic because it screws up
    // the configuration of the field editor.  We sneak around this by
    // intercepting selectWithFrame and editWithFrame and sneaking a
    // reduced, centered rect in at the last minute.
    if (mIsEditingOrSelecting == NO)
    {
        // Get our ideal size for current text
        NSSize textSize = [self cellSizeForBounds:theRect];

        // Center that in the proposed rect
        float heightDelta = newRect.size.height - textSize.height;
        if (heightDelta > 0)
        {
            newRect.size.height -= heightDelta;
            newRect.origin.y += (heightDelta / 2);
        }
    }
    
    return newRect;
}

// -------------------------------------------------------------------------------
//	cellSize
// -------------------------------------------------------------------------------
- (NSSize)cellSize
{
    NSSize cellSize = [super cellSize];
    cellSize.width += (self.personImage ? [self.personImage size].width : 0) + 3;
    return cellSize;
}

@end
