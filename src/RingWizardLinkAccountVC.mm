/*
 *  Copyright (C) 2015-2016 Savoir-faire Linux Inc.
 *  Author: Loïc Siret <loic.siret@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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
#import <api/lrc.h>
#import <api/newaccountmodel.h>

#import "Constants.h"
#import "views/NSImage+Extensions.h"
#import "utils.h"

@interface RingWizardLinkAccountVC ()

@end

@implementation RingWizardLinkAccountVC {
    __unsafe_unretained IBOutlet NSView* initialContainer;

    __unsafe_unretained IBOutlet NSView* loadingContainer;
    __unsafe_unretained IBOutlet NSProgressIndicator* progressBar;

    __unsafe_unretained IBOutlet NSView* errorContainer;

    __unsafe_unretained IBOutlet NSTextField* pinTextField;
    __unsafe_unretained IBOutlet NSButton* fileButton;
    __unsafe_unretained IBOutlet NSSecureTextField* passwordTextField;

    __unsafe_unretained IBOutlet NSButton* linkButton;
    __unsafe_unretained IBOutlet NSPopover* helpPINContainer;
    __unsafe_unretained IBOutlet NSPopover* helpArchiveFileContainer;
    __unsafe_unretained IBOutlet NSStackView* pinContainer;
    __unsafe_unretained IBOutlet NSStackView* filePathContainer;
    NSString *fileButtonTitleBackup;

    QMetaObject::Connection accountCreated;
    QMetaObject::Connection accountRemoved;
    QString accountToCreate;
}

@synthesize accountModel, backupFile;

-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil accountmodel:(lrc::api::NewAccountModel*) accountModel {
    if (self =  [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.accountModel = accountModel;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    [initialContainer setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    [loadingContainer setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    [errorContainer setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    fileButtonTitleBackup = NSLocalizedString(@"Select archive",
                                              @"export account button title");
}

- (void)showImportViewOfType:(IMPORT_TYPE)type
{
    [pinContainer setHidden: type == IMPORT_FROM_BACKUP];
    [filePathContainer setHidden: type == IMPORT_FROM_DEVICE];
    [self.delegate showView:initialContainer];
    [fileButton setTitle:fileButtonTitleBackup];
    backupFile = nil;
    [pinTextField setStringValue:@""];
    [pinTextField setEnabled:YES];
    [linkButton setEnabled:NO];
    self.passwordValue = @"";
    self.pinValue = @"";
    [passwordTextField setStringValue:@""];
}

- (void)showError
{
    [self.delegate showView:errorContainer];
    QObject::disconnect(accountCreated);
    QObject::disconnect(accountRemoved);
}
- (void)showLoading
{
    [progressBar startAnimation:nil];
    [self.delegate showView:loadingContainer];
}

- (IBAction)importRingAccount:(id)sender
{
    QObject::disconnect(accountCreated);
    QObject::disconnect(accountRemoved);
    accountCreated = QObject::connect(self.accountModel,
                                      &lrc::api::NewAccountModel::accountAdded,
                                      [self] (const QString& accountID) {
                                           if(accountID.compare(accountToCreate) != 0) {
                                               return;
                                           }
                                          [self.delegate didLinkAccountWithSuccess:YES];
                                          lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(accountID);
                                          accountProperties.Ringtone.ringtonePath = [defaultRingtonePath() UTF8String];
                                          self.accountModel->setAccountConfig(accountID, accountProperties);
                                          [self registerDefaultPreferences];
                                          QObject::disconnect(accountCreated);
                                          QObject::disconnect(accountRemoved);
                                      });
    // account that is invalid will be removed, connect the signal to show error message
    accountRemoved = QObject::connect(self.accountModel,
                                      &lrc::api::NewAccountModel::accountRemoved,
                                      [self] (const QString& accountID) {
                                          if(accountID.compare(accountToCreate) == 0) {
                                              [self showError];
                                          }
                                      });
    accountRemoved = QObject::connect(self.accountModel,
                                      &lrc::api::NewAccountModel::invalidAccountDetected,
                                      [self] (const QString& accountID) {
                                          if(accountID.compare(accountToCreate) == 0) {
                                              [self showError];
                                          }
                                      });

    [self showLoading];
    NSString *pin = backupFile ? @"" : (self.pinValue ? self.pinValue : @"");
    NSString *archivePath = backupFile ? [backupFile path] : @"";
    NSString *pathword = self.passwordValue ? self.passwordValue : @"";
    accountToCreate = self.accountModel->createNewAccount(lrc::api::profile::Type::RING, "",[archivePath UTF8String], [pathword UTF8String], [pin UTF8String]);
}

- (IBAction)dismissViewWithError:(id)sender
{
    [self.delegate didLinkAccountWithSuccess:NO];
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

- (IBAction)showPINHelp:(id)sender
{
    [helpPINContainer showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSMaxYEdge];
}

- (IBAction)showArchiveFileHelp:(id)sender
{
    [helpArchiveFileContainer showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSMaxYEdge];
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
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:Preferences::CallNotifications];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:Preferences::MessagesNotifications];
}
@end
