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

#import "CallView.h"

#import <QItemSelectionModel>
#import <QAbstractProxyModel>
#import <QUrl>

#import <video/configurationproxy.h>
#import <video/sourcemodel.h>
#import <video/previewmanager.h>
#import <video/renderer.h>
#import <video/device.h>
#import <video/devicemodel.h>

@interface CallView ()

@property NSMenu *contextualMenu;

@end

@implementation CallView
@synthesize contextualMenu;


- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
    }
    return self;
}


#pragma mark - Destination Operations

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    /*------------------------------------------------------
     method called whenever a drag enters our drop zone
     --------------------------------------------------------*/
    NSLog(@"Dragging entered");

    NSURL* fileURL = [NSURL URLFromPasteboard: [sender draggingPasteboard]];
    CFStringRef fileExtension = (CFStringRef) [fileURL.path pathExtension];
    CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, NULL);

    // Check if the pasteboard contains image data and source/user wants it copied
    if ( [sender draggingSourceOperationMask] & NSDragOperationCopy &&
        (UTTypeConformsTo(fileUTI, kUTTypeImage)) || (UTTypeConformsTo(fileUTI, kUTTypeMovie))) {

        //highlight our drop zone
        highlight=YES;

        [self setNeedsDisplay: YES];

        /* When an image from one window is dragged over another, we want to resize the dragging item to
         * preview the size of the image as it would appear if the user dropped it in. */
        [sender enumerateDraggingItemsWithOptions:NSDraggingItemEnumerationConcurrent
                                          forView:self
                                          classes:[NSArray arrayWithObject:[NSPasteboardItem class]]
                                    searchOptions:nil
                                       usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop) {
                                           *stop = YES;
                                       }];

        //accept data as a copy operation
        return NSDragOperationCopy;
    }

    return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
    /*------------------------------------------------------
     method called whenever a drag exits our drop zone
     --------------------------------------------------------*/
    //remove highlight of the drop zone
    highlight=NO;

    [self setNeedsDisplay: YES];
}

-(void)drawRect:(NSRect)rect
{
    /*------------------------------------------------------
     draw method is overridden to do drop highlighing
     --------------------------------------------------------*/
    //do the usual draw operation to display the image
    [super drawRect:rect];

    if ( highlight ) {
        //highlight by overlaying a gray border
        [[NSColor blueColor] set];
        [NSBezierPath setDefaultLineWidth: 5];
        [NSBezierPath strokeRect: rect];
    }
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    /*------------------------------------------------------
     method to determine if we can accept the drop
     --------------------------------------------------------*/
    //finished with the drag so remove any highlighting
    highlight=NO;

    [self setNeedsDisplay: YES];

    NSURL* fileURL = [NSURL URLFromPasteboard: [sender draggingPasteboard]];
    CFStringRef fileExtension = (CFStringRef) [fileURL.path pathExtension];
    CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, NULL);

    //check to see if we can accept the data
    return (UTTypeConformsTo(fileUTI, kUTTypeImage)) || (UTTypeConformsTo(fileUTI, kUTTypeMovie));
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    /*------------------------------------------------------
     method that should handle the drop data
     --------------------------------------------------------*/
    if ( [sender draggingSource] != self ) {
        NSURL* fileURL = [NSURL URLFromPasteboard: [sender draggingPasteboard]];
        Video::SourceModel::instance()->setFile(QUrl::fromLocalFile(QString::fromUtf8([fileURL.path UTF8String])));
    }

    return YES;
}

- (void)mouseDown:(NSEvent *)theEvent {

    contextualMenu = [[NSMenu alloc] initWithTitle:@"Switch camera"];

    for(int i = 0 ; i < Video::DeviceModel::instance()->devices().size() ; ++i) {
        Video::Device* device = Video::DeviceModel::instance()->devices()[i];
        [contextualMenu insertItemWithTitle:device->name().toNSString() action:@selector(switchInput:) keyEquivalent:@"" atIndex:i];
    }

    [contextualMenu addItem:[NSMenuItem separatorItem]];
    [contextualMenu insertItemWithTitle:@"Choose file" action:@selector(chooseFile:) keyEquivalent:@"" atIndex:contextualMenu.itemArray.count];

    [NSMenu popUpContextMenu:contextualMenu withEvent:theEvent forView:self];
}

- (void) switchInput:(NSMenuItem*) sender
{
    int index = [contextualMenu indexOfItem:sender];
    Video::SourceModel::instance()->switchTo(Video::DeviceModel::instance()->devices()[index]);
}

- (void) chooseFile:(NSMenuItem*) sender
{
    NSOpenPanel *browsePanel = [[NSOpenPanel alloc] init];
    [browsePanel setDirectoryURL:[NSURL URLWithString:NSHomeDirectory()]];
    [browsePanel setCanChooseFiles:YES];
    [browsePanel setCanChooseDirectories:NO];
    [browsePanel setCanCreateDirectories:NO];

    NSMutableArray* fileTypes = [[NSMutableArray alloc] initWithArray:[NSImage imageTypes]];
    [fileTypes addObject:(__bridge NSString *)kUTTypeVideo];
    [fileTypes addObject:(__bridge NSString *)kUTTypeMovie];
    [browsePanel setAllowedFileTypes:fileTypes];

    [browsePanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL*  theDoc = [[browsePanel URLs] objectAtIndex:0];
            Video::SourceModel::instance()->setFile(QUrl::fromLocalFile(QString::fromUtf8([theDoc.path UTF8String])));
        }
    }];

}

@end
