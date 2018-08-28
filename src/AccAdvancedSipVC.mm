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
#define OUTGOING_TLS_SERVER_TAG 0
#define NEGOTIATION_TIMOUT_TAG 1
#define REGISTRATION_TAG 2
#define LOCALPORT_TAG 3
#define CUSTOM_PORT_TAG 4
#define CUSTOM_ADDRESS_TAG 5
#define MINAUDIO_TAG 6
#define MAXAUDIO_TAG 7
#define MINVIDEO_TAG 8
#define MAXVIDEO_TAG 9

#import "AccAdvancedSipVC.h"

//LRC
#import <api/lrc.h>
#import <api/newaccountmodel.h>

@interface AccAdvancedSipVC () {
    __unsafe_unretained IBOutlet NSButton *encryptMediaButton;
    __unsafe_unretained IBOutlet NSButton *enableSDESButton;
    __unsafe_unretained IBOutlet NSButton *fallbackEncryptionFailureButton;
    __unsafe_unretained IBOutlet NSButton *encryptNegotiationButton;
    __unsafe_unretained IBOutlet NSButton *checkIncomingCertificatesButton;
    __unsafe_unretained IBOutlet NSButton *checkAnswerCertificatesButton;
    __unsafe_unretained IBOutlet NSButton *requereIncomingCertificateButton;
    __unsafe_unretained IBOutlet NSPopUpButton *tlsProtocolsList;
    __unsafe_unretained IBOutlet NSTextField *outgoingTlsServerNameField;
    __unsafe_unretained IBOutlet NSStepper *negotiationTimeoutStepper;
    __unsafe_unretained IBOutlet NSTextField *negotiationTimeoutField;
    __unsafe_unretained IBOutlet NSStepper *registrationTimeoutStepper;
    __unsafe_unretained IBOutlet NSTextField *registrationTimeoutField;
    __unsafe_unretained IBOutlet NSStepper *networkStepper;
    __unsafe_unretained IBOutlet NSTextField *networkField;
    __unsafe_unretained IBOutlet NSTextField *customAddressField;
    __unsafe_unretained IBOutlet NSButton *useCustomAddressButton;
    __unsafe_unretained IBOutlet NSStepper *customPortStepper;
    __unsafe_unretained IBOutlet NSTextField *customPortField;
    __unsafe_unretained IBOutlet NSStepper *minAudioPortStepper;
    __unsafe_unretained IBOutlet NSStepper *maxAudioPortStepper;
    __unsafe_unretained IBOutlet NSStepper *minVideoPortStepper;
    __unsafe_unretained IBOutlet NSStepper *maxVideoPortStepper;
    __unsafe_unretained IBOutlet NSTextField *minAudioRTPRange;
    __unsafe_unretained IBOutlet NSTextField *maxAudioRTPRange;
    __unsafe_unretained IBOutlet NSTextField *minVideoRTPRange;
    __unsafe_unretained IBOutlet NSTextField *maxVideoRTPRange;
}

@end

@implementation AccAdvancedSipVC

NSString *TLS_PROTOCOL_DEFAULT = @"Default";
NSString *TLS_PROTOCOL_TLSv1 = @"TLSv1";
NSString *TLS_PROTOCOL_TLSv1_1 = @"TLSv1_1";
NSString *TLS_PROTOCOL_TLSv1_2 = @"TLSv1_2";

@synthesize privateKeyPaswordField;
@synthesize selectCACertificateButton, selectUserCertificateButton, selectPrivateKeyButton;

- (void)awakeFromNib
{
    [super awakeFromNib];
    [negotiationTimeoutStepper setTag:NEGOTIATION_TIMOUT_TAG];
    [negotiationTimeoutField setTag:NEGOTIATION_TIMOUT_TAG];
    [registrationTimeoutStepper setTag:REGISTRATION_TAG];
    [registrationTimeoutField setTag:REGISTRATION_TAG];
    [networkStepper setTag:LOCALPORT_TAG];
    [networkField setTag:LOCALPORT_TAG];
    [customAddressField setTag: CUSTOM_ADDRESS_TAG];
    [outgoingTlsServerNameField setTag: OUTGOING_TLS_SERVER_TAG];
    [customPortStepper setTag: CUSTOM_PORT_TAG];
    [customPortField setTag: CUSTOM_PORT_TAG];
    [minAudioPortStepper setTag:MINAUDIO_TAG];
    [maxAudioPortStepper setTag:MAXAUDIO_TAG];
    [minVideoPortStepper setTag:MINVIDEO_TAG];
    [maxVideoPortStepper setTag:MAXVIDEO_TAG];
    [minAudioRTPRange setTag:MINAUDIO_TAG];
    [maxAudioRTPRange setTag:MAXAUDIO_TAG];
    [minVideoRTPRange setTag:MINVIDEO_TAG];
    [maxVideoRTPRange setTag:MAXVIDEO_TAG];
    [[self view] setAutoresizingMask: NSViewMinXMargin | NSViewMaxXMargin | NSViewHeightSizable];

}

