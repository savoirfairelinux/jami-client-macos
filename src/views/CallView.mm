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

#import "CallView.h"
#import "CallLayer.h"

#import <QUrl>

@interface CallView ()

@property NSMenu *contextualMenu;

@end

@implementation CallView
@synthesize contextualMenu;
@synthesize shouldAcceptInteractions;


- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
        [self setWantsLayer:YES];
        [self setLayer:[CALayer layer]];
        [self.layer setBackgroundColor:[[NSColor blackColor] CGColor]];
    }

    [self.window setAcceptsMouseMovedEvents:YES];

    NSTrackingAreaOptions options = (NSTrackingActiveAlways | NSTrackingInVisibleRect | NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved);

    NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:frame
                                                        options:options
                                                          owner:self
                                                       userInfo:nil];

    [self addTrackingArea:area];
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
    CFStringRef fileExtension = (__bridge CFStringRef) [fileURL.path pathExtension];
    CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, NULL);

    // Check if the pasteboard contains image data and source/user wants it copied
    if ( [sender draggingSourceOperationMask] & NSDragOperationCopy &&
        (UTTypeConformsTo(fileUTI, kUTTypeVideo)) ||
        (UTTypeConformsTo(fileUTI, kUTTypeMovie)) ||
        (UTTypeConformsTo(fileUTI, kUTTypeImage))) {

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
        CFRelease(fileUTI);
        //accept data as a copy operation
        return NSDragOperationCopy;
    }

    CFRelease(fileUTI);
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
    CFStringRef fileExtension = (__bridge CFStringRef) [fileURL.path pathExtension];
    CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, NULL);

    BOOL conforms = (UTTypeConformsTo(fileUTI, kUTTypeVideo)) ||
                    (UTTypeConformsTo(fileUTI, kUTTypeMovie)) ||
                    UTTypeConformsTo(fileUTI, kUTTypeImage);
    CFRelease(fileUTI);
    //check to see if we can accept the data
    return conforms;
}
#if 0
// TODO: add file as a source
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    /*------------------------------------------------------
     method that should handle the drop data
     --------------------------------------------------------*/
    if ( [sender draggingSource] != self ) {
        NSURL* fileURL = [NSURL URLFromPasteboard: [sender draggingPasteboard]];
        Call* call = [self getCurrentCall];
        if (call == nullptr) return;
        if (auto outVideo = call->firstMedia<media::Video>(media::Media::Direction::OUT)) {
            outVideo->sourceModel()->setFile(QUrl::fromLocalFile(QString::fromUtf8([fileURL.path UTF8String])));
            return YES;
        }
    }

    return NO;
}
#endif

- (void)showContextualMenu:(NSEvent *)theEvent {

    contextualMenu = [[NSMenu alloc] initWithTitle:@"Switch camera"];

    auto devices = [self.callDelegate getDeviceList];

    for(int i = 0 ; i < devices.size() ; ++i) {
        std::string device = devices[i];
        [contextualMenu insertItemWithTitle:@(device.c_str()) action:@selector(switchInput:) keyEquivalent:@"" atIndex:i];
    }
    [contextualMenu insertItemWithTitle:NSLocalizedString(@"Share screen", @"Contextual menu entry")
                                 action:@selector(captureScreen:)
                          keyEquivalent:@""
                                atIndex:contextualMenu.itemArray.count];
#if 0
// TODO: add file as a source
    [contextualMenu addItem:[NSMenuItem separatorItem]];
    [contextualMenu insertItemWithTitle:NSLocalizedString(@"Choose file", @"Contextual menu entry")
                                 action:@selector(chooseFile:)
                          keyEquivalent:@""
                                atIndex:contextualMenu.itemArray.count];
#endif

    [NSMenu popUpContextMenu:contextualMenu withEvent:theEvent forView:self];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self]; // cancel showContextualMenu
    [self performSelector:@selector(mouseIdle:) withObject:theEvent afterDelay:3];
    if (self.callDelegate && shouldAcceptInteractions)
        [self.callDelegate mouseIsMoving:YES];
}

- (void) mouseIdle:(NSEvent *)theEvent
{
    if (self.callDelegate && shouldAcceptInteractions)
        [self.callDelegate mouseIsMoving:NO];
}

- (void) rightMouseUp: (NSEvent*) theEvent {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    if([theEvent clickCount] == 1 && shouldAcceptInteractions) {
        [self performSelector:@selector(showContextualMenu:) withObject:theEvent];
    }
}

- (void)mouseUp:(NSEvent *)theEvent
{
    if([theEvent clickCount] == 2 && self.callDelegate) {
        [self.callDelegate callShouldToggleFullScreen];
    }
}

- (void) switchInput:(NSMenuItem*) sender
{
    int index = [contextualMenu indexOfItem:sender];
    [self.callDelegate switchToDevice: index];
}

- (void) captureScreen:(NSMenuItem*) sender
{
    [self.callDelegate screenShare];
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
    [fileTypes addObject:(__bridge NSString *)kUTTypeImage];
    [browsePanel setAllowedFileTypes:fileTypes];
    [browsePanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL*  theDoc = [[browsePanel URLs] objectAtIndex:0];
            [self.callDelegate switchToFile: [theDoc.path UTF8String]];
        }
    }];
}

@end
