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

#import <Cocoa/Cocoa.h>

#import "RegisterNameWC.h"
#import "AppDelegate.h"

//LRC
#import <api/lrc.h>
#import <api/newaccountmodel.h>
#import <api/account.h>
#import <namedirectory.h>

@implementation RegisterNameWC
{
    __unsafe_unretained IBOutlet NSTextField* registeredNameField;
    __unsafe_unretained IBOutlet NSSecureTextField* passwordField;
    __unsafe_unretained IBOutlet NSTextField* passwordLabel;
    __unsafe_unretained IBOutlet NSLayoutConstraint* passwordTopConstraint;
    __unsafe_unretained IBOutlet NSImageView* ivLookupResult;
    __unsafe_unretained IBOutlet NSProgressIndicator* indicatorLookupResult;

    __unsafe_unretained IBOutlet NSProgressIndicator *registrationProgress;

    QMetaObject::Connection registrationEnded;
    QMetaObject::Connection registeredNameFound;

    BOOL lookupQueued;
    BOOL needPassword;
    NSString* usernameWaitingForLookupResult;
}

NSInteger const BLOCKCHAIN_NAME_TAG             = 2;
NSInteger const PASSWORD_TAG             = 3;

@synthesize accountModel;

-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil accountmodel:(lrc::api::NewAccountModel*) accountModel
{
    if (self = [self initWithWindowNibName:nibNameOrNil])
    {
        self.accountModel= accountModel;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    auto accounts = self.accountModel->getAccountList();
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    needPassword = accountProperties.archiveHasPassword;
    [passwordField setHidden: !needPassword];
    [passwordLabel setHidden: !needPassword];
    passwordTopConstraint.constant = needPassword ? 20.0 : -20.0;
    [registeredNameField setTag:BLOCKCHAIN_NAME_TAG];
    [ivLookupResult setHidden:YES];
    [indicatorLookupResult setHidden:YES];
}

#pragma mark - Username validation delegate methods

- (BOOL)userNameAvailable
{
    return (registeredNameField.stringValue.length > 0 && self.isUserNameAvailable);
}

- (void)showLookUpAvailable:(BOOL)available andText:(NSString *)message
{
    [ivLookupResult setImage:[NSImage imageNamed:(available?@"ic_action_accept":@"ic_action_cancel")]] ;
    [ivLookupResult setHidden:NO];
    [ivLookupResult setToolTip:message];
}

- (void)onUsernameAvailabilityChangedWithNewAvailability:(BOOL)newAvailability
{
    self.isUserNameAvailable = newAvailability;

    self.couldRegister = needPassword ?
    self.isUserNameAvailable && [self.passwordString length] > 0 :
    self.isUserNameAvailable;
}

- (void)hideLookupSpinner
{
    [indicatorLookupResult setHidden:YES];
}

- (void)showLookupSpinner
{
    [ivLookupResult setHidden:YES];
    [indicatorLookupResult setHidden:NO];
    [indicatorLookupResult startAnimation:nil];
}

- (BOOL)lookupUserName
{
    [self showLookupSpinner];
    QObject::disconnect(registeredNameFound);
    registeredNameFound = QObject::connect(
                                           &NameDirectory::instance(),
                                           &NameDirectory::registeredNameFound,
                                           [=] (NameDirectory::LookupStatus status,
                                                const QString& address, const QString& name) {
                                               NSLog(@"Name lookup ended");
                                               lookupQueued = NO;
                                               //If this is the username we are waiting for, we can disconnect.
                                               if (name.compare(QString::fromNSString(usernameWaitingForLookupResult)) == 0) {
                                                   QObject::disconnect(registeredNameFound);
                                               } else {
                                                   //Keep waiting...
                                                   return;
                                               }

                                               //We may now stop the spinner
                                               [self hideLookupSpinner];

                                               BOOL isAvailable = NO;
                                               NSString* message;
                                               switch(status)
                                               {
                                                   case NameDirectory::LookupStatus::SUCCESS:
                                                   {
                                                       message = NSLocalizedString(@"The entered username is not available",
                                                                                   @"Text shown to user when his username is already registered");
                                                       isAvailable = NO;
                                                       break;
                                                   }
                                                   case NameDirectory::LookupStatus::NOT_FOUND:
                                                   {
                                                       message = NSLocalizedString(@"The entered username is available",
                                                                                   @"Text shown to user when his username is available to be registered");
                                                       isAvailable = YES;
                                                       break;
                                                   }
                                                   case NameDirectory::LookupStatus::INVALID_NAME:
                                                   {
                                                       message = NSLocalizedString(@"The entered username is invalid. It must have at least 3 characters and contain only lowercase alphanumeric characters.",
                                                                                   @"Text shown to user when his username is invalid to be registered");
                                                       isAvailable = NO;
                                                       break;
                                                   }
                                                   case NameDirectory::LookupStatus::ERROR:
                                                   default:
                                                   {
                                                       message = NSLocalizedString(@"Failed to perform lookup",
                                                                                   @"Text shown to user when an error occur at registration");
                                                       isAvailable = NO;
                                                       break;
                                                   }
                                               }
                                               [self showLookUpAvailable:isAvailable andText: message];
                                               [self onUsernameAvailabilityChangedWithNewAvailability:isAvailable];
                                           }
                                           );

    //Start the lookup in a second so that the UI dosen't seem to freeze
    BOOL result = NameDirectory::instance().lookupName(QString(), QString::fromNSString(usernameWaitingForLookupResult));
}

- (void)controlTextDidChange:(NSNotification *)notif
{
    NSTextField* textField = [notif object];
    if (textField.tag == BLOCKCHAIN_NAME_TAG) {
        NSString* alias = textField.stringValue;

        [self showLookupSpinner];
        [self onUsernameAvailabilityChangedWithNewAvailability:NO];
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
        [self performSelector:@selector(lookUp:) withObject:alias afterDelay:0.5];
    } else if (textField.tag == PASSWORD_TAG) {
        self.couldRegister = needPassword ?
        self.isUserNameAvailable && [self.passwordString length] > 0 :
        self.isUserNameAvailable;
    }
}

- (void) lookUp:(NSString*) name
{
    if (!lookupQueued) {
        usernameWaitingForLookupResult = name;
        lookupQueued = YES;
        [self lookupUserName];
    }
}

#pragma mark - Registration process

- (IBAction)registerUsername:(id)sender
{
    NSString *password = passwordField.stringValue;
    if((!password || [password length] == 0) && needPassword) {
        return;
    }
    [registrationProgress startAnimation:nil];
    [self showLoading];
    [self setCallback];

    self.isUserNameAvailable = self.accountModel->registerName(self.selectedAccountID,
                                                               [password UTF8String],
                                                               [registeredNameField.stringValue UTF8String]);
    if (!self.isUserNameAvailable) {
        NSLog(@"Could not initialize registerName operation");
        QObject::disconnect(registrationEnded);
    }
}

- (void)setCallback
{
    QObject::disconnect(registrationEnded);
    registrationEnded = QObject::connect(self.accountModel,
                                         &lrc::api::NewAccountModel::nameRegistrationEnded,
                                         [self] (const std::string& accountId, lrc::api::account::RegisterNameStatus status, const std::string& name) {
                                             if(accountId.compare(self.selectedAccountID) != 0) {
                                                 return;
                                             }
                                             switch(status)
                                             {
                                                 case lrc::api::account::RegisterNameStatus::SUCCESS: {
                                                     [self.delegate didRegisterName:  registeredNameField.stringValue withSuccess: YES];
                                                     break;
                                                 }
                                                 case lrc::api::account::RegisterNameStatus::INVALID_NAME:
                                                 case lrc::api::account::RegisterNameStatus::WRONG_PASSWORD:
                                                 case lrc::api::account::RegisterNameStatus::NETWORK_ERROR:
                                                 case lrc::api::account::RegisterNameStatus::ALREADY_TAKEN: {
                                                     [self showError];
                                                     break;
                                                 }
                                             }
                                             QObject::disconnect(registrationEnded);
                                         });
}


+ (NSSet *)keyPathsForValuesAffectingUserNameAvailableORNotBlockchain
{
    return [NSSet setWithObjects: NSStringFromSelector(@selector(isUserNameAvailable)), nil];
}


@end
