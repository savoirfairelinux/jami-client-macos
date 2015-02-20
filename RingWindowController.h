//
//  RingWindowController.h
//  Ring
//
//  Created by Alexandre Lision on 2015-01-27.
//
//

#import <Cocoa/Cocoa.h>
#import "HistoryViewController.h"
#import "PreferencesViewController.h"

@interface RingWindowController : NSWindowController {
    IBOutlet NSView *currentView;
}
@property (nonatomic, assign) NSViewController *myCurrentViewController;
@property PreferencesViewController* preferencesViewController;

- (IBAction)openPreferences:(id)sender;
- (IBAction)closePreferences:(NSToolbarItem *)sender;

@end