-(void)viewDidLoad {
    [super viewDidLoad];
    NSMenu *tlsMethods = [[NSMenu alloc] initWithTitle:@""];
    [tlsMethods addItem: [[NSMenuItem alloc] initWithTitle: TLS_PROTOCOL_DEFAULT action:nil keyEquivalent:@""]];
    [tlsMethods addItem: [[NSMenuItem alloc] initWithTitle: TLS_PROTOCOL_TLSv1 action:nil keyEquivalent:@""]];
    [tlsMethods addItem: [[NSMenuItem alloc] initWithTitle: TLS_PROTOCOL_TLSv1_1 action:nil keyEquivalent:@""]];
    [tlsMethods addItem: [[NSMenuItem alloc] initWithTitle: TLS_PROTOCOL_TLSv1_2 action:nil keyEquivalent:@""]];
    tlsProtocolsList.menu = tlsMethods;
    [self updateView];
}

- (void) setSelectedAccount:(std::string) account {
    [super setSelectedAccount: account];
    [self updateView];
}

- (void) updateView {
    auto accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    [encryptMediaButton setState: accountProperties.SRTP.enable];
    [enableSDESButton setState: accountProperties.SRTP.keyExchange == lrc::api::account::KeyExchangeProtocol::SDES ? NSControlStateValueOn : NSControlStateValueOff];
    [fallbackEncryptionFailureButton setState: accountProperties.SRTP.rtpFallback];
    [encryptNegotiationButton setState: accountProperties.TLS.enable];
    [selectCACertificateButton setEnabled: accountProperties.TLS.enable];
    [selectUserCertificateButton setEnabled: accountProperties.TLS.enable];
    [selectPrivateKeyButton setEnabled: accountProperties.TLS.enable];
    [privateKeyPaswordField setEnabled: accountProperties.TLS.enable];
    [checkIncomingCertificatesButton setState: accountProperties.TLS.verifyServer];
    [checkAnswerCertificatesButton setState: accountProperties.TLS.verifyClient];
    [requereIncomingCertificateButton setState: accountProperties.TLS.requireClientCertificate];
    switch (accountProperties.TLS.method) {
        case lrc::api::account::TlsMethod::DEFAULT:
            [tlsProtocolsList selectItemWithTitle:TLS_PROTOCOL_DEFAULT];
            break;
        case lrc::api::account::TlsMethod::TLSv1:
            [tlsProtocolsList selectItemWithTitle:TLS_PROTOCOL_TLSv1];
            break;
        case lrc::api::account::TlsMethod::TLSv1_1:
            [tlsProtocolsList selectItemWithTitle:TLS_PROTOCOL_TLSv1_1];
            break;
        case lrc::api::account::TlsMethod::TLSv1_2:
            [tlsProtocolsList selectItemWithTitle:TLS_PROTOCOL_TLSv1_2];
            break;

        default:
            break;
    }
    [negotiationTimeoutStepper setIntegerValue: accountProperties.TLS.negotiationTimeoutSec];
    [negotiationTimeoutField setIntegerValue: accountProperties.TLS.negotiationTimeoutSec];
    [registrationTimeoutStepper setIntegerValue: accountProperties.Registration.expire];
    [registrationTimeoutField setIntegerValue: accountProperties.Registration.expire];
    [networkStepper setIntegerValue: accountProperties.localPort];
    [networkField setIntegerValue: accountProperties.localPort];
    [customAddressField setEnabled:!accountProperties.publishedSameAsLocal];
    [customPortField setEnabled:!accountProperties.publishedSameAsLocal];
    [customPortStepper setEnabled:!accountProperties.publishedSameAsLocal];
    [useCustomAddressButton setState:!accountProperties.publishedSameAsLocal];
    [customPortStepper setIntegerValue: accountProperties.publishedPort];
    [customPortField setIntegerValue: accountProperties.publishedPort];
    [customAddressField setStringValue: @(accountProperties.publishedAddress.c_str())];
    [minAudioPortStepper setIntegerValue: accountProperties.Audio.audioPortMin];
    [minAudioRTPRange setIntegerValue: accountProperties.Audio.audioPortMin];
    [maxAudioPortStepper setIntegerValue: accountProperties.Audio.audioPortMax];
    [maxAudioRTPRange setIntegerValue: accountProperties.Audio.audioPortMax];
    [minVideoPortStepper setIntegerValue: accountProperties.Video.videoPortMin];
    [minVideoRTPRange setIntegerValue: accountProperties.Video.videoPortMin];
    [maxVideoPortStepper setIntegerValue: accountProperties.Video.videoPortMin];
    [maxVideoRTPRange setIntegerValue: accountProperties.Video.videoPortMin];
}

