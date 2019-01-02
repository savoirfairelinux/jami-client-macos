/*
 *  Copyright (C) 2016-2019 Savoir-faire Linux Inc.
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

#import "MigrateRingAccountsWC.h"

//LRC
#import <accountmodel.h>

//RING
#import "views/ITProgressIndicator.h"

@interface MigrateRingAccountsWC() <NSTextFieldDelegate>{
    __unsafe_unretained IBOutlet NSSecureTextField* passwordField;
    __unsafe_unretained IBOutlet NSSecureTextField* passwordConfirmField;
    __unsafe_unretained IBOutlet NSTextField* infoField;
    __unsafe_unretained IBOutlet NSTextField* errorField;
    __unsafe_unretained IBOutlet ITProgressIndicator* progressIndicator;
}

- (IBAction)onClickComplete:(id)sender;
@end

@implementation MigrateRingAccountsWC{
    struct {
        unsigned int didComplete:1;
        unsigned int didCompleteWithError:1;
    } delegateRespondsTo;
}

NSTimer* errorTimer;
QMetaObject::Connection stateChanged;

#pragma mark - Initialise / Setters
- (id)initWithDelegate:(id <MigrateRingAccountsDelegate>) del actionCode:(NSInteger) code
{
    return [super initWithWindowNibName:@"MigrateRingAccountsWindow" delegate:del actionCode:code];
}

- (void) awakeFromNib{
    [self setInfoMessageForAccount];
}

- (void)setDelegate:(id <MigrateRingAccountsDelegate>)aDelegate
{
    if (super.delegate != aDelegate) {
        [super setDelegate: aDelegate];
        delegateRespondsTo.didCompleteWithError = [self.delegate respondsToSelector:@selector(migrationDidCompleteWithError)];
        delegateRespondsTo.didComplete = [self.delegate respondsToSelector:@selector(migrationDidComplete)];
    }
}

- (void) setAccount:(Account *)aAccount
{
    _account = aAccount;
}

- (void) setInfoMessageForAccount
{
    NSMutableAttributedString* infoMessage = [[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"The following account needs to be migrated to the new Ring account format:",@"Text shown to the user")];
    [infoMessage appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
    [infoMessage appendAttributedString:[[NSAttributedString alloc] initWithString:NSLocalizedString(@"Alias : ",@"Text shown to the user")]];
    const CGFloat fontSize = 13;
    NSDictionary *attrs = @{
                            NSFontAttributeName:[NSFont boldSystemFontOfSize:fontSize]
                            };
    [infoMessage appendAttributedString:[[NSAttributedString alloc] initWithString:self.account->alias().toNSString() attributes:attrs]];
    [infoMessage appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
    [infoMessage appendAttributedString:[[NSAttributedString alloc] initWithString:NSLocalizedString(@"RingID : ",@"Text shown to the user")]];
    [infoMessage appendAttributedString:[[NSAttributedString alloc] initWithString:self.account->username().toNSString() attributes:attrs]];
    [infoMessage appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
    [infoMessage appendAttributedString:[[NSAttributedString alloc] initWithString:NSLocalizedString(@"To proceed with the migration, you must choose a password for your account. This password will be used to encrypt your master key. It will be required for adding new devices to your Ring account. If you are not ready to choose a password, you may close Ring and resume the migration later.",@"Text shown to the user")]];
    [infoField setAttributedStringValue:infoMessage];
}


- (void) showError:(NSString*) errorMessage
{
    [errorField setStringValue:errorMessage];
    [super showError];
}

- (void)showLoading
{
    [progressIndicator setNumberOfLines:30];
    [progressIndicator setWidthOfLine:2];
    [progressIndicator setLengthOfLine:5];
    [progressIndicator setInnerMargin:20];
    [super showLoading];
}

#pragma mark - Events Handlers
- (IBAction)removeAccount:(id)sender
{
    AccountModel::instance().remove(self.account);
    AccountModel::instance().save();
    [self cancelPressed:sender];
}

- (IBAction)startMigration:(NSButton *)sender
{
    if (![self validatePasswords]) {
        [self showError:NSLocalizedString(@"Password and confirmation mismatch.",@"Text show to the user when password didn't match")];
    } else {
        [self showLoading];
        errorTimer = [NSTimer scheduledTimerWithTimeInterval:30
                                                      target:self
                                                    selector:@selector(didCompleteWithError) userInfo:nil
                                                     repeats:NO];
        stateChanged = QObject::connect(
                                        self.account, &Account::stateChanged,
                                        [=](Account::RegistrationState state){
                                            switch(state){
                                                case Account::RegistrationState::READY:
                                                case Account::RegistrationState::TRYING:
                                                case Account::RegistrationState::UNREGISTERED:{
                                                    self.account<< Account::EditAction::RELOAD;
                                                    QObject::disconnect(stateChanged);
                                                    [self didComplete];
                                                    break;
                                                }
                                                case Account::RegistrationState::ERROR:
                                                case Account::RegistrationState::INITIALIZING:
                                                case Account::RegistrationState::COUNT__:{
                                                    //DO Nothing
                                                    break;
                                                }
                                            }
                                        });
        self.account->setArchivePassword(QString::fromNSString(self.password));
        self.account->performAction(Account::EditAction::SAVE);
    }
}

- (BOOL)validatePasswords
{
    BOOL result = (self.password.length != 0 && [self.password isEqualToString:self.passwordConfirmation]);
    NSLog(@"ValidatesPasswords : %s", result ? "true" : "false");
    return result;
}

+ (NSSet *)keyPathsForValuesAffectingValidatePasswords
{
    return [NSSet setWithObjects:@"password", @"passwordConfirmation", nil];
}


#pragma mark - Delegates
- (void)didComplete
{
    [errorTimer invalidate];
    errorTimer = nil;
    [self showFinal];
}

- (void)onClickComplete:(id)sender
{
    [self cancelPressed:sender];
    if (delegateRespondsTo.didComplete)
        [((id<MigrateRingAccountsDelegate>)self.delegate) migrationDidComplete];
}


- (void)didCompleteWithError
{
    [self showError:NSLocalizedString(@"Failed to migrate your account. You can retry by pressing Ok or delete your account.",@"Error message shown to user when it is impossible to migrate account")];
}


@end
