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
#import "utils.h"

@interface RingWizardLinkAccountVC ()

@end

@implementation RingWizardLinkAccountVC {
    __unsafe_unretained IBOutlet NSView* initialContainer;
    __unsafe_unretained IBOutlet NSView* firstStepContainer;

    __unsafe_unretained IBOutlet NSView* loadingContainer;
    __unsafe_unretained IBOutlet NSProgressIndicator* progressBar;

    __unsafe_unretained IBOutlet NSView* errorContainer;

    __unsafe_unretained IBOutlet NSTextField* pinTextField;
    __unsafe_unretained IBOutlet NSButton* fileButton;
    __unsafe_unretained IBOutlet NSSecureTextField* passwordTextField;

    __unsafe_unretained IBOutlet NSButton* linkButton;
    NSString *fileButtonTitleBackup;

    Account* accountToCreate;
    NSURL* backupFile;
    NSTimer* errorTimer;
    QMetaObject::Connection stateChanged;
}

- (IBAction)goToStepTwo:(id)sender
{
    [self disconnectCallback];
    [firstStepContainer setHidden:YES];
    [initialContainer setHidden:NO];
    [loadingContainer setHidden:YES];
    [errorContainer setHidden:YES];
}

- (IBAction)goToStepOne:(id)sender
{
    [firstStepContainer setHidden:NO];
    [initialContainer setHidden:YES];
    [loadingContainer setHidden:YES];
    [errorContainer setHidden:YES];
    [fileButton setTitle:fileButtonTitleBackup];
    backupFile = nil;
    [pinTextField setStringValue:@""];
    [pinTextField setEnabled:YES];
    [linkButton setEnabled:NO];
    [passwordTextField setStringValue:@""];
}

- (void)show
{
    [firstStepContainer setHidden:NO];
    [initialContainer setHidden:YES];
    [loadingContainer setHidden:YES];
    [errorContainer setHidden:YES];
    fileButtonTitleBackup = [fileButton title];
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
        profile->save();
    }
    accountToCreate = AccountModel::instance().add(QString::fromNSString(NSFullUserName()), Account::Protocol::RING);
    if (backupFile == nil)
        accountToCreate->setArchivePin(QString::fromNSString(self.pinValue));
    else
        accountToCreate->setArchivePath(QString::fromLocal8Bit([backupFile fileSystemRepresentation]));
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
    [self deleteAccount];
    [self goToStepOne:sender];
}

- (IBAction)pickBackupFile:(id)sender
{
    NSOpenPanel* filePicker = [NSOpenPanel openPanel];
    [filePicker setCanChooseFiles:YES];
    [filePicker setCanChooseDirectories:NO];
    [filePicker setAllowsMultipleSelection:NO];

    if ([filePicker runModal] == NSFileHandlingPanelOKButton) {
        if ([[filePicker URLs] count] == 1) {
            backupFile = [[filePicker URLs] objectAtIndex:0];
            [fileButton setTitle:[backupFile lastPathComponent]];
            [pinTextField setEnabled:NO];
            [pinTextField setStringValue:@""];
            [linkButton setEnabled:YES];
        }
    }
}

/**
 * Set default values for preferences
 */
- (void)registerDefaultPreferences
{
    if (!appSandboxed()) {
        // enable AutoStartup
        LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
        if (loginItemsRef == nil) return;
        CFURLRef appUrl = (__bridge CFURLRef)[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
        LSSharedFileListItemRef itemRef = LSSharedFileListInsertItemURL(loginItemsRef, kLSSharedFileListItemLast, NULL, NULL, appUrl, NULL, NULL);
        if (itemRef) CFRelease(itemRef);
    }

    // enable Notifications
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:Preferences::Notifications];
}

- (void)saveAccount
{
    accountToCreate->setUpnpEnabled(YES); // Always active upnp
    accountToCreate << Account::EditAction::SAVE;
}

- (void)deleteAccount
{
    if(auto account = AccountModel::instance().getById(accountToCreate->id())) {
        AccountModel::instance().remove(accountToCreate);
        AccountModel::instance().save();
    }
}

- (void)disconnectCallback
{
    [errorTimer invalidate];
    QObject::disconnect(stateChanged);
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
