#import "AppDelegate.h"


@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints"];

    self.ringWindowController = [[RingWindowController alloc] initWithWindowNibName:@"RingWindow"];
    [self.ringWindowController showWindow:nil];
}

@end
