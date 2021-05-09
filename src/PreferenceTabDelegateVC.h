//
//  PreferenceTabDelegateVC.h
//  Jami
//
//  Created by jami on 2021-05-08.
//

#import <Cocoa/Cocoa.h>
#include <qstring.h>
#import "LrcModelsProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface PreferenceTabDelegateVC : NSViewController<LrcModelsProtocol, NSTableViewDataSource, NSTableViewDelegate> {}

- (void) setup:(QString)pluginName category:(QString)category;
- (void) update;
@end

NS_ASSUME_NONNULL_END
