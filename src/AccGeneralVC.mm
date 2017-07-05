/*
 *  Copyright (C) 2015-2016 Savoir-faire Linux Inc.
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
#import "AccGeneralVC.h"

#import <accountmodel.h>
#import <protocolmodel.h>
#import <qitemselectionmodel.h>

@interface AccGeneralVC () {

    __unsafe_unretained IBOutlet NSTextField *aliasTextField;

    __unsafe_unretained IBOutlet NSTextField *serverHostTextField;
    __unsafe_unretained IBOutlet NSTextField *usernameTextField;
    __unsafe_unretained IBOutlet NSSecureTextField *passwordTextField;
    NSTextField *clearTextField;

    __unsafe_unretained IBOutlet NSButton *upnpButton;
    __unsafe_unretained IBOutlet NSButton *autoAnswerButton;
    __unsafe_unretained IBOutlet NSButton *userAgentButton;
    __unsafe_unretained IBOutlet NSTextField *userAgentTextField;
}
@end

@implementation AccGeneralVC

//Tags for views
typedef NS_ENUM(NSInteger, TagViews) {
    ALIAS       = 0,
    HOSTNAME    = 1,
    USERNAME    = 2,
    PASSWORD    = 3,
    USERAGENT   = 4,
    DTMF_SIP    = 5,
    DTMF_RTP    = 6,
};

- (void)awakeFromNib
{
    NSLog(@"INIT General VC");
    [aliasTextField setTag:TagViews::ALIAS];
    [serverHostTextField setTag:TagViews::HOSTNAME];
    [usernameTextField setTag:TagViews::USERNAME];
    [passwordTextField setTag:TagViews::PASSWORD];
    [userAgentTextField setTag:TagViews::USERAGENT];

    QObject::connect(AccountModel::instance().selectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {
                         if(!current.isValid())
                             return;
                         [self loadAccount];
                     });
}

- (IBAction)toggleUpnp:(NSButton *)sender {
    AccountModel::instance().selectedAccount()->setUpnpEnabled([sender state] == NSOnState);
}

- (IBAction)toggleAutoAnswer:(NSButton *)sender {
    AccountModel::instance().selectedAccount()->setAutoAnswer([sender state] == NSOnState);
}

- (IBAction)toggleCustomAgent:(NSButton *)sender {
    [userAgentTextField setEnabled:[sender state] == NSOnState];
    AccountModel::instance().selectedAccount()->setHasCustomUserAgent([sender state] == NSOnState);
}

- (void)loadAccount
{
    auto account = AccountModel::instance().selectedAccount();

    [aliasTextField setStringValue:account->alias().toNSString()];
    [serverHostTextField setStringValue:account->hostname().toNSString()];
    [usernameTextField setStringValue:account->username().toNSString()];
    [passwordTextField setStringValue:account->password().toNSString()];
    [clearTextField setStringValue:account->password().toNSString()];

    [upnpButton setState:AccountModel::instance().selectedAccount()->isUpnpEnabled()];
    [userAgentButton setState:AccountModel::instance().selectedAccount()->hasCustomUserAgent()];
    [userAgentTextField setEnabled:AccountModel::instance().selectedAccount()->hasCustomUserAgent()];
    [autoAnswerButton setState:AccountModel::instance().selectedAccount()->isAutoAnswer()];
    [userAgentTextField setStringValue:account->userAgent().toNSString()];
}

- (IBAction)tryRegistration:(id)sender {
    AccountModel::instance().selectedAccount() << Account::EditAction::SAVE;
}

- (IBAction)showPassword:(NSButton *)sender {
    if (sender.state == NSOnState) {
        clearTextField = [[NSTextField alloc] initWithFrame:passwordTextField.frame];
        [clearTextField setTag:passwordTextField.tag];
        [clearTextField setDelegate:self];
        [clearTextField setBounds:passwordTextField.bounds];
        [clearTextField setStringValue:passwordTextField.stringValue];
        [clearTextField becomeFirstResponder];
        [self.view addSubview:clearTextField];
        [passwordTextField setHidden:YES];
    } else {
        [passwordTextField setStringValue:clearTextField.stringValue];
        [passwordTextField setHidden:NO];
        [clearTextField removeFromSuperview];
        clearTextField = nil;
    }
}

/**
 *  Debug purpose
 */
-(void) dumpFrame:(CGRect) frame WithName:(NSString*) name
{
    NSLog(@"frame %@ : %f %f %f %f \n\n",name ,frame.origin.x, frame.origin.y, frame.size.width, frame.size.height);
}

#pragma mark - NSTextFieldDelegate methods

- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor
{
    return YES;
}

-(void)controlTextDidChange:(NSNotification *)notif
{
    NSTextField *textField = [notif object];

    switch ([textField tag]) {
        case TagViews::ALIAS:
            AccountModel::instance().selectedAccount()->setAlias([[textField stringValue] UTF8String]);
            AccountModel::instance().selectedAccount()->setDisplayName([[textField stringValue] UTF8String]);
            break;
        case TagViews::HOSTNAME:
            AccountModel::instance().selectedAccount()->setHostname([[textField stringValue] UTF8String]);
            break;
        case TagViews::USERNAME:
            AccountModel::instance().selectedAccount()->setUsername([[textField stringValue] UTF8String]);
            break;
        case TagViews::PASSWORD:
            AccountModel::instance().selectedAccount()->setPassword([[textField stringValue] UTF8String]);
            break;
        case TagViews::USERAGENT:
            AccountModel::instance().selectedAccount()->setUserAgent([[textField stringValue] UTF8String]);
            break;
        default:
            break;
    }
}

@end
