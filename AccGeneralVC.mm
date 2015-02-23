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


#import "AccGeneralVC.h"

@interface AccGeneralVC ()

@property Account* privateAccount;

@end

@implementation AccGeneralVC
@synthesize aliasTextField;
@synthesize serverHostTextField;
@synthesize usernameTextField;
@synthesize passwordTextField;
@synthesize privateAccount;

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        NSLog(@"INIT General VC");
    }
    return self;
}

- (void)awakeFromNib
{
    [self.aliasTextField setTag:ALIAS_TAG];
    [self.serverHostTextField setTag:HOSTNAME_TAG];
    [self.usernameTextField setTag:USERNAME_TAG];
    [self.passwordTextField setTag:PASSWORD_TAG];
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
        default:
            break;
    }

    [textField.window makeFirstResponder:textField];
    [[textField currentEditor] moveToEndOfLine:nil];
}
@end
