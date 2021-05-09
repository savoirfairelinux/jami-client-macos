//
//  PluginPreferenceTab.h
//  Jami
//
//  Created by jami on 2021-05-08.
//

#import <Cocoa/Cocoa.h>
#import "../PreferenceTabDelegateVC.h"

NS_ASSUME_NONNULL_BEGIN

@interface PluginPreferenceTab : NSTabViewItem

@property (unsafe_unretained) IBOutlet NSView *containerView;
@property PreferenceTabDelegateVC* viewController;

@end

NS_ASSUME_NONNULL_END
