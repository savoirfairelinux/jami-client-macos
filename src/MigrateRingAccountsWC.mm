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
#import <api/newaccountmodel.h>

//RING
#import "views/ITProgressIndicator.h"

@interface MigrateRingAccountsWC() <NSTextFieldDelegate>{
    __unsafe_unretained IBOutlet NSSecureTextField* passwordField;
    __unsafe_unretained IBOutlet NSSecureTextField* passwordConfirmField;
    __unsafe_unretained IBOutlet NSTextField* infoField;
    __unsafe_unretained IBOutlet NSTextField* errorField;
    __unsafe_unretained IBOutlet ITProgressIndicator* progressIndicator;
    __unsafe_unretained IBOutlet NSImageView* profileImage;
    __unsafe_unretained IBOutlet NSTextField* alias;
}

- (IBAction)onClickComplete:(id)sender;
@end

@implementation MigrateRingAccountsWC {
    struct {
        unsigned int didComplete:1;
        unsigned int didCompleteWithError:1;
    } delegateRespondsTo;
}

NSTimer* errorTimer;
QMetaObject::Connection stateChanged;

@synthesize accountModel, accountToMigrate;

#pragma mark - Initialise / Setters
- (id)initWithDelegate:(id <MigrateRingAccountsDelegate>) del actionCode:(NSInteger) code
{
    return [super initWithWindowNibName:@"MigrateRingAccountsWindow" delegate:del actionCode:code];
}

- (void) awakeFromNib{
    [self setInfoMessageForAccount];
    [profileImage setWantsLayer: YES];
    profileImage.layer.cornerRadius = 40;
    profileImage.layer.masksToBounds = YES;
}

- (void)setDelegate:(id <MigrateRingAccountsDelegate>)aDelegate
{
    if (super.delegate != aDelegate) {
        [super setDelegate: aDelegate];
        delegateRespondsTo.didCompleteWithError = [self.delegate respondsToSelector:@selector(migrationDidCompleteWithError)];
        delegateRespondsTo.didComplete = [self.delegate respondsToSelector:@selector(migrationDidComplete)];
    }
}

- (void) setInfoMessageForAccount
{
    const lrc::api::account::Info& accountInfo = self.accountModel->getAccountInfo(accountToMigrate);
    NSData *imageData = [[NSData alloc]
                         initWithBase64EncodedString: @(accountInfo.profileInfo.avatar.c_str())
                         options:NSDataBase64DecodingIgnoreUnknownCharacters];
    NSImage *image = [[NSImage alloc] initWithData:imageData];
    if (image) {
        profileImage.image = image;
    } else {
        profileImage.image = [NSImage imageNamed:@"default_avatar_overlay.png"];
        profileImage.layer.backgroundColor = [[NSColor grayColor] CGColor];
    }
    alias.stringValue = @(accountInfo.profileInfo.alias.c_str());

    NSMutableAttributedString* infoMessage = [[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"This account needs to be migrated",@"Text shown to the user")];
    [infoMessage appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
    const CGFloat fontSize = 13;
    NSDictionary *attrs = @{
                            NSFontAttributeName:[NSFont boldSystemFontOfSize:fontSize]
                            };
    auto registredName = accountInfo.registeredName;
    if(!registredName.empty()) {
        [infoMessage appendAttributedString:[[NSAttributedString alloc] initWithString:NSLocalizedString(@"Registered name: ",@"Text shown to the user")
                                                                            attributes:attrs]];
        [infoMessage appendAttributedString:[[NSAttributedString alloc] initWithString:@(registredName.c_str()) attributes:attrs]];
    } else if(!accountInfo.profileInfo.uri.empty()) {
        [infoMessage appendAttributedString:[[NSAttributedString alloc] initWithString:NSLocalizedString(@"ID: ",@"Text shown to the user")
                                                                            attributes:attrs]];
        [infoMessage appendAttributedString:[[NSAttributedString alloc] initWithString:@(accountInfo.profileInfo.uri.c_str()) attributes:attrs]];

    }
    [infoMessage appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
    [infoMessage appendAttributedString:[[NSAttributedString alloc] initWithString:NSLocalizedString(@"To proceed with the migration, you need to enter a password that was used for this account.",@"Text shown to the user")]];
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
    self.accountModel->removeAccount(accountToMigrate);
    [self cancelPressed:sender];
    if (delegateRespondsTo.didComplete)
        [((id<MigrateRingAccountsDelegate>)self.delegate) migrationDidComplete];
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
        stateChanged = QObject::connect(self.accountModel,
                                        &lrc::api::NewAccountModel::migrationEnded,
                                        [self](const std::string& accountId, bool ok) {
                                            if (accountToMigrate != accountId) {
                                                return;
                                            }
                                            if (ok) {
                                                [self didComplete];
                                            } else {
                                                [self didCompleteWithError];
                                            }
                                        });
        lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(accountToMigrate);
        accountProperties.archivePassword = [self.password UTF8String];
        self.accountModel->setAccountConfig(accountToMigrate, accountProperties);
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
