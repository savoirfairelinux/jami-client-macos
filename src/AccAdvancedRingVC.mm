/*
 *  Copyright (C) 2015-2018 Savoir-faire Linux Inc.
 *  Author: Alexandre Lision <alexandre.lision@savoirfairelinux.com>
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
#import "AccAdvancedRingVC.h"

//LRC
#import <api/lrc.h>
#import <api/newaccountmodel.h>
#import <api/newdevicemodel.h>

@interface AccAdvancedRingVC () {
    __unsafe_unretained IBOutlet NSButton *allowIncoming;
    __unsafe_unretained IBOutlet NSTextField *nameServerField;
    __unsafe_unretained IBOutlet NSTextField *proxyServerField;
    __unsafe_unretained IBOutlet NSTextField *bootstrapServerField;
    __unsafe_unretained IBOutlet NSButton *enableProxyButton;
}
@end

@implementation AccAdvancedRingVC

//Tags for views
const NSInteger  NAME_SERVER_TAG         = 100;
const NSInteger  PROXY_SERVER_TAG        = 200;
const NSInteger  BOOTSTRAP_SERVER_TAG    = 300;

-(void) updateView {
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    [allowIncoming setState: accountProperties.allowIncoming];
    [nameServerField setStringValue: @(accountProperties.RingNS.uri.c_str())];
    [proxyServerField setStringValue:@(accountProperties.proxyServer.c_str())];
    [bootstrapServerField setStringValue:@(accountProperties.hostname.c_str())];
    [enableProxyButton setState: accountProperties.proxyEnabled];
    [proxyServerField setEditable:accountProperties.proxyEnabled];
}

-(void) viewDidLoad {
    [super viewDidLoad];
    [[self view] setAutoresizingMask: NSViewMinXMargin | NSViewMaxXMargin | NSViewHeightSizable];
    [self updateView];
}

- (void) setSelectedAccount:(std::string) account {
    [super setSelectedAccount: account];
    [self updateView];
}

#pragma mark - Actions

- (IBAction)allowCallFromUnknownPeer:(id)sender {
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    if(accountProperties.allowIncoming != [sender state]) {
        accountProperties.allowIncoming = [sender state];
        self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
    }
}

- (IBAction)enableProxy:(id)sender {
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    if(accountProperties.proxyEnabled != [sender state]) {
        accountProperties.proxyEnabled = [sender state];
        self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
    }
    [proxyServerField setEditable:[sender state]];
}

- (IBAction) valueDidChange: (id) sender
{
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);

    switch ([sender tag]) {
        case NAME_SERVER_TAG:
            if(accountProperties.RingNS.uri != [[sender stringValue] UTF8String]) {
                accountProperties.RingNS.uri = [[sender stringValue] UTF8String];
                self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
            }
            return;
        case PROXY_SERVER_TAG:
            if(accountProperties.proxyServer != [[sender stringValue] UTF8String]) {
                accountProperties.proxyServer = [[sender stringValue] UTF8String];
                self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
            }
            return;
        case BOOTSTRAP_SERVER_TAG:
            if(accountProperties.hostname != [[sender stringValue] UTF8String]) {
                accountProperties.hostname = [[sender stringValue] UTF8String];
                self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
            }
            return;
        default:
            break;
    }

    [super valueDidChange:sender];
}

#pragma mark - NSTextFieldDelegate methods

-(void)controlTextDidChange:(NSNotification *)notif
{
    NSTextField *textField = [notif object];
    NSRange test = [[textField currentEditor] selectedRange];

    [self valueDidChange:textField];
}

@end
