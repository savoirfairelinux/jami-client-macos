/************************************************************************************
 *   Copyright (C) 2014-2015 by Savoir-Faire Linux                                  *
 *   Author : Alexandre Lision <alexandre.lision@savoirfairelinux.com>              *
 *                                                                                  *
 *   This library is free software; you can redistribute it and/or                  *
 *   modify it under the terms of the GNU Lesser General Public                     *
 *   License as published by the Free Software Foundation; either                   *
 *   version 2.1 of the License, or (at your option) any later version.             *
 *                                                                                  *
 *   This library is distributed in the hope that it will be useful,                *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of                 *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU              *
 *   Lesser General Public License for more details.                                *
 *                                                                                  *
 *   You should have received a copy of the GNU Lesser General Public               *
 *   License along with this library; if not, write to the Free Software            *
 *   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA *
 ***********************************************************************************/
#import "ConversationsViewController.h"

#import <callmodel.h>
#import <QtCore/qitemselectionmodel.h>
#import <video/previewmanager.h>
#include <video/renderer.h>


#import "CurrentCallVC.h"

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#define COLUMNID_CONVERSATIONS @"ConversationsColumn"	// the single column name in our outline view

@interface ConversationsViewController ()

@property CurrentCallVC* currentVC;
@property (assign) IBOutlet NSView *currentCallView;
@property (assign) IBOutlet NSTextField *callBar;
@end

@implementation ConversationsViewController
@synthesize conversationsView;
@synthesize treeController;
@synthesize currentVC;
@synthesize currentCallView;
@synthesize callBar;

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        NSLog(@"INIT Conversations VC");
    }

    [self connectSlots];
    return self;
}

- (void) connectSlots
{
    QObject::connect(CallModel::instance(), &CallModel::incomingCall, [self] (Call* c) {
        [currentVC displayCall:c];
    });
}

- (void)awakeFromNib
{
    NSLog(@"awakeFromNib");

    treeController = [[QNSTreeController alloc] initWithQModel:CallModel::instance()];

    [treeController setAvoidsEmptySelection:NO];
    [treeController setChildrenKeyPath:@"children"];

    [self.conversationsView bind:@"content" toObject:treeController withKeyPath:@"arrangedObjects" options:nil];
    [self.conversationsView bind:@"sortDescriptors" toObject:treeController withKeyPath:@"sortDescriptors" options:nil];
    [self.conversationsView bind:@"selectionIndexPaths" toObject:treeController withKeyPath:@"selectionIndexPaths" options:nil];

    NSInteger idx = [conversationsView columnWithIdentifier:COLUMNID_CONVERSATIONS];
    [[[[self.conversationsView tableColumns] objectAtIndex:idx] headerCell] setStringValue:@"Conversations"];

    CALayer *viewLayer = [CALayer layer];
    [currentCallView setWantsLayer:YES]; // view's backing store is using a Core Animation Layer

    // NOW THE CURRENT CALL VIEW
    currentVC = [[CurrentCallVC alloc] initWithNibName:@"CurrentCall" bundle:nil];
    [currentCallView addSubview:[self.currentVC view]];
    currentCallView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.currentVC initFrame];

}

- (IBAction)placeCall:(id)sender {

    Call* c = CallModel::instance()->dialingCall();
    c->setDialNumber(QString::fromNSString([callBar stringValue]));
    c << Call::Action::ACCEPT;
}

- (IBAction)startPreview:(id)sender {
    Video::PreviewManager::instance()->startPreview();
    Video::Renderer* rend = Video::PreviewManager::instance()->previewRenderer();
    QObject::connect(rend,
                     &Video::Renderer::frameUpdated,
                     [=]() {

                         const QByteArray& data = Video::PreviewManager::instance()->previewRenderer()->currentFrame();
                         QSize res = Video::PreviewManager::instance()->previewRenderer()->size();

                         NSLog(@"We have a frame! w: %d h: %d", res.width(), res.height());

                         auto buf = reinterpret_cast<const unsigned char*>(data.data());
                         NSLog(@"We have a frame! 0: %u 1: %u 2: %u 3: %u", buf[0], buf[1], buf[2], buf[3]);

                         int bytes = res.height() * 4 * res.width();
                         uint8_t *baseAddress = (uint8_t*) malloc(bytes);
                         memcpy(baseAddress,buf,bytes);

                         /*Create a CGImageRef from the CVImageBufferRef*/
                         const CGFloat whitePoint[] = {0.3127, 0.3290, 0.3583};
                         const CGFloat blackPoint[] = {0, 0, 0};
                         const CGFloat gamma[] = {1, 1, 1};

                         // 3*3 matrix, columns first (x,x,x,y,y,y,z,z,z)
                         const CGFloat matrix[] = {  1.1301350511386112, 0.060066677968017186, 5.5941685031361255,
                             1.7517093292648473, 4.590608577725039   , 0.05650675255693056,
                             2.768830875289597 , 1.0                 , 0.0 };


                         CGColorSpaceRef colorSpace = CGColorSpaceCreateCalibratedRGB(whitePoint, blackPoint, gamma, matrix);

                         CGContextRef newContext = CGBitmapContextCreate(baseAddress,
                                                                         res.width(),
                                                                         res.height(),
                                                                         8,
                                                                         4*res.width(),
                                                                         colorSpace,
                                                                         kCGImageAlphaPremultipliedLast);


                         CGImageRef newImage = CGBitmapContextCreateImage(newContext);

                         /*We release some components*/
                         CGContextRelease(newContext);
                         CGColorSpaceRelease(colorSpace);

                         //NSLog(@"content center x %f, y %f", videoLayer.contentsRect.origin.x, videoLayer.contentsRect.origin.y);
                         //NSLog(@"content size: w %f, h %f", videoLayer.contentsRect.size.width, videoLayer.contentsRect.size.height);
                         
                         //videoLayer.contents = (__bridge id)newImage;
                         free(baseAddress);
                     });
}

- (IBAction)stopPreview:(id)sender {
    Video::PreviewManager::instance()->stopPreview();
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
    if([[treeController selectedNodes] count] > 0) {
        QModelIndex qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
        //Update details view
        Call* toDisplay = CallModel::instance()->getCall(qIdx);

        CallModel::instance()->selectionModel()->setCurrentIndex(qIdx, QItemSelectionModel::ClearAndSelect);
        [currentVC displayCall:toDisplay];
    } else {
        [currentVC hideWithAnimation:YES];
        CallModel::instance()->selectionModel()->clearCurrentIndex();
    }
}


@end
