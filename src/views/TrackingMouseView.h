//
//  TrackingMouseView.h
//  Jami
//
//  Created by kateryna on 2021-06-01.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TrackingMouseViewDelegate
-(void)mouseExited;
@end

@interface TrackingMouseView : NSView {
@private
    NSTrackingArea *trackingArea;
}

- (void)subscribeForMouceMovement:(BOOL)subscribe;
@property (retain, nonatomic) id <TrackingMouseViewDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
