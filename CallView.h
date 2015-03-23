//
//  CallView.h
//  Ring
//
//  Created by Alexandre Lision on 2015-03-22.
//
//

#import <Cocoa/Cocoa.h>

@interface CallView : NSImageView <NSDraggingDestination>
{
    //highlight the drop zone
    BOOL highlight;
}

- (id)initWithCoder:(NSCoder *)coder;

@end
