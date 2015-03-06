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
#import <video/manager.h>
#import <QtCore/qitemselectionmodel.h>
#include <video/renderer.h>

#import "CurrentCallVC.h"

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#define COLUMNID_CONVERSATIONS @"ConversationsColumn"	// the single column name in our outline view

@interface ConversationsViewController ()

@property CurrentCallVC* currentVC;
@property (assign) IBOutlet NSView *currentCallView;
@property (assign) IBOutlet NSTextField *callBar;
@property CALayer *customPreviewLayer;

@end

@implementation ConversationsViewController
@synthesize conversationsView;
@synthesize treeController;
@synthesize currentVC;
@synthesize currentCallView;
@synthesize callBar;
@synthesize customPreviewLayer;

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


    // NOW THE VIDEO VIEW
    customPreviewLayer = [CALayer layer];
    customPreviewLayer.bounds = CGRectMake(0, 0, currentCallView.frame.size.height, currentCallView.frame.size.width);
    customPreviewLayer.position = CGPointMake(currentCallView.frame.size.width/2., currentCallView.frame.size.height/2.);
    //customPreviewLayer.affineTransform = CGAffineTransformMakeRotation(M_PI/2);
    customPreviewLayer.backgroundColor = [NSColor redColor].CGColor;
    [currentCallView.layer addSublayer:customPreviewLayer];

}

- (IBAction)placeCall:(id)sender {

    Call* c = CallModel::instance()->dialingCall();
    c->setDialNumber(QString::fromNSString([callBar stringValue]));
    c << Call::Action::ACCEPT;
}
- (IBAction)startPreview:(id)sender {
    Video::Manager::instance()->startPreview();
    Video::Renderer* rend = Video::Manager::instance()->previewRenderer();
    QObject::connect(
                     rend,
                     &Video::Renderer::frameUpdated,
                    [=]() {

                        NSLog(@"We have a frame!");
                        const QByteArray& data = Video::Manager::instance()->previewRenderer()->currentFrame();
                        QSize res = Video::Manager::instance()->previewRenderer()->size();
                        CVPixelBufferRef imageBuffer = NULL;
                        CVPixelBufferCreateWithBytes(NULL,
                                                     res.width(),
                                                     res.height(),
                                                     k32BGRAPixelFormat,
                                                     (void*)data.constData(),
                                                     4 * res.width(),
                                                     NULL,
                                                     0,
                                                     NULL,
                                                     &imageBuffer);


                        CMVideoFormatDescriptionRef format = NULL;
                        CMVideoFormatDescriptionCreateForImageBuffer(NULL, imageBuffer, &format);


                        CMSampleTimingInfo timingInfo;
                        timingInfo.presentationTimeStamp = CMTimeMake(1, 30);
                        CMSampleBufferRef bufOut = NULL;
                        CGContextRef context = CGBitmapContextCreate(NULL, res.width(), res.height(), 8, 0, CGColorSpaceCreateDeviceRGB(), kCGImageAlphaPremultipliedLast);

                        OSStatus result;
                        result = CMSampleBufferCreateForImageBuffer (NULL, imageBuffer, YES, NULL, 0, format, &timingInfo, &bufOut);

                        if([NSThread isMainThread])
                            customPreviewLayer.contents = (__bridge id)bufOut;
                        else
                            dispatch_sync(dispatch_get_main_queue(), ^{
                                customPreviewLayer.contents = (__bridge id)bufOut;
                            });
                });
}
- (IBAction)stopPreview:(id)sender {
    Video::Manager::instance()->stopPreview();
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
