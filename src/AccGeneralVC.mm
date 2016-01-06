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


#import "AccGeneralVC.h"

#import <accountmodel.h>
#import <protocolmodel.h>
#import <qitemselectionmodel.h>

@interface AccGeneralVC ()

@property (assign) IBOutlet NSView *boxingAccount;
@property (assign) IBOutlet NSView *boxingParameters;
@property (assign) IBOutlet NSView *boxingCommon;

@property (assign) IBOutlet NSTextField *aliasTextField;
@property (assign) IBOutlet NSTextField *typeLabel;

@property (assign) IBOutlet NSTextField *serverHostTextField;
@property (assign) IBOutlet NSTextField *usernameTextField;
@property (assign) IBOutlet NSSecureTextField *passwordTextField;
@property (strong) NSTextField *clearTextField;

@property (assign) IBOutlet NSButton *upnpButton;
@property (assign) IBOutlet NSButton *autoAnswerButton;
@property (assign) IBOutlet NSButton *userAgentButton;

@property (assign) IBOutlet NSTextField *userAgentTextField;

@end

@implementation AccGeneralVC
@synthesize typeLabel;
@synthesize boxingAccount;
@synthesize boxingParameters;
@synthesize boxingCommon;
@synthesize aliasTextField;
@synthesize serverHostTextField;
@synthesize usernameTextField;
@synthesize passwordTextField;
@synthesize clearTextField;
@synthesize upnpButton;
@synthesize autoAnswerButton;
@synthesize userAgentButton;
@synthesize userAgentTextField;

- (void)awakeFromNib
{
    NSLog(@"INIT General VC");
    [aliasTextField setTag:ALIAS_TAG];
    [serverHostTextField setTag:HOSTNAME_TAG];
    [usernameTextField setTag:USERNAME_TAG];
    [passwordTextField setTag:PASSWORD_TAG];
    [userAgentTextField setTag:USERAGENT_TAG];

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

- (void)loadAccount
{
    auto account = [self currentAccount];

    if([account->alias().toNSString() isEqualToString:@"IP2IP"]) {
        [boxingAccount.subviews setValue:@YES forKeyPath:@"hidden"];
        [boxingParameters.subviews setValue:@YES forKeyPath:@"hidden"];

        NSLog(@"IP@IP");
        // Put visible items at top of the frame
        [boxingCommon setFrameOrigin:NSMakePoint(boxingAccount.frame.origin.x,
                                                boxingAccount.frame.origin.y - 40)];
        [boxingCommon setNeedsDisplay:YES];

    } else {
        [boxingAccount.subviews setValue:@NO forKeyPath:@"hidden"];
        [boxingParameters.subviews setValue:@NO forKeyPath:@"hidden"];

        [self.aliasTextField setStringValue:account->alias().toNSString()];
        [self.serverHostTextField setStringValue:account->hostname().toNSString()];
        [self.usernameTextField setStringValue:account->username().toNSString()];
        [self.passwordTextField setStringValue:account->password().toNSString()];
        [self.clearTextField setStringValue:account->password().toNSString()];
    }

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

    [upnpButton setState:[self currentAccount]->isUpnpEnabled()];
    [userAgentButton setState:[self currentAccount]->hasCustomUserAgent()];
    [userAgentTextField setEnabled:[self currentAccount]->hasCustomUserAgent()];
    [self.autoAnswerButton setState:[self currentAccount]->isAutoAnswer()];
    [self.userAgentTextField setStringValue:account->userAgent().toNSString()];
}

- (IBAction)tryRegistration:(id)sender {
    [self currentAccount] << Account::EditAction::SAVE;
}

- (IBAction)showPassword:(NSButton *)sender {
    if (sender.state == NSOnState) {
        clearTextField = [[NSTextField alloc] initWithFrame:passwordTextField.frame];
        [clearTextField setTag:passwordTextField.tag];
        [clearTextField setDelegate:self];
        [clearTextField setBounds:passwordTextField.bounds];
        [clearTextField setStringValue:passwordTextField.stringValue];
        [clearTextField becomeFirstResponder];
        [boxingParameters addSubview:clearTextField];
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
        case ALIAS_TAG:
            [self currentAccount]->setAlias([[textField stringValue] UTF8String]);
            [self currentAccount]->setDisplayName([[textField stringValue] UTF8String]);
            break;
        case HOSTNAME_TAG:
            [self currentAccount]->setHostname([[textField stringValue] UTF8String]);
            break;
        case USERNAME_TAG:
            [self currentAccount]->setUsername([[textField stringValue] UTF8String]);
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
