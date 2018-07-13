//
//  AddSIPAccountVC.h
//  Ring
//
//  Created by Kateryna Kostiuk on 2018-07-26.
//

#import <Cocoa/Cocoa.h>
#import "LrcModelsSProtocol.h"

@protocol AddSIPAccountDelegate <NSObject>
- (void)done;
- (void)showView:(NSView*)view;
@end

@interface AddSIPAccountVC : NSViewController <LrcModelsSProtocol>
@property (nonatomic, weak) NSWindowController <AddSIPAccountDelegate>* delegate;
- (void)show;

@end
