#import <AppKit/NSApplication.h> // NSApplicationDelegate
#import "RingWindowController.h"
#import "PreferencesWindowController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property RingWindowController* ringWindowController;
@property PreferencesWindowController* preferencesWindowController;

+ (void)restoreWindowWithIdentifier:(NSString *)identifier
                                state:(NSCoder *)state
                                completionHandler:(void (^)(NSWindow *, NSError *))completionHandler;

@end
