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
#import "ConversationsViewController.h"

#import <QuartzCore/QuartzCore.h>

#import <callmodel.h>
#include <cstdlib>

#import <video/previewmanager.h>
#include <video/renderer.h>

#define COLUMNID_CONVERSATIONS @"ConversationsColumn"	// the single column name in our outline view

@interface ConversationsViewController ()
@property (assign) IBOutlet NSView *previewView;
@property CALayer *videoLayer;
@property CGImageRef newImage;

@end

@implementation ConversationsViewController
@synthesize previewView;
@synthesize conversationsView;
@synthesize treeController;
@synthesize videoLayer;
@synthesize newImage;


- (IBAction)startPreview:(id)sender {
    Video::PreviewManager::instance()->startPreview();
    Video::Renderer* rend = Video::PreviewManager::instance()->previewRenderer();
    QObject::connect(rend,
                     &Video::Renderer::frameUpdated,
                     [=]() {

                         const QByteArray& data = Video::PreviewManager::instance()->previewRenderer()->currentFrame();
                         QSize res = Video::PreviewManager::instance()->previewRenderer()->size();

                         //NSLog(@"We have a frame! w: %d h: %d", res.width(), res.height());

                         auto buf = reinterpret_cast<const unsigned char*>(data.data());
                         //NSLog(@"First pix 0: %u 1: %u 2: %u 3: %u", buf[0], buf[1], buf[2], buf[3]);
                         //NSLog(@"Second pix 0: %u 1: %u 2: %u 3: %u", buf[4], buf[5], buf[6], buf[7]);

                         /*Create a CGImageRef from the CVImageBufferRef*/
                         const CGFloat whitePoint[] = {0.3127, 0.3290, 1.0000};
                         const CGFloat blackPoint[] = {0, 0, 0};
                         const CGFloat gamma[] = {1, 1, 1};

                         // 3*3 matrix, columns first (x,x,x,y,y,y,z,z,z)
                         const CGFloat matrix[] = {0.4124564,  0.2126729,  0.0193339 ,
                              0.3575761, 0.7151522 ,0.1191920 ,
                              0.1804375, 0.0721750 ,  0.9503041};


                         CGColorSpaceRef colorSpace = CGColorSpaceCreateCalibratedRGB(whitePoint, blackPoint, gamma, matrix);

                         CGContextRef newContext = CGBitmapContextCreate((void *)buf,
                                                                         res.width(),
                                                                         res.height(),
                                                                         8,
                                                                         4*res.width(),
                                                                         colorSpace,
                                                                         kCGImageAlphaPremultipliedLast);


                         newImage = CGBitmapContextCreateImage(newContext);

                         /*We release some components*/
                         CGContextRelease(newContext);
                         CGColorSpaceRelease(colorSpace);

                         //NSLog(@"content center x %f, y %f", videoLayer.contentsRect.origin.x, videoLayer.contentsRect.origin.y);
                         //NSLog(@"content size: w %f, h %f", videoLayer.contentsRect.size.width, videoLayer.contentsRect.size.height);
                         [CATransaction begin];
                         videoLayer.contents = (__bridge id)newImage;
                         [CATransaction commit];

                         CFRelease(newImage);
                     });
}
- (IBAction)stopPreview:(id)sender {
    Video::PreviewManager::instance()->stopPreview();
}

- (void)awakeFromNib
{
    NSLog(@"awakeFromNib Conversation");

    videoLayer = [CALayer layer];
    [previewView setWantsLayer:YES]; // view's backing store is using a Core Animation Layer
    [previewView setLayer:videoLayer];

    [videoLayer setFrame:previewView.frame];
    videoLayer.bounds = CGRectMake(0, 0, previewView.frame.size.height, previewView.frame.size.width);
    videoLayer.backgroundColor = [NSColor whiteColor].CGColor;

}

#pragma mark - NSOutlineViewDelegate methods

// -------------------------------------------------------------------------------
//	shouldSelectItem:item
// -------------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item;
{
    return YES;
}

// -------------------------------------------------------------------------------
//	dataCellForTableColumn:tableColumn:item
// -------------------------------------------------------------------------------
- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    NSCell *returnCell = [tableColumn dataCell];


    if(item == nil)
        return returnCell;
    if ([[tableColumn identifier] isEqualToString:COLUMNID_CONVERSATIONS])
    {

        NSIndexPath* idx = ((NSTreeNode*)item).indexPath;
        NSUInteger myArray[[idx length]];
        [idx getIndexes:myArray];

        NSLog(@"dataCellForTableColumn, indexPath: %lu", (unsigned long)myArray[0]);

        QModelIndex qIdx = CallModel::instance()->index(myArray[0], 0);

        QVariant test = CallModel::instance()->data(qIdx, Qt::DisplayRole);
    }

    return returnCell;
}

// -------------------------------------------------------------------------------
//	textShouldEndEditing:fieldEditor
// -------------------------------------------------------------------------------
- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
    if ([[fieldEditor string] length] == 0)
    {
        // don't allow empty node names
        return NO;
    }
    else
    {
        return YES;
    }
}

// -------------------------------------------------------------------------------
//	shouldEditTableColumn:tableColumn:item
//
//	Decide to allow the edit of the given outline view "item".
// -------------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    return NO;
}

// -------------------------------------------------------------------------------
//	outlineView:willDisplayCell:forTableColumn:item
// -------------------------------------------------------------------------------
- (void)outlineView:(NSOutlineView *)olv willDisplayCell:(NSCell*)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    if ([[tableColumn identifier] isEqualToString:COLUMNID_CONVERSATIONS])
    {
        QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
        if(qIdx.isValid())
            cell.title = CallModel::instance()->data(qIdx, Qt::DisplayRole).toString().toNSString();
    }
}

// -------------------------------------------------------------------------------
//	outlineViewSelectionDidChange:notification
// -------------------------------------------------------------------------------
- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    // ask the tree controller for the current selection
    NSLog(@"outlineViewSelectionDidChange!!");
}


@end
