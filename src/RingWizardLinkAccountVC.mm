/*
 *  Copyright (C) 2015-2016 Savoir-faire Linux Inc.
 *  Author: Loïc Siret <loic.siret@savoirfairelinux.com>
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

#import "RingWizardLinkAccountVC.h"
//Cocoa
#import <AddressBook/AddressBook.h>
#import <Quartz/Quartz.h>

//Qt
#import <QUrl>
#import <QPixmap>

//LRC
#import <accountmodel.h>
#import <protocolmodel.h>
#import <profilemodel.h>
#import <QItemSelectionModel>
#import <account.h>
#import <certificate.h>
#import <profilemodel.h>
#import <profile.h>
#import <person.h>

#import "Constants.h"
#import "views/NSImage+Extensions.h"

@interface RingWizardLinkAccountVC ()

@end

@implementation RingWizardLinkAccountVC {
    __unsafe_unretained IBOutlet NSView* initialContainer;
    __unsafe_unretained IBOutlet NSTextField* pinField;
    __unsafe_unretained IBOutlet NSSecureTextField* passwordField;
    __unsafe_unretained IBOutlet NSTextField* pinLabel;
    __unsafe_unretained IBOutlet NSTextField* passwordLabel;
    __unsafe_unretained IBOutlet NSButton* createButton;

    __unsafe_unretained IBOutlet NSView* loadingContainer;
    __unsafe_unretained IBOutlet NSProgressIndicator* progressBar;

    __unsafe_unretained IBOutlet NSView* errorContainer;

    Account* accountToCreate;
    NSTimer* errorTimer;
    QMetaObject::Connection stateChanged;
}

- (void)show
{
    [initialContainer setHidden:NO];
    [loadingContainer setHidden:YES];
    [errorContainer setHidden:YES];
}

- (void)showError
{
    [initialContainer setHidden:YES];
    [loadingContainer setHidden:YES];
    [errorContainer setHidden:NO];
}
- (void)showLoading
{
    [initialContainer setHidden:YES];
    [loadingContainer setHidden:NO];
    [progressBar startAnimation:nil];
    [errorContainer setHidden:YES];
}

- (IBAction)importRingAccount:(id)sender
{
    [self showLoading];
    if (auto profile = ProfileModel::instance().selectedProfile()) {
        profile->person()->setFormattedName([NSFullUserName() UTF8String]);
        auto defaultAvatar = [NSImage imageResize:[NSImage imageNamed:@"default_user_icon"] newSize:{100,100}];
        QPixmap pixMap;
        pixMap.loadFromData(QByteArray::fromNSData([defaultAvatar TIFFRepresentation]));
        profile->person()->setPhoto(QVariant(pixMap));
        profile->save();
    }
    accountToCreate = AccountModel::instance().add(QString::fromNSString(NSFullUserName()), Account::Protocol::RING);
    accountToCreate->setArchivePin(QString::fromNSString(self.pinValue));
    accountToCreate->setArchivePassword(QString::fromNSString(self.passwordValue));

    [self setCallback];

    [self performSelector:@selector(saveAccount) withObject:nil afterDelay:1];
    [self registerDefaultPreferences];
}

- (IBAction)dismissViewWithError:(id)sender
{
    [self.delegate didLinkAccountWithSuccess:NO];
}

- (IBAction)back:(id)sender
{
    [self show];
}

/**
 * Set default values for preferences
 */
- (void)registerDefaultPreferences
{
    // enable AutoStartup
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItemsRef == nil) return;
    CFURLRef appUrl = (__bridge CFURLRef)[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
    LSSharedFileListItemRef itemRef = LSSharedFileListInsertItemURL(loginItemsRef, kLSSharedFileListItemLast, NULL, NULL, appUrl, NULL, NULL);
    if (itemRef) CFRelease(itemRef);

    // enable Notifications
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:Preferences::Notifications];
}

- (void)saveAccount
{
    accountToCreate->setUpnpEnabled(YES); // Always active upnp
    accountToCreate << Account::EditAction::SAVE;
}

- (void)setCallback
{
    errorTimer = [NSTimer scheduledTimerWithTimeInterval:30
                                                  target:self
                                                selector:@selector(didLinkFailed) userInfo:nil
                                                 repeats:NO];

    stateChanged = QObject::connect(&AccountModel::instance(),
                                    &AccountModel::accountStateChanged,
                                    [=](Account *account, const Account::RegistrationState state) {
                                        switch(state){
                                            case Account::RegistrationState::READY:
                                            case Account::RegistrationState::TRYING:
                                            case Account::RegistrationState::UNREGISTERED:{
                                                accountToCreate<< Account::EditAction::RELOAD;
                                                QObject::disconnect(stateChanged);
                                                [errorTimer invalidate];
                                                [self.delegate didLinkAccountWithSuccess:YES];
                                                break;
                                            }
                                            case Account::RegistrationState::ERROR:
                                                QObject::disconnect(stateChanged);
                                                [errorTimer invalidate];
                                                [self showError];
                                                break;
                                            case Account::RegistrationState::INITIALIZING:
                                            case Account::RegistrationState::COUNT__:{
                                                //DO Nothing
                                                break;
                                            }
                                        }
                                    });
}


- (void)didLinkFailed
{
    [self showError];
}

@end
