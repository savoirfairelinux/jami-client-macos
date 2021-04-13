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

#import "DraggingDestinationView.h"

@implementation DraggingDestinationView
- (id)initWithFrame:(NSRect)frame
{
    if (self = [super initWithFrame: frame])
        [self registerForDraggedTypes:[NSArray arrayWithObjects: NSPasteboardTypeURL, nil]];
    return self;
}

-(void)drawRect:(NSRect)rect
{
    [super drawRect:rect];

    if (highlight) {
        [[[NSColor blackColor] colorWithAlphaComponent:0.8] set];
        [NSBezierPath fillRect: rect];
    }

    NSRect rectText = rect;
    NSDictionary *attributes = nil;

    NSString *title = highlight ?
    NSLocalizedString(@"Drop files to send", @"drop files") : @"";
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [style setLineBreakMode:NSLineBreakByWordWrapping];
    [style setAlignment:NSCenterTextAlignment];
    NSFont *font= [NSFont systemFontOfSize: 32 weight: NSFontWeightSemibold];
    attributes = [[NSDictionary alloc] initWithObjectsAndKeys:
                  style, NSParagraphStyleAttributeName,
                  font,NSFontAttributeName,
                  [NSColor whiteColor],
                  NSForegroundColorAttributeName, nil];
    rectText.size = [title sizeWithAttributes: attributes];
    rectText.origin.x = floor( NSMidX(rect) - rectText.size.width / 2);
    rectText.origin.y = floor( NSMidY([self bounds]) - rectText.size.height / 2 );
    [title drawInRect:rectText withAttributes: attributes];
}

#pragma mark - Destination Operations

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    highlight = true;
    [self setNeedsDisplay: true];
    return NSDragOperationCopy;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
    highlight = false;
    [self setNeedsDisplay: true];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    highlight = false;
    [self setNeedsDisplay: true];
    return true;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    NSArray *classArray = [NSArray arrayWithObject:[NSURL class]];
    NSArray *arrayOfURLs = [[sender draggingPasteboard] readObjectsForClasses:classArray options:nil];
    [self.draggingDestinationDelegate filesDragged: arrayOfURLs];
    return true;
}

@end
