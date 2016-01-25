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
#define REGISTRATION_TAG 0
#define LOCALPORT_TAG 1
#define STUNURL_TAG 2
#define PUBLICADDR_TAG 3
#define PUBLICPORT_TAG 4
#define MINAUDIO_TAG 5
#define MAXAUDIO_TAG 6
#define MINVIDEO_TAG 7
#define MAXVIDEO_TAG 8

#define TURN_SERVER_TAG     9
#define TURN_USERNAME_TAG   10
#define TURN_PASSWORD_TAG   11
#define TURN_REALM_TAG      12

#import "AccAdvancedVC.h"

///Qt
#import <qitemselectionmodel.h>

///LRC
#import <accountmodel.h>
#import <credentialmodel.h>
#import <credential.h>


@interface AccAdvancedVC ()
@property (unsafe_unretained) IBOutlet NSView *registrationContainer;
@property (unsafe_unretained) IBOutlet NSView *mainContainer;

@property (unsafe_unretained) IBOutlet NSTextField *registrationField;
@property (unsafe_unretained) IBOutlet NSTextField *localPortField;
@property (unsafe_unretained) IBOutlet NSButton *isUsingSTUN;

@property (unsafe_unretained) IBOutlet NSTextField *STUNserverURLField;
@property (unsafe_unretained) IBOutlet NSTextField *minAudioRTPRange;
@property (unsafe_unretained) IBOutlet NSTextField *maxAudioRTPRange;
@property (unsafe_unretained) IBOutlet NSTextField *minVideoRTPRange;
@property (unsafe_unretained) IBOutlet NSTextField *maxVideoRTPRange;

@property (unsafe_unretained) IBOutlet NSButton *isUsingTURN;
@property (unsafe_unretained) IBOutlet NSTextField *turnServerURL;
@property (unsafe_unretained) IBOutlet NSTextField *turnUsername;
@property (unsafe_unretained) IBOutlet NSSecureTextField *turnPassword;
@property (unsafe_unretained) IBOutlet NSTextField *turnRealm;

@property (unsafe_unretained) IBOutlet NSStepper *registrationStepper;
@property (unsafe_unretained) IBOutlet NSStepper *localPortStepper;
@property (unsafe_unretained) IBOutlet NSStepper *minAudioPortStepper;
@property (unsafe_unretained) IBOutlet NSStepper *maxAudioPortStepper;
@property (unsafe_unretained) IBOutlet NSStepper *minVideoPortStepper;
@property (unsafe_unretained) IBOutlet NSStepper *maxVideoPortStepper;

@property (unsafe_unretained) IBOutlet NSMatrix *publishAddrAndPortRadioGroup;
@property (unsafe_unretained) IBOutlet NSTextField *publishedAddrField;
@property (unsafe_unretained) IBOutlet NSTextField *publishedPortField;

@end

@implementation AccAdvancedVC
@synthesize registrationField;
@synthesize localPortField;
@synthesize isUsingSTUN;
@synthesize STUNserverURLField;
@synthesize minAudioRTPRange;
@synthesize maxAudioRTPRange;
@synthesize minVideoRTPRange;
@synthesize maxVideoRTPRange;
@synthesize registrationStepper;
@synthesize localPortStepper;
@synthesize turnPassword, isUsingTURN, turnRealm, turnServerURL, turnUsername;
@synthesize minAudioPortStepper;
@synthesize maxAudioPortStepper;
@synthesize minVideoPortStepper;
@synthesize maxVideoPortStepper;
@synthesize publishAddrAndPortRadioGroup;
@synthesize publishedAddrField;
@synthesize publishedPortField;

