//
//  ConversationsViewController.h
//  Ring
//
//  Created by Alexandre Lision on 2015-02-02.
//
//

#import <Cocoa/Cocoa.h>
#import "QNSTreeController.h"

@interface ConversationsViewController : NSViewController <NSOutlineViewDelegate> {
    NSOutlineView *conversationsView;
}

@property QNSTreeController *treeController;
@property (assign) IBOutlet NSOutlineView *conversationsView;

@end
