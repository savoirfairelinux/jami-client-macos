/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
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

#import "RegisterNameWC.h"


//Cocoa

//LRC
#import <accountmodel.h>
#import <QItemSelectionModel>
#import <account.h>

#import "AppDelegate.h"

@interface RegisterNameWC ()
@end

@implementation RegisterNameWC
{
    __unsafe_unretained IBOutlet NSTextField* registeredNameField;
    __unsafe_unretained IBOutlet NSSecureTextField* passwordField;
    __unsafe_unretained IBOutlet NSImageView* ivLookupResult;
    __unsafe_unretained IBOutlet NSProgressIndicator* indicatorLookupResult;

    __unsafe_unretained IBOutlet NSProgressIndicator *registrationProgress;

    QMetaObject::Connection registrationEnded;
    QMetaObject::Connection registeredNameFound;

    BOOL lookupQueued;
    NSString* usernameWaitingForLookupResult;
}

NSInteger const BLOCKCHAIN_NAME_TAG             = 2;

- (id)initWithDelegate:(id <LoadingWCDelegate>) del
{
    return [self initWithDelegate:del actionCode:0];
}

- (id)initWithDelegate:(id <RegisterNameDelegate>) del actionCode:(NSInteger) code
{
    return [super initWithWindowNibName:@"RegisterNameWindow" delegate:del actionCode:code];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [registeredNameField setTag:BLOCKCHAIN_NAME_TAG];
    self.registeredName = @"";
    [ivLookupResult setHidden:YES];
    [indicatorLookupResult setHidden:YES];
}

#pragma mark - Input validation

- (BOOL)isPasswordValid
{
    return self.password.length >= 6;
}

#pragma mark - Username validation delegate methods

- (BOOL)userNameAvailable
{
    return (self.registeredName.length > 0 && self.isUserNameAvailable);
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
                                           [=] ( const Account* account, NameDirectory::LookupStatus status,  const QString& address, const QString& name) {
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
    BOOL result = NameDirectory::instance().lookupName(nullptr, QString(), QString::fromNSString(usernameWaitingForLookupResult));

}

- (void)controlTextDidChange:(NSNotification *)notif
{
    NSTextField* textField = [notif object];
    if (textField.tag != BLOCKCHAIN_NAME_TAG) {
        return;
    }
    NSString* alias = textField.stringValue;

    [self showLookupSpinner];
    [self onUsernameAvailabilityChangedWithNewAvailability:NO];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self performSelector:@selector(lookUp:) withObject:alias afterDelay:0.5];
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
    [registrationProgress startAnimation:nil];
    [self showLoading];
    [self setCallback];

    self.isUserNameAvailable = AccountModel::instance().selectedAccount()->registerName(QString::fromNSString(self.password),
                                                                                        QString::fromNSString(self.registeredName));
    if (!self.isUserNameAvailable) {
        NSLog(@"Could not initialize registerName operation");
        QObject::disconnect(registrationEnded);
    }
}

- (void)setCallback
{
    QObject::disconnect(registrationEnded);
    registrationEnded = QObject::connect(AccountModel::instance().selectedAccount(),
                                         &Account::nameRegistrationEnded,
                                         [=] (NameDirectory::RegisterNameStatus status,  const QString& name)
                                         {
                                             QObject::disconnect(registrationEnded);
                                             switch(status) {
                                                 case NameDirectory::RegisterNameStatus::WRONG_PASSWORD:
                                                 case NameDirectory::RegisterNameStatus::ALREADY_TAKEN:
                                                 case NameDirectory::RegisterNameStatus::NETWORK_ERROR:
                                                     [self showError];
                                                     break;
                                                 case NameDirectory::RegisterNameStatus::SUCCESS:
                                                     [self.delegate didRegisterNameWithSuccess];
                                                     // Artificial refresh of the model to update the welcome view
                                                     Q_EMIT AccountModel::instance().dataChanged(QModelIndex(), QModelIndex());
                                                     break;
                                             }
                                         });
}


+ (NSSet *)keyPathsForValuesAffectingUserNameAvailableORNotBlockchain
{
    return [NSSet setWithObjects: NSStringFromSelector(@selector(isUserNameAvailable)), nil];
}

+ (NSSet *)keyPathsForValuesAffectingIsPasswordValid
{
    return [NSSet setWithObjects:@"password", nil];
}

@end
