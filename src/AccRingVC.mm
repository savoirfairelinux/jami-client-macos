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
#import "AccRingVC.h"

#import <accountmodel.h>
#import <qitemselectionmodel.h>

@interface AccRingVC ()

@property (assign) IBOutlet NSTextField *aliasTextField;
@property (assign) IBOutlet NSTextField *bootstrapField;
@property (assign) IBOutlet NSTextField *blockchainField;
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
@synthesize bootstrapField;
@synthesize hashField;
@synthesize aliasTextField;
@synthesize blockchainField;
@synthesize upnpButton;
@synthesize autoAnswerButton;
@synthesize userAgentButton;
@synthesize userAgentTextField;
@synthesize allowContacts, allowHistory, allowUnknown;

typedef NS_ENUM(NSInteger, TagViews) {
    ALIAS = 0,
    HOSTNAME,
    USERAGENT,
    BLOCKCHAIN,
};

- (void)awakeFromNib
{
    NSLog(@"INIT Ring VC");
    [aliasTextField setTag:TagViews::ALIAS];
    [userAgentTextField setTag:TagViews::USERAGENT];
    [bootstrapField setTag:TagViews::HOSTNAME];
    [blockchainField setTag:TagViews::BLOCKCHAIN];

    QObject::connect(AccountModel::instance().selectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {
                         if(!current.isValid())
                             return;
                         [self loadAccount];
                     });
}

- (void)loadAccount
{
    auto account = AccountModel::instance().selectedAccount();

    [self.aliasTextField setStringValue:account->alias().toNSString()];

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
    [blockchainField setStringValue:account->nameServiceURL().toNSString()];

    if([account->username().toNSString() isEqualToString:@""])
        [hashField setStringValue:NSLocalizedString(@"Reopen account to see your hash",
                                                    @"Show advice to user")];
    else
        [hashField setStringValue:account->username().toNSString()];

}

- (IBAction)toggleUpnp:(NSButton *)sender {
    AccountModel::instance().selectedAccount()->setUpnpEnabled([sender state] == NSOnState);
}

- (IBAction)toggleAutoAnswer:(NSButton *)sender {
    AccountModel::instance().selectedAccount()->setAutoAnswer([sender state] == NSOnState);
}

- (IBAction)toggleCustomAgent:(NSButton *)sender {
    [self.userAgentTextField setEnabled:[sender state] == NSOnState];
    AccountModel::instance().selectedAccount()->setHasCustomUserAgent([sender state] == NSOnState);
}

- (IBAction)toggleAllowFromUnknown:(id)sender {
    AccountModel::instance().selectedAccount()->setAllowIncomingFromUnknown([sender state] == NSOnState);
    [allowHistory setEnabled:![sender state] == NSOnState];
    [allowContacts setEnabled:![sender state] == NSOnState];
}
- (IBAction)toggleAllowFromHistory:(id)sender {
    AccountModel::instance().selectedAccount()->setAllowIncomingFromHistory([sender state] == NSOnState);
}
- (IBAction)toggleAllowFromContacts:(id)sender {
    AccountModel::instance().selectedAccount()->setAllowIncomingFromContact([sender state] == NSOnState);
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
        case TagViews::USERAGENT:
            AccountModel::instance().selectedAccount()->setUserAgent([[textField stringValue] UTF8String]);
            break;
        case TagViews::BLOCKCHAIN:
            AccountModel::instance().selectedAccount()->setNameServiceURL([[textField stringValue] UTF8String]);
            break;
        default:
            break;
    }
}

@end
