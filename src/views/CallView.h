//
//  CallView.h
//  Ring
//
//  Created by Alexandre Lision on 2015-03-26.
//
//

#import <Cocoa/Cocoa.h>

@interface CallView : NSView <NSDraggingDestination, NSOpenSavePanelDelegate>
{
    //highlight the drop zone
    BOOL highlight;
}

- (id)initWithCoder:(NSCoder *)coder;

/**
 * Sets weither this view allow first click interactions
 */
@property BOOL shouldAcceptInteractions;

@end
