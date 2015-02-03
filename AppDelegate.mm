#import "AppDelegate.h"


@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.ringWindowController = [[RingWindowController alloc] initWithWindowNibName:@"RingWindow"];
    [self.ringWindowController showWindow:nil];
}

- (PreferencesWindowController *)preferencesWindowController
{
    if (!_preferencesWindowController)
    {
        NSLog(@"Coucou");
        _preferencesWindowController = [[PreferencesWindowController alloc] initWithWindowNibName:@"PreferencesWindow"];
        _preferencesWindowController.window.restorable = YES;
        _preferencesWindowController.window.restorationClass = [self class];
        _preferencesWindowController.window.identifier = @"preferences";
    }
    return _preferencesWindowController;
}

- (IBAction)launchPreferencesWindow:(id)sender {
    [[self preferencesWindowController] showWindow:nil];
}

+ (void)restoreWindowWithIdentifier:(NSString *)identifier
                              state:(NSCoder *)state
                  completionHandler:(void (^)(NSWindow *, NSError *))completionHandler
{
    NSLog(@"restoreWindowWithIdentifier: %@", identifier);
    NSWindow *window = nil;
    if ([identifier isEqualToString:@"preferences"])
    {
        AppDelegate *appDelegate = [NSApp delegate];
        window = [[appDelegate preferencesWindowController] window];
    }
    completionHandler(window, nil);
}

@end
