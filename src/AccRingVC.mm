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

//Cocoa
#import <Quartz/Quartz.h>

#import <accountmodel.h>
#import <qitemselectionmodel.h>

@interface AccRingVC ()

@property (unsafe_unretained) IBOutlet NSButton* photoView;
@property (assign) IBOutlet NSTextField *aliasTextField;
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
@synthesize photoView;
@synthesize bootstrapField;
@synthesize hashField;
@synthesize aliasTextField;
@synthesize upnpButton;
@synthesize autoAnswerButton;
@synthesize userAgentButton;
@synthesize userAgentTextField;
@synthesize allowContacts, allowHistory, allowUnknown;

// Tags for views
NSInteger const ALIAS_TAG       =   0;
NSInteger const HOSTNAME_TAG    =   1;
NSInteger const USERAGENT_TAG   =   4;

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

    [photoView setWantsLayer: YES];
    photoView.layer.cornerRadius = photoView.frame.size.width / 2;
    photoView.layer.masksToBounds = YES;
    [photoView setImage:[NSImage imageNamed:@"default_user_icon"]];
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

    if([account->username().toNSString() isEqualToString:@""])
        [hashField setStringValue:NSLocalizedString(@"Reopen account to see your hash",
                                                    @"Show advice to user")];
    else
        [hashField setStringValue:account->username().toNSString()];

}

- (IBAction) editPhoto:(id)sender {
    IKPictureTaker* pictureTaker = [IKPictureTaker pictureTaker];
    [pictureTaker beginPictureTakerSheetForWindow:self.view.window
                                     withDelegate:self
                                   didEndSelector:@selector(pictureTakerDidEnd:returnCode:contextInfo:)
                                      contextInfo:nil];
}

- (void) pictureTakerDidEnd:(IKPictureTaker *) picker
                 returnCode:(NSInteger) code
                contextInfo:(void*) contextInfo
{
    auto outputImage = [picker outputImage];
    if (outputImage == nil) {
        [photoView setImage:[NSImage imageNamed:@"default_user_icon"]];
    } else
        [photoView setImage:outputImage];
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

- (IBAction)toggleAllowFromUnknown:(NSButton*) sender {
    AccountModel::instance().selectedAccount()->setAllowIncomingFromUnknown([sender state] == NSOnState);
    [allowHistory setEnabled:![sender state] == NSOnState];
    [allowContacts setEnabled:![sender state] == NSOnState];
}

- (IBAction)toggleAllowFromHistory:(NSButton*) sender {
    AccountModel::instance().selectedAccount()->setAllowIncomingFromHistory([sender state] == NSOnState);
}

- (IBAction)toggleAllowFromContacts:(NSButton*) sender {
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
        case ALIAS_TAG:
            AccountModel::instance().selectedAccount()->setAlias([[textField stringValue] UTF8String]);
            AccountModel::instance().selectedAccount()->setDisplayName([[textField stringValue] UTF8String]);
            break;
        case HOSTNAME_TAG:
            AccountModel::instance().selectedAccount()->setHostname([[textField stringValue] UTF8String]);
            break;
        case USERAGENT_TAG:
            AccountModel::instance().selectedAccount()->setUserAgent([[textField stringValue] UTF8String]);
            break;
        default:
            break;
    }
}

@end
