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
#import <accountmodel.h>

@implementation PasswordChangeWC
{
    Account* account;
    __unsafe_unretained IBOutlet NSSecureTextField *oldPassword;
    __unsafe_unretained IBOutlet NSSecureTextField *newPassword;
    __unsafe_unretained IBOutlet NSSecureTextField *repeatedPassword;

    __unsafe_unretained IBOutlet NSImageView *repeatPasswordValid;

    __unsafe_unretained IBOutlet NSButton *acceptButton;

    IBOutlet NSPopover *wrongPasswordPopover;
}

-(id)initWithAccount:(Account*)acc
{
    account = acc;
    return [super initWithWindowNibName:@"PasswordChange"];
}

-(void)windowDidLoad
{
    [super windowDidLoad];
    if (account != nullptr) {
        const auto hasPassword = account->archiveHasPassword();

        [oldPassword setEnabled:hasPassword];
        [oldPassword setPlaceholderString:(hasPassword)?@"":@"Account has no password"];
    }
}

-(IBAction)accept:(id)sender
{
    if (account->changePassword(QString::fromNSString([oldPassword stringValue]), QString::fromNSString([newPassword stringValue])))
    {
        AccountModel::instance().save();
        [self close];
    } else {
        [oldPassword setStringValue:@""];
        [wrongPasswordPopover showRelativeToRect:oldPassword.visibleRect ofView:oldPassword preferredEdge:NSMinYEdge];
    }
}

-(IBAction)cancel:(id)sender
{
    [self close];
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