- (void)awakeFromNib
{
    NSLog(@"INIT Advanced VC");
    [registrationStepper setTag:REGISTRATION_TAG];
    [localPortStepper setTag:LOCALPORT_TAG];
    [minAudioPortStepper setTag:MINAUDIO_TAG];
    [maxAudioPortStepper setTag:MAXAUDIO_TAG];
    [minVideoPortStepper setTag:MINVIDEO_TAG];
    [maxVideoPortStepper setTag:MAXVIDEO_TAG];

    [turnServerURL setTag:TURN_SERVER_TAG];
    [turnUsername setTag:TURN_USERNAME_TAG];
    [turnPassword setTag:TURN_PASSWORD_TAG];
    [turnRealm setTag:TURN_REALM_TAG];

    [registrationField setTag:REGISTRATION_TAG];
    [localPortField setTag:LOCALPORT_TAG];
    [minAudioRTPRange setTag:MINAUDIO_TAG];
    [maxAudioRTPRange setTag:MAXAUDIO_TAG];
    [minVideoRTPRange setTag:MINVIDEO_TAG];
    [maxVideoRTPRange setTag:MAXVIDEO_TAG];

    [STUNserverURLField setTag:STUNURL_TAG];
    [publishedPortField setTag:PUBLICPORT_TAG];
    [publishedAddrField setTag:PUBLICADDR_TAG];

    QObject::connect(AccountModel::instance().selectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {
                         if(!current.isValid())
                             return;
                         [self loadAccount];
                     });

}

- (Account*) currentAccount
{
    auto accIdx = AccountModel::instance().selectionModel()->currentIndex();
    return AccountModel::instance().getAccountByModelIndex(accIdx);
}

- (void)loadAccount
{
    auto account = [self currentAccount];

    [self updateControlsWithTag:REGISTRATION_TAG];
    [self updateControlsWithTag:LOCALPORT_TAG];
    [self updateControlsWithTag:MINAUDIO_TAG];
    [self updateControlsWithTag:MAXAUDIO_TAG];
    [self updateControlsWithTag:MINVIDEO_TAG];
    [self updateControlsWithTag:MAXVIDEO_TAG];

    [STUNserverURLField setStringValue:account->sipStunServer().toNSString()];
    [isUsingSTUN setState:account->isSipStunEnabled()?NSOnState:NSOffState];
    [STUNserverURLField setEnabled:account->isSipStunEnabled()];

    [isUsingTURN setState:account->isTurnEnabled()?NSOnState:NSOffState];
    [self toggleTURN:isUsingTURN];
    [turnServerURL setStringValue:account->turnServer().toNSString()];

    auto turnCreds = account->credentialModel()->primaryCredential(Credential::Type::TURN);

    [turnUsername setStringValue:turnCreds->username().toNSString()];
    [turnPassword setStringValue:turnCreds->password().toNSString()];
    [turnRealm setStringValue:turnCreds->realm().toNSString()];

    if(account->isPublishedSameAsLocal())
        [publishAddrAndPortRadioGroup selectCellAtRow:0 column:0];
    else {
        [publishAddrAndPortRadioGroup selectCellAtRow:1 column:0];
    }

    [publishedAddrField setStringValue:account->publishedAddress().toNSString()];
    [publishedPortField setIntValue:account->publishedPort()];
    [publishedAddrField setEnabled:!account->isPublishedSameAsLocal()];
    [publishedPortField setEnabled:!account->isPublishedSameAsLocal()];

    if(account->protocol() == Account::Protocol::RING) {
        [self.registrationContainer setHidden:YES];
    } else {
        [self.registrationContainer setHidden:NO];
    }
}

#pragma mark - NSTextFieldDelegate methods

-(void)controlTextDidChange:(NSNotification *)notif
{
    NSTextField *textField = [notif object];
    NSRange test = [[textField currentEditor] selectedRange];

    [self valueDidChange:textField];
    //FIXME: saving account lose focus because in NSTreeController we remove and reinsert row so View selection change
    [textField.window makeFirstResponder:textField];
    [[textField currentEditor] setSelectedRange:test];
}

