//
//  RSVerticallyCenteredTextFieldCell.h
//  RSCommon
//
//  Created by Daniel Jalkut on 6/17/06.
//  Copyright 2006 Red Sweater Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PersonCell : NSTextFieldCell
{
	BOOL mIsEditingOrSelecting;
}
@property (readwrite, strong) NSImage *personImage;
@end
