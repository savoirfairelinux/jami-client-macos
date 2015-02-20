//
//  PreferenceWindowController.h
//  Ring
//
//  Created by Alexandre Lision on 2015-02-03.
//
//

#import <Cocoa/Cocoa.h>

@interface PreferencesViewController : NSViewController <NSToolbarDelegate>

- (void) close;
@property (nonatomic, assign) NSViewController *currentVC;
@property (nonatomic, assign) NSViewController *generalPrefsVC;
@property (nonatomic, assign) NSViewController *audioPrefsVC;
@property (nonatomic, assign) NSViewController *videoPrefsVC;

- (void)displayGeneral:(NSToolbarItem *)sender;
- (void)displayAudio:(NSToolbarItem *)sender;
- (void)displayAncrage:(NSToolbarItem *)sender;
- (void)displayVideo:(NSToolbarItem *)sender;

@end