#pragma mark - Actions

- (IBAction)toggleEnableSDES:(id)sender {
    auto accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    lrc::api::account::KeyExchangeProtocol newState = [sender state] == NSControlStateValueOn ? lrc::api::account::KeyExchangeProtocol::SDES : lrc::api::account::KeyExchangeProtocol::NONE;
    if(accountProperties.SRTP.keyExchange != newState) {
        accountProperties.SRTP.keyExchange = newState;
        self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
    }
}
- (IBAction)toggleEncryptMedia:(id)sender {
    auto accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    if(accountProperties.SRTP.enable!= [sender state]) {
        accountProperties.SRTP.enable = [sender state];
        self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
    }
}
- (IBAction)toggleFallbackEncryptionFailure:(id)sender {
    auto accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    if(accountProperties.SRTP.rtpFallback != [sender state]) {
        accountProperties.SRTP.rtpFallback = [sender state];
        self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
    }
}
- (IBAction)toggleEncryptNegotiation:(id)sender {
    auto accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    if(accountProperties.TLS.enable != [sender state]) {
        accountProperties.TLS.enable = [sender state];
        self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
        [selectCACertificateButton setEnabled: [sender state]];
        [selectUserCertificateButton setEnabled: [sender state]];
        [selectPrivateKeyButton setEnabled: [sender state]];
        [privateKeyPaswordField setEnabled: [sender state]];
    }
}
- (IBAction)toggleVerifyServerCertificate:(id)sender {
    auto accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    if(accountProperties.TLS.verifyServer != [sender state]) {
        accountProperties.TLS.verifyServer = [sender state];
        self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
    }
}
- (IBAction)toggleVerifyClientCertificate:(id)sender {
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    if(accountProperties.TLS.verifyClient != [sender state]) {
        accountProperties.TLS.verifyClient = [sender state];
        self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
    }
}
- (IBAction)toggleCertForIncomingConnection:(id)sender {
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    if(accountProperties.TLS.requireClientCertificate != [sender state]) {
        accountProperties.TLS.requireClientCertificate = [sender state];
        self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
    }
}

- (IBAction)enableCustomAddress:(id)sender {
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    if(accountProperties.publishedSameAsLocal != ![sender state]) {
        accountProperties.publishedSameAsLocal = ![sender state];
        self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
        [customAddressField setEnabled:[sender state]];
        [customPortField setEnabled:[sender state]];
        [customPortStepper setEnabled:[sender state]];
    }
}

- (IBAction)chooseTlsProtocol:(id)sender {
    int index = [sender indexOfSelectedItem];
    if(index < 0) {
        return;
    }
    NSString *title = [[tlsProtocolsList.menu itemAtIndex:index] title];
    lrc::api::account::TlsMethod method;

    if(title == TLS_PROTOCOL_DEFAULT) {
        method = lrc::api::account::TlsMethod::DEFAULT;
    } else if(title == TLS_PROTOCOL_TLSv1) {
        method = lrc::api::account::TlsMethod::TLSv1;
    } else if(title == TLS_PROTOCOL_TLSv1_1) {
        method = lrc::api::account::TlsMethod::TLSv1_1;
    } else if(title == TLS_PROTOCOL_TLSv1_2) {
        method = lrc::api::account::TlsMethod::TLSv1_2;
    } else {
        return;
    }
    auto accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    if(accountProperties.TLS.method != method) {
        accountProperties.TLS.method = method;
        self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
    }
}

