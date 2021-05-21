//
//  ChooseMediaVC.h
//  Jami
//
//  Created by kateryna on 2021-05-19.
//

#import <Cocoa/Cocoa.h>
#import <qstring.h>
#import <qvector.h>

NS_ASSUME_NONNULL_BEGIN

@interface ChooseMediaVC: NSViewController<NSTableViewDelegate, NSTableViewDataSource>
@property (copy) void (^onDeviceSelected)(NSString* device);

-(void)setMediaDevices:(const QVector<QString>&)devices andDefaultDevice:(const QString&)device;
@end

NS_ASSUME_NONNULL_END
