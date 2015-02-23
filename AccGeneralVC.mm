/************************************************************************************
 *   Copyright (C) 2014-2015 by Savoir-Faire Linux                                  *
 *   Author : Alexandre Lision <alexandre.lision@savoirfairelinux.com>              *
 *                                                                                  *
 *   This library is free software; you can redistribute it and/or                  *
 *   modify it under the terms of the GNU Lesser General Public                     *
 *   License as published by the Free Software Foundation; either                   *
 *   version 2.1 of the License, or (at your option) any later version.             *
 *                                                                                  *
 *   This library is distributed in the hope that it will be useful,                *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of                 *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU              *
 *   Lesser General Public License for more details.                                *
 *                                                                                  *
 *   You should have received a copy of the GNU Lesser General Public               *
 *   License along with this library; if not, write to the Free Software            *
 *   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA *
 ***********************************************************************************/

#define ALIAS_TAG 0
#define HOSTNAME_TAG 1
#define USERNAME_TAG 2
#define PASSWORD_TAG 3
#define USERAGENT_TAG 4


#import "AccGeneralVC.h"

#import <protocolmodel.h>
#include <qitemselectionmodel.h>

@interface AccGeneralVC ()

@property Account* privateAccount;

@property (assign) IBOutlet NSView *boxingAccount;
@property (assign) IBOutlet NSView *boxingParameters;

@property (assign) IBOutlet NSTextField *aliasTextField;
@property (assign) IBOutlet NSTextField *typeLabel;

@property (assign) IBOutlet NSTextField *serverHostTextField;
@property (assign) IBOutlet NSTextField *usernameTextField;
@property (assign) IBOutlet NSSecureTextField *passwordTextField;

@property (assign) IBOutlet NSButton *upnpButton;
@property (assign) IBOutlet NSButton *autoAnswerButton;
@property (assign) IBOutlet NSButton *userAgentButton;

@property (assign) IBOutlet NSTextField *userAgentTextField;

@end

@implementation AccGeneralVC
@synthesize typeLabel;
@synthesize aliasTextField;
@synthesize serverHostTextField;
@synthesize usernameTextField;
@synthesize passwordTextField;
@synthesize upnpButton;
@synthesize autoAnswerButton;
@synthesize userAgentButton;
@synthesize userAgentTextField;
@synthesize privateAccount;

- (void)awakeFromNib
{
    NSLog(@"INIT General VC");
    [self.aliasTextField setTag:ALIAS_TAG];
    [self.serverHostTextField setTag:HOSTNAME_TAG];
    [self.usernameTextField setTag:USERNAME_TAG];
    [self.passwordTextField setTag:PASSWORD_TAG];
    [self.userAgentTextField setTag:USERAGENT_TAG];
}

- (IBAction)toggleUpnp:(NSButton *)sender {
    privateAccount->setUpnpEnabled([sender state] == NSOnState);
}

- (IBAction)toggleAutoAnswer:(NSButton *)sender {
    privateAccount->setAutoAnswer([sender state] == NSOnState);
}

- (IBAction)toggleCustomAgent:(NSButton *)sender {
    [self.userAgentTextField setEnabled:[sender state] == NSOnState];
    privateAccount->setHasCustomUserAgent([sender state] == NSOnState);
}

- (void)loadAccount:(Account *)account
{
    if(privateAccount == account)
        return;

    privateAccount = account;

    if([account->alias().toNSString() isEqualToString:@"IP2IP"]) {
        [self.boxingAccount.subviews setValue:@YES forKeyPath:@"hidden"];
        [self.boxingParameters.subviews setValue:@YES forKeyPath:@"hidden"];
    } else {
        [self.boxingAccount.subviews setValue:@NO forKeyPath:@"hidden"];
        [self.boxingParameters.subviews setValue:@NO forKeyPath:@"hidden"];

        [self.aliasTextField setStringValue:account->alias().toNSString()];
        [self.serverHostTextField setStringValue:account->hostname().toNSString()];
        [self.usernameTextField setStringValue:account->username().toNSString()];
        [self.passwordTextField setStringValue:account->password().toNSString()];

    }

    switch (account->protocol()) {
        case Account::Protocol::SIP:
            [self.typeLabel setStringValue:@"SIP"];
            break;
        case Account::Protocol::IAX:
            [self.typeLabel setStringValue:@"IAX"];
            break;
        case Account::Protocol::RING:
            [self.typeLabel setStringValue:@"RING"];
            break;

        default:
            break;
    }

    [upnpButton setState:privateAccount->isUpnpEnabled()];
    [userAgentButton setState:privateAccount->hasCustomUserAgent()];
    [userAgentTextField setEnabled:privateAccount->hasCustomUserAgent()];
    [self.autoAnswerButton setState:privateAccount->isAutoAnswer()];
    [self.userAgentTextField setStringValue:account->userAgent().toNSString()];
}

#pragma mark - NSTextFieldDelegate methods

- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor
{
    NSLog(@"textShouldBeginEditing");
    return YES;
}

- (BOOL)control:(NSControl *)control didFailToFormatString:(NSString *)string errorDescription:(NSString *)error
{
    NSLog(@"didFailToFormatString");
}

- (void)control:(NSControl *)control didFailToValidatePartialString:(NSString *)string errorDescription:(NSString *)error
{
    NSLog(@"didFailToValidatePartialString");
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    NSLog(@"doCommandBySelector");
}

-(void)controlTextDidBeginEditing:(NSNotification *)obj
{

}

-(void)controlTextDidChange:(NSNotification *)notif
{
    NSTextField *textField = [notif object];
    NSRange test = [[textField currentEditor] selectedRange];

    switch ([textField tag]) {
        case ALIAS_TAG:
            privateAccount->setAlias([[textField stringValue] UTF8String]);
            break;
        case HOSTNAME_TAG:
            privateAccount->setHostname([[textField stringValue] UTF8String]);
            break;
        case USERNAME_TAG:
            privateAccount->setUsername([[textField stringValue] UTF8String]);
            break;
        case PASSWORD_TAG:
            privateAccount->setPassword([[textField stringValue] UTF8String]);
            break;
        case USERAGENT_TAG:
            privateAccount->setUserAgent([[textField stringValue] UTF8String]);
            break;
        default:
            break;
    }

    //FIXME: saving account lose focus because in NSTreeController we remove and reinsert row so View selction change
    //privateAccount << Account::EditAction::SAVE;
    [textField.window makeFirstResponder:textField];
    [[textField currentEditor] setSelectedRange:test];
}
@end