- (IBAction) valueDidChange: (id) sender
{
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);

    switch ([sender tag]) {
        case OUTGOING_TLS_SERVER_TAG:
            if(accountProperties.TLS.serverName != [[sender stringValue] UTF8String]) {
                accountProperties.TLS.serverName = [[sender stringValue] UTF8String];
                self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
            }
            return;
        case NEGOTIATION_TIMOUT_TAG:
            if(accountProperties.TLS.negotiationTimeoutSec != [[sender stringValue] integerValue]) {
                accountProperties.TLS.negotiationTimeoutSec = [[sender stringValue] integerValue];
                self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
                [negotiationTimeoutStepper setIntegerValue: [[sender stringValue] integerValue]];
                [negotiationTimeoutField setIntegerValue: [[sender stringValue] integerValue]];
            }
            return;
        case REGISTRATION_TAG:
            if(accountProperties.Registration.expire != [[sender stringValue] integerValue]) {
                accountProperties.Registration.expire = [[sender stringValue] integerValue];
                self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
                [registrationTimeoutStepper setIntegerValue: [[sender stringValue] integerValue]];
                [registrationTimeoutField setIntegerValue: [[sender stringValue] integerValue]];
            }
            return;
        case LOCALPORT_TAG:
            if(accountProperties.localPort != [[sender stringValue] integerValue]) {
                accountProperties.localPort = [[sender stringValue] integerValue];
                self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
                [networkStepper setIntegerValue: [[sender stringValue] integerValue]];
                [networkField setIntegerValue: [[sender stringValue] integerValue]];
            }
            return;
        case CUSTOM_ADDRESS_TAG:
            if(accountProperties.publishedAddress != [[sender stringValue] UTF8String]) {
                NSString *name = [sender stringValue];
                accountProperties.publishedAddress = [[sender stringValue] UTF8String];
                self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
            }
            return;
        case CUSTOM_PORT_TAG:
            if(accountProperties.publishedPort != [[sender stringValue] integerValue]) {
                accountProperties.publishedPort = [[sender stringValue] integerValue];
                self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
                [customPortStepper setIntegerValue: [[sender stringValue] integerValue]];
                [customPortField setIntegerValue: [[sender stringValue] integerValue]];
            }
            return;
        case MINAUDIO_TAG:
            if(accountProperties.Audio.audioPortMin != [[sender stringValue] integerValue]) {
                accountProperties.Audio.audioPortMin = [[sender stringValue] integerValue];
                self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
                [minAudioPortStepper setIntegerValue: [[sender stringValue] integerValue]];
                [minAudioRTPRange setIntegerValue: [[sender stringValue] integerValue]];
            }
            return;
        case MAXAUDIO_TAG:
            if(accountProperties.Audio.audioPortMax != [[sender stringValue] integerValue]) {
                accountProperties.Audio.audioPortMax = [[sender stringValue] integerValue];
                self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
                [maxAudioPortStepper setIntegerValue: [[sender stringValue] integerValue]];
                [maxAudioRTPRange setIntegerValue: [[sender stringValue] integerValue]];
            }
            return;
        case MINVIDEO_TAG:
            if(accountProperties.Video.videoPortMin != [[sender stringValue] integerValue]) {
                accountProperties.Video.videoPortMin = [[sender stringValue] integerValue];
                self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
                [minVideoPortStepper setIntegerValue: [[sender stringValue] integerValue]];
                [minVideoRTPRange setIntegerValue: [[sender stringValue] integerValue]];
            }
            return;
        case MAXVIDEO_TAG:
            if(accountProperties.Video.videoPortMax != [[sender stringValue] integerValue]) {
                accountProperties.Video.videoPortMax = [[sender stringValue] integerValue];
                self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
                [maxVideoPortStepper setIntegerValue: [[sender stringValue] integerValue]];
                [maxVideoRTPRange setIntegerValue: [[sender stringValue] integerValue]];
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
