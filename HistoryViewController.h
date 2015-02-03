//
//  HistoryViewController.h
//  Ring
//
//  Created by Alexandre Lision on 2015-01-28.
//
//

#import <Cocoa/Cocoa.h>
#import "QNSTreeController.h"


@interface HistoryViewController : NSViewController <NSOutlineViewDelegate> {

    NSOutlineView *historyView;
}

@property NSTreeController *treeController;
@property (assign) IBOutlet NSOutlineView *historyView;

@end
