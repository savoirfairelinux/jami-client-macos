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
@property (unsafe_unretained) IBOutlet NSButton *allowUnknown;
@property (unsafe_unretained) IBOutlet NSButton *allowHistory;
@property (unsafe_unretained) IBOutlet NSButton *allowContacts;

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
@synthesize allowContacts, allowHistory, allowUnknown;

- (void)awakeFromNib
{
    NSLog(@"INIT Ring VC");
    [aliasTextField setTag:ALIAS_TAG];
    [userAgentTextField setTag:USERAGENT_TAG];
    [bootstrapField setTag:HOSTNAME_TAG];

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

    [self.aliasTextField setStringValue:account->alias().toNSString()];

    [typeLabel setStringValue:@"RING"];

    [allowUnknown setState:account->allowIncomingFromUnknown()];
    [allowHistory setState:account->allowIncomingFromHistory()];
    [allowContacts setState:account->allowIncomingFromContact()];

    [allowHistory setEnabled:!account->allowIncomingFromUnknown()];
    [allowContacts setEnabled:!account->allowIncomingFromUnknown()];

    [upnpButton setState:account->isUpnpEnabled()];
    [userAgentButton setState:account->hasCustomUserAgent()];
    [userAgentTextField setEnabled:account->hasCustomUserAgent()];

    [autoAnswerButton setState:account->isAutoAnswer()];
    [userAgentTextField setStringValue:account->userAgent().toNSString()];

    [bootstrapField setStringValue:account->hostname().toNSString()];

    if([account->username().toNSString() isEqualToString:@""])
        [hashField setStringValue:NSLocalizedString(@"Reopen account to see your hash",
                                                    @"Show advice to user")];
    else
        [hashField setStringValue:account->username().toNSString()];

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

- (IBAction)toggleAllowFromUnknown:(id)sender {
    [self currentAccount]->setAllowIncomingFromUnknown([sender state] == NSOnState);
    [allowHistory setEnabled:![sender state] == NSOnState];
    [allowContacts setEnabled:![sender state] == NSOnState];
}
- (IBAction)toggleAllowFromHistory:(id)sender {
    [self currentAccount]->setAllowIncomingFromHistory([sender state] == NSOnState);
}
- (IBAction)toggleAllowFromContacts:(id)sender {
    [self currentAccount]->setAllowIncomingFromContact([sender state] == NSOnState);
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
            [self currentAccount]->setDisplayName([[textField stringValue] UTF8String]);
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
