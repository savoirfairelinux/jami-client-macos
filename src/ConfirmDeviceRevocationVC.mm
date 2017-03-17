//
//  ConfirmDeviceRevocationVC.m
//  Ring
//
//  Created by Kateryna Kostiuk on 2017-03-15.
//
//

#import "ConfirmDeviceRevocationVC.h"

//LRC
#import <account.h>

//Ring
#import "views/ITProgressIndicator.h"

@interface ConfirmDeviceRevocationVC() <NSTextFieldDelegate>{
    __unsafe_unretained IBOutlet NSSecureTextField* passwordField;
    __unsafe_unretained IBOutlet NSTextField* resultField;
    __unsafe_unretained IBOutlet NSTextField* errorField;
    __unsafe_unretained IBOutlet ITProgressIndicator* progressIndicator;
    __unsafe_unretained IBOutlet NSTextField* deviceIDTextField;
}
@end

@implementation ConfirmDeviceRevocationVC {
    struct {
        unsigned int didStart:1;
        unsigned int didComplete:1;
    } delegateRespondsTo;
}

@synthesize account;

#pragma mark - Initialize
- (id)initWithDelegate:(id <ConfirmDeviceRevocationdDelegate>) del actionCode:(NSInteger) code
{
    return [super initWithWindowNibName:@"ConfirmDeviceRevocation" delegate:del actionCode:code];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [deviceIDTextField setStringValue:_deviceID];

}

- (void)setDelegate:(id <ConfirmDeviceRevocationdDelegate>)aDelegate
{
    if (super.delegate != aDelegate) {
        [super setDelegate: aDelegate];
        delegateRespondsTo.didStart = [aDelegate respondsToSelector:@selector(didStartWithPassword:)];
        delegateRespondsTo.didComplete = [aDelegate respondsToSelector:@selector(didCompleteWithPin:Password:)];
    }
}

- (void)showError:(NSString*) errorMessage
{
    [errorField setStringValue:errorMessage];
    [super showError];
}

- (void)showLoading
{
    [progressIndicator setNumberOfLines:30];
    [progressIndicator setWidthOfLine:2];
    [progressIndicator setLengthOfLine:5];
    [progressIndicator setInnerMargin:20];
    [super showLoading];
}

- (void)showFinal
{
    [resultField setStringValue:NSLocalizedString(@"Device is now revoked", @"Text shown to user when revice revoked with success" )];
    [super showFinal];
}



#pragma mark - Events Handlers
- (IBAction)completeAction:(id)sender
{
//        [self showLoading];
//        NSString* password = passwordField.stringValue;
//        NSString* accountID = account->username().toNSString();
//        account->revokeDevice(QString::fromNSString(password), accountID, self.deviceID);

}




@end
