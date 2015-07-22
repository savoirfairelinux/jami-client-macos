//
//  RingOutlineView.h
//  Ring
//
//  Created by Alexandre Lision on 2015-07-17.
//
//

#import <Cocoa/Cocoa.h>

@protocol ContextMenuDelegate;
@protocol ContextMenuDelegate

@required

- (NSMenu*) contextualMenuForIndex:(NSIndexPath*) path;

@end

@protocol KeyboardShortcutDelegate;
@protocol KeyboardShortcutDelegate

@optional

/**
 *  This shortcut has to respond to cmd (⌘) + a
 */
- (void) onAddShortcut;

@end

@interface RingOutlineView : NSOutlineView

@property (nonatomic,weak) id <ContextMenuDelegate>         contextMenuDelegate;
@property (nonatomic,weak) id <KeyboardShortcutDelegate>    shortcutsDelegate;

@end
