/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *  Author: Anthony Léonard <anthony.leonard@savoirfairelinux.com>
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

#import "PasswordChangeWC.h"
#import <api/lrc.h>
#import <api/account.h>
#import <api/newaccountmodel.h>

@implementation PasswordChangeWC
{
    __unsafe_unretained IBOutlet NSSecureTextField *oldPassword;
    __unsafe_unretained IBOutlet NSTextField *oldPasswordTitle;
    __unsafe_unretained IBOutlet NSSecureTextField *newPassword;
    __unsafe_unretained IBOutlet NSSecureTextField *repeatedPassword;
    __unsafe_unretained IBOutlet NSLayoutConstraint *newPasswordTopConstraint;

    __unsafe_unretained IBOutlet NSImageView *repeatPasswordValid;

    __unsafe_unretained IBOutlet NSButton *acceptButton;

    IBOutlet NSPopover *wrongPasswordPopover;
}

@synthesize accountModel;

-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil accountmodel:(lrc::api::NewAccountModel*) accountModel
{
    if (self = [self initWithWindowNibName:nibNameOrNil])
    {
        self.accountModel= accountModel;
    }
    return self;
}

-(void)windowDidLoad
{
    [super windowDidLoad];
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    BOOL hasPassword = accountProperties.archiveHasPassword;
    [oldPassword setHidden: !hasPassword];
    [oldPasswordTitle setHidden: !hasPassword];
    newPasswordTopConstraint.constant = hasPassword ? 15.0 : -oldPasswordTitle.frame.size.height;
}

-(IBAction)accept:(id)sender
{
    if (self.accountModel->changeAccountPassword(self.selectedAccountID, [[oldPassword stringValue] UTF8String], [[newPassword stringValue] UTF8String])) {
        lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
        BOOL haspassword = ![[newPassword stringValue] isEqualToString:@""];
        accountProperties.archiveHasPassword = haspassword;
        self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
        [self.delegate paswordCreatedWithSuccess: haspassword];
        [self close];
    } else {
        [oldPassword setStringValue:@""];
        [oldPassword setPlaceholderString:@"Enter your old password"];
        [wrongPasswordPopover showRelativeToRect:oldPassword.visibleRect ofView:oldPassword preferredEdge:NSMinYEdge];
    }
}

-(IBAction)cancel:(id)sender
{
    [self close];
}

-(void) close {
    [NSApp endSheet:self.window];
    [self.window orderOut:self];
}

#pragma mark - NSTextFieldDelegate methods

-(void)controlTextDidChange:(NSNotification *)obj
{
    if ([[newPassword stringValue] isEqualToString: [repeatedPassword stringValue]]) {
        [repeatPasswordValid setHidden:NO];
        [acceptButton setEnabled:YES];
    } else {
        [repeatPasswordValid setHidden:YES];
        [acceptButton setEnabled:NO];
    }
}

@end
