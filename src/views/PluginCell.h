//
//  PluginCell.h
//  Jami
//
//  Created by jami on 2021-05-07.
//

#import <Cocoa/Cocoa.h>
#import "../PluginItemDelegateVC.h"

NS_ASSUME_NONNULL_BEGIN

@interface PluginCell : NSTableCellView

@property (unsafe_unretained) IBOutlet NSView *containerView;
@property PluginItemDelegateVC* viewController;

@end

NS_ASSUME_NONNULL_END
