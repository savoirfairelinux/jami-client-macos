//
//  ChatVC.h
//  Ring
//
//  Created by Alexandre Lision on 2015-06-04.
//
//

#import <Cocoa/Cocoa.h>

@interface ChatVC : NSViewController <NSTextFieldDelegate>

/**
 * Message contained in messageField TextField.
 * This is a KVO method to bind the text with the send Button
 * if message.length is > 0, button is enabled, otherwise disabled
 */
@property (retain) NSString* message;

@end
