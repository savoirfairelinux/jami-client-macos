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

#import "AccRingVC.h"

@interface AccRingVC ()

@property Account* privateAccount;

@property (assign) IBOutlet NSTextField *aliasTextField;
@property (assign) IBOutlet NSTextField *typeLabel;
@property (assign) IBOutlet NSTextField *boostrapField;

@property (assign) IBOutlet NSButton *upnpButton;
@property (assign) IBOutlet NSButton *autoAnswerButton;
@property (assign) IBOutlet NSButton *userAgentButton;
@property (assign) IBOutlet NSTextField *userAgentTextField;

@end

@implementation AccRingVC
@synthesize privateAccount;
@synthesize typeLabel;
@synthesize boostrapField;
@synthesize aliasTextField;
@synthesize upnpButton;
@synthesize autoAnswerButton;
@synthesize userAgentButton;
@synthesize userAgentTextField;

- (void)awakeFromNib
{
    NSLog(@"INIT Ring VC");
    [self.aliasTextField setTag:ALIAS_TAG];
    [self.userAgentTextField setTag:USERAGENT_TAG];
}

- (void)loadAccount:(Account *)account
{
    if(privateAccount == account)
        return;

    privateAccount = account;

    [self.aliasTextField setStringValue:account->alias().toNSString()];

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

    [self.autoAnswerButton setState:privateAccount->isAutoAnswer()];
    [self.userAgentTextField setStringValue:account->userAgent().toNSString()];
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
