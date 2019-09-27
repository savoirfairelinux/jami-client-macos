//
//  RecordFileVC.h
//  Jami
//
//  Created by kate on 2019-09-27.
//

#import <Cocoa/Cocoa.h>
#import "LrcModelsProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@protocol RecordingViewDelegate <NSObject>
-(void) closeRecordingView;
@end

@interface RecordFileVC : NSViewController <LrcModelsProtocol>
@property (retain, nonatomic) id <RecordingViewDelegate> delegate;

-(void) stopMedia;

@end

NS_ASSUME_NONNULL_END
