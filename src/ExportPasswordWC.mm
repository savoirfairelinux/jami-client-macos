/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
 *  Author: Alexandre Lision <alexandre.lision@savoirfairelinux.com>
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
#import "ExportPasswordWC.h"

//LRC
#import <api/lrc.h>
#import <api/newaccountmodel.h>
//#import <account.h>
#import <api/account.h>

//Ring
#import "views/ITProgressIndicator.h"
@interface ExportPasswordWC() <NSTextFieldDelegate>{
    __unsafe_unretained IBOutlet NSSecureTextField* passwordField;
    __unsafe_unretained IBOutlet NSTextField* resultField;
    __unsafe_unretained IBOutlet NSTextField* errorField;
    __unsafe_unretained IBOutlet ITProgressIndicator* progressIndicator;
}
@end

@implementation ExportPasswordWC {

}

@synthesize accountModel;
QMetaObject::Connection accountConnection;

-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil accountmodel:(lrc::api::NewAccountModel*) accountModel
{
    if (self =  [self initWithWindowNibName: nibNameOrNil])
    {
        self.accountModel= accountModel;
    }
    return self;
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

#pragma mark - Events Handlers
- (IBAction)completeAction:(id)sender
{
    NSString* password = passwordField.stringValue;
    [self showLoading];
    QObject::disconnect(accountConnection);
    accountConnection = QObject::connect(self.accountModel,
                                         &lrc::api::NewAccountModel::exportOnRingEnded,
                                         [self] (const std::string &accountID, lrc::api::account::ExportOnRingStatus status, const std::string &pin){
                                             if(accountID.compare(self.selectedAccountID) != 0) {
                                                 return;
                                             }
                                             switch (status) {
                                                 case lrc::api::account::ExportOnRingStatus::SUCCESS: {
                                                     NSString *nsPin = @(pin.c_str());
                                                     NSLog(@"Export ended with Success, pin is %@",nsPin);
                                                     [resultField setAttributedStringValue:[self formatPinMessage:nsPin]];
                                                     [self showFinal];
                                                 }
                                                     break;
                                                 case lrc::api::account::ExportOnRingStatus::WRONG_PASSWORD:{
                                                     NSLog(@"Export ended with wrong password");
                                                     [self showError:NSLocalizedString(@"The password you entered does not unlock this account", @"Error shown to the user" )];
                                                 }
                                                     break;
                                                 case lrc::api::account::ExportOnRingStatus::NETWORK_ERROR:{
                                                     NSLog(@"Export ended with NetworkError!");
                                                     [self showError:NSLocalizedString(@"A network error occured during the export", @"Error shown to the user" )];
                                                 }
                                                     break;
                                                 default:{
                                                     NSLog(@"Export ended with Unknown status!");
                                                     [self showError:NSLocalizedString(@"An error occured during the export", @"Error shown to the user" )];
                                                 }
                                                     break;
                                             }
                                              QObject::disconnect(accountConnection);
                                         });
    self.accountModel->exportOnRing(self.selectedAccountID, [password UTF8String]);
}

//TODO: Move String formatting to a dedicated Utility Classes
- (NSAttributedString*) formatPinMessage:(NSString*) pin
{
    NSMutableAttributedString* thePin = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"\n%@\n", pin]];
    [thePin beginEditing];
    NSRange range = NSMakeRange(0, [thePin length]);
    [thePin addAttribute:NSFontAttributeName value:[NSFont fontWithName:@"Helvetica-Bold" size:20.0] range:range];

    NSMutableParagraphStyle* mutParaStyle=[[NSMutableParagraphStyle alloc] init];
    [mutParaStyle setAlignment:NSCenterTextAlignment];

    [thePin addAttributes:[NSDictionary dictionaryWithObject:mutParaStyle forKey:NSParagraphStyleAttributeName] range:range];

    NSMutableAttributedString* infos = [[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"To complete the processs, you need to open Ring on the new device and choose the option \"Link this device to an account\". Your pin is valid for 10 minutes.","Title shown to user to concat with Pin")];
    [thePin appendAttributedString:infos];
    [thePin endEditing];

    return thePin;
}

@end
