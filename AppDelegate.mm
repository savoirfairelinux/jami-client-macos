#import "AppDelegate.h"


@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];

    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints"];

    NSMutableDictionary * states = [NSMutableDictionary dictionaryWithCapacity:2];
    [states setObject:[NSNumber numberWithBool:NO] forKey:@"enable_notifications"];
    [states setObject:[NSNumber numberWithBool:NO] forKey:@"window_behaviour"];

    self.ringWindowController = [[RingWindowController alloc] initWithWindowNibName:@"RingWindow"];
    [self.ringWindowController showWindow:nil];
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification{
    return YES;
}

@end
