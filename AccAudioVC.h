//
//  AccAudioVC.h
//  Ring
//
//  Created by Alexandre Lision on 2015-02-25.
//
//

#import <Cocoa/Cocoa.h>

#import "QNSTreeController.h"

@interface AccAudioVC : NSViewController <NSOutlineViewDelegate> {


    NSOutlineView *codecsView;
}

@property QNSTreeController *treeController;
@property (assign) IBOutlet NSOutlineView *codecsView;

@end
