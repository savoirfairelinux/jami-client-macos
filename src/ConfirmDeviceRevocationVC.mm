/*
 *  Copyright (C) 2015-2017 Savoir-faire Linux Inc.
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

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

}

@end
