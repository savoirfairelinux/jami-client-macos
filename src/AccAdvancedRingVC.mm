/*
 *  Copyright (C) 2015-2019 Savoir-faire Linux Inc.
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
    __unsafe_unretained IBOutlet NSButton *enableLocalModeratorButton;
    __unsafe_unretained IBOutlet NSButton *togleRendezVous;
}
@end

@implementation AccAdvancedRingVC

//Tags for views
const NSInteger  NAME_SERVER_TAG         = 100;
const NSInteger  PROXY_SERVER_TAG        = 200;
const NSInteger  BOOTSTRAP_SERVER_TAG    = 300;

-(void) updateView {
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    [allowIncoming setState: accountProperties.DHT.PublicInCalls];
    [nameServerField setStringValue: accountProperties.RingNS.uri.toNSString()];
    [proxyServerField setStringValue: accountProperties.proxyServer.toNSString()];
    [bootstrapServerField setStringValue: accountProperties.hostname.toNSString()];
    [enableProxyButton setState: accountProperties.proxyEnabled];
    [proxyServerField setEditable:accountProperties.proxyEnabled];
    [togleRendezVous setState: accountProperties.isRendezVous];
    [enableLocalModeratorButton setState: self.accountModel->isLocalModeratorsEnabled(self.selectedAccountID)];
}

-(void) viewDidLoad {
    [super viewDidLoad];
    [[self view] setAutoresizingMask: NSViewMinXMargin | NSViewMaxXMargin | NSViewWidthSizable];
    [self updateView];
}

- (void) setSelectedAccount:(const QString&) account {
    [super setSelectedAccount: account];
    [self updateView];
}

#pragma mark - Actions

- (IBAction)allowCallFromUnknownPeer:(id)sender {
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    if(accountProperties.DHT.PublicInCalls != [sender state]) {
        accountProperties.DHT.PublicInCalls = [sender state];
        self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
    }
}

- (IBAction)enableRendezVous:(id)sender {
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    if(accountProperties.isRendezVous != [sender state]) {
        accountProperties.isRendezVous = [sender state];
        self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
    }
}

- (IBAction)enableLocalModerators:(id)sender {
    self.accountModel->enableLocalModerators(self.selectedAccountID, [sender state]);
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
            if(accountProperties.RingNS.uri != QString::fromNSString([sender stringValue])) {
                accountProperties.RingNS.uri = QString::fromNSString([sender stringValue]);
                self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
            }
            return;
        case PROXY_SERVER_TAG:
            if(accountProperties.proxyServer != QString::fromNSString([sender stringValue])) {
                accountProperties.proxyServer = QString::fromNSString([sender stringValue]);
                self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
            }
            return;
        case BOOTSTRAP_SERVER_TAG:
            if(accountProperties.hostname != QString::fromNSString([sender stringValue])) {
                accountProperties.hostname = QString::fromNSString([sender stringValue]);
                self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
            }
            return;
        default:
            break;
    }

    [super valueDidChange:sender];
}

#pragma mark - NSTextFieldDelegate methods

-(void)controlTextDidEndEditing:(NSNotification *)notif
{
    NSTextField *textField = [notif object];
    [self valueDidChange:textField];
}

@end
