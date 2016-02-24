//
//  TransferCellView.h
//  Ring
//
//  Created by Alexandre Lision on 22/02/16.
//
//

#import <Cocoa/Cocoa.h>

@interface TransferCellView : NSTableCellView

@property (nonatomic, weak) IBOutlet NSTextField* fileName;
@property (nonatomic, weak) IBOutlet NSTextField* status;
@property (nonatomic, weak) IBOutlet NSProgressIndicator* progressBar;
@property (nonatomic, weak) IBOutlet NSButton* acceptButton;
@property (nonatomic, weak) IBOutlet NSButton* refuseButton;


@end
