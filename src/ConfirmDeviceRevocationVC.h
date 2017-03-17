//
//  ConfirmDeviceRevocationVC.h
//  Ring
//
//  Created by Kateryna Kostiuk on 2017-03-15.
//
//
#import <Cocoa/Cocoa.h>
#import <account.h>
#import "AbstractLoadingWC.h"

@protocol ConfirmDeviceRevocationdDelegate <LoadingWCDelegate>

@optional
- (void)deviceRevocationComplitedWithSuccess;
- (void)didStartWithPassword:(NSString*) password;

@end
@interface ConfirmDeviceRevocationVC : AbstractLoadingWC

/**
 * password string contained in passwordField.
 * This is a KVO method to bind the text with the OK Button
 * if password.length is > 0, button is enabled, otherwise disabled
 */
@property (retain) NSString* password;
@property (assign) Account* account;
@property (retain) NSString* deviceID;

@end
