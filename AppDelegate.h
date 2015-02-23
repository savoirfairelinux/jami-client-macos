#import <AppKit/NSApplication.h> // NSApplicationDelegate
#import "RingWindowController.h"
#import "PreferencesWindowController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSUserNotificationCenterDelegate>

@property RingWindowController* ringWindowController;

@end
