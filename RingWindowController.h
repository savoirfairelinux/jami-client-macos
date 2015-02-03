//
//  RingWindowController.h
//  Ring
//
//  Created by Alexandre Lision on 2015-01-27.
//
//

#import <Cocoa/Cocoa.h>
#import "HistoryViewController.h"

@interface RingWindowController : NSWindowController {
    NSTextField *callUriTextField;

}

@property (assign) IBOutlet NSTextField *callUriTextField;

- (IBAction)placeCall:(NSButton *)sender;


@end
