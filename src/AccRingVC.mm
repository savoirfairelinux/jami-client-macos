/*
 *  Copyright (C) 2004-2015 Savoir-Faire Linux Inc.
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
 *
 *  Additional permission under GNU GPL version 3 section 7:
 *
 *  If you modify this program, or any covered work, by linking or
 *  combining it with the OpenSSL project's OpenSSL library (or a
 *  modified version of that library), containing parts covered by the
 *  terms of the OpenSSL or SSLeay licenses, Savoir-Faire Linux Inc.
 *  grants you additional permission to convey the resulting work.
 *  Corresponding Source for a non-source form of such a combination
 *  shall include the source code for the parts of OpenSSL used as well
 *  as that of the covered work.
 */
#define ALIAS_TAG 0
#define HOSTNAME_TAG 1
#define USERNAME_TAG 2
#define PASSWORD_TAG 3
#define USERAGENT_TAG 4

#import "AccRingVC.h"

#import <accountmodel.h>
#import <qitemselectionmodel.h>

@interface AccRingVC ()

@property (assign) IBOutlet NSTextField *aliasTextField;
@property (assign) IBOutlet NSTextField *typeLabel;
@property (assign) IBOutlet NSTextField *bootstrapField;
@property (assign) IBOutlet NSTextField *hashField;

@property (assign) IBOutlet NSButton *upnpButton;
@property (assign) IBOutlet NSButton *autoAnswerButton;
@property (assign) IBOutlet NSButton *userAgentButton;
@property (assign) IBOutlet NSTextField *userAgentTextField;

@end

@implementation AccRingVC
@synthesize typeLabel;
@synthesize bootstrapField;
@synthesize hashField;
@synthesize aliasTextField;
@synthesize upnpButton;
@synthesize autoAnswerButton;
@synthesize userAgentButton;
@synthesize userAgentTextField;

- (void)awakeFromNib
{
    NSLog(@"INIT Ring VC");
    [aliasTextField setTag:ALIAS_TAG];
    [userAgentTextField setTag:USERAGENT_TAG];
    [bootstrapField setTag:HOSTNAME_TAG];

    QObject::connect(AccountModel::instance()->selectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {
                         if(!current.isValid())
                             return;
                         [self loadAccount];
                     });
}

- (Account*) currentAccount
{
    auto accIdx = AccountModel::instance()->selectionModel()->currentIndex();
    return AccountModel::instance()->getAccountByModelIndex(accIdx);
}

- (void)loadAccount
{
    auto account = [self currentAccount];

    [self.aliasTextField setStringValue:account->alias().toNSString()];

    switch (account->protocol()) {
        case Account::Protocol::SIP:
            [typeLabel setStringValue:@"SIP"];
            break;
        case Account::Protocol::IAX:
            [typeLabel setStringValue:@"IAX"];
            break;
        case Account::Protocol::RING:
            [typeLabel setStringValue:@"RING"];
            break;

        default:
            break;
    }

    [upnpButton setState:[self currentAccount]->isUpnpEnabled()];
    [userAgentButton setState:[self currentAccount]->hasCustomUserAgent()];
    [userAgentTextField setEnabled:[self currentAccount]->hasCustomUserAgent()];

    [autoAnswerButton setState:[self currentAccount]->isAutoAnswer()];
    [userAgentTextField setStringValue:account->userAgent().toNSString()];

    [bootstrapField setStringValue:account->hostname().toNSString()];

    if([[self currentAccount]->username().toNSString() isEqualToString:@""])
        [hashField setStringValue:@"Reopen account to see your hash"];
    else
        [hashField setStringValue:[self currentAccount]->username().toNSString()];

}

- (IBAction)toggleUpnp:(NSButton *)sender {
    [self currentAccount]->setUpnpEnabled([sender state] == NSOnState);
}

- (IBAction)toggleAutoAnswer:(NSButton *)sender {
    [self currentAccount]->setAutoAnswer([sender state] == NSOnState);
}

- (IBAction)toggleCustomAgent:(NSButton *)sender {
    [self.userAgentTextField setEnabled:[sender state] == NSOnState];
    [self currentAccount]->setHasCustomUserAgent([sender state] == NSOnState);
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
        case ALIAS_TAG:
            [self currentAccount]->setAlias([[textField stringValue] UTF8String]);
            break;
        case HOSTNAME_TAG:
            [self currentAccount]->setHostname([[textField stringValue] UTF8String]);
            break;
        case PASSWORD_TAG:
            [self currentAccount]->setPassword([[textField stringValue] UTF8String]);
            break;
        case USERAGENT_TAG:
            [self currentAccount]->setUserAgent([[textField stringValue] UTF8String]);
            break;
        default:
            break;
    }
}

@end