- (IBAction) valueDidChange: (id) sender
{
    switch ([sender tag]) {
        case REGISTRATION_TAG:
            [self currentAccount]->setRegistrationExpire([sender integerValue]);
            break;
        case LOCALPORT_TAG:
            [self currentAccount]->setLocalPort([sender integerValue]);
            break;
        case STUNURL_TAG:
            [self currentAccount]->setSipStunServer([[sender stringValue] UTF8String]);
            break;
        case PUBLICADDR_TAG:
            [self currentAccount]->setPublishedAddress([[sender stringValue] UTF8String]);
            break;
        case PUBLICPORT_TAG:
            [self currentAccount]->setPublishedPort([sender integerValue]);
            break;
        case MINAUDIO_TAG:
            [self currentAccount]->setAudioPortMin([sender integerValue]);
            break;
        case MAXAUDIO_TAG:
            [self currentAccount]->setAudioPortMax([sender integerValue]);
            break;
        case MINVIDEO_TAG:
            [self currentAccount]->setVideoPortMin([sender integerValue]);
            break;
        case MAXVIDEO_TAG:
            [self currentAccount]->setVideoPortMax([sender integerValue]);
            break;
        case TURN_SERVER_TAG:
            [self currentAccount]->setTurnServer([[sender stringValue] UTF8String]);
            break;
        case TURN_USERNAME_TAG:
            [self currentAccount]->credentialModel()->primaryCredential(Credential::Type::TURN)->setUsername([[sender stringValue] UTF8String]);
            break;
        case TURN_PASSWORD_TAG:
            [self currentAccount]->credentialModel()->primaryCredential(Credential::Type::TURN)->setPassword([[sender stringValue] UTF8String]);
            break;
        case TURN_REALM_TAG:
            [self currentAccount]->credentialModel()->primaryCredential(Credential::Type::TURN)->setRealm([[sender stringValue] UTF8String]);
            break;
        default:
            break;
    }
    [self updateControlsWithTag:[sender tag]];
}

- (IBAction)toggleSTUN:(NSButton *)sender
{
    [self currentAccount]->setSipStunEnabled([sender state]);
    [STUNserverURLField setEnabled:[self currentAccount]->isSipStunEnabled()];
}

- (IBAction)toggleTURN:(id)sender {
    [self currentAccount]->setTurnEnabled([sender state]);
    [turnServerURL setEnabled:[sender state]];
    [turnUsername setEnabled:[sender state]];
    [turnPassword setEnabled:[sender state]];
    [turnRealm setEnabled:[sender state]];
}

- (IBAction)didSwitchPublishedAddress:(NSMatrix *)matrix
{
    NSInteger row = [matrix selectedRow];
    if(row == 0) {
        [self currentAccount]->setPublishedSameAsLocal(YES);
    } else {
        [self currentAccount]->setPublishedSameAsLocal(NO);
    }
    [publishedAddrField setEnabled:![self currentAccount]->isPublishedSameAsLocal()];
    [publishedPortField setEnabled:![self currentAccount]->isPublishedSameAsLocal()];

}

- (void) updateControlsWithTag:(NSInteger) tag
{
    switch (tag) {
        case REGISTRATION_TAG:
            [registrationStepper setIntegerValue:[self currentAccount]->registrationExpire()];
            [registrationField setIntegerValue:[self currentAccount]->registrationExpire()];
            break;
        case LOCALPORT_TAG:
            [localPortStepper setIntegerValue:[self currentAccount]->localPort()];
            [localPortField setIntegerValue:[self currentAccount]->localPort()];
            break;
        case MINAUDIO_TAG:
            [minAudioPortStepper setIntegerValue:[self currentAccount]->audioPortMin()];
            [minAudioRTPRange setIntegerValue:[self currentAccount]->audioPortMin()];
            break;
        case MAXAUDIO_TAG:
            [maxAudioPortStepper setIntegerValue:[self currentAccount]->audioPortMax()];
            [maxAudioRTPRange setIntegerValue:[self currentAccount]->audioPortMax()];
            break;
        case MINVIDEO_TAG:
            [minVideoPortStepper setIntegerValue:[self currentAccount]->videoPortMin()];
            [minVideoRTPRange setIntegerValue:[self currentAccount]->videoPortMin()];
            break;
        case MAXVIDEO_TAG:
            [maxVideoPortStepper setIntegerValue:[self currentAccount]->videoPortMax()];
            [maxVideoRTPRange setIntegerValue:[self currentAccount]->videoPortMax()];
            break;
        default:
            break;
    }
}

@end
