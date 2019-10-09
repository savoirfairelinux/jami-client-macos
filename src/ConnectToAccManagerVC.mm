/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
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

#import "ConnectToAccManagerVC.h"
#import "utils.h"

//LRC
#import <api/lrc.h>
#import <api/newaccountmodel.h>

@interface ConnectToAccManagerVC ()

@end

@implementation ConnectToAccManagerVC {
    __unsafe_unretained IBOutlet NSView* initialContainer;
    __unsafe_unretained IBOutlet NSView* loadingContainer;
    __unsafe_unretained IBOutlet NSProgressIndicator* progressBar;
    __unsafe_unretained IBOutlet NSView* errorContainer;

    __unsafe_unretained IBOutlet NSTextField* userNameField;
    __unsafe_unretained IBOutlet NSTextField* accountManagerField;
    __unsafe_unretained IBOutlet NSSecureTextField* passwordTextField;
}

QMetaObject::Connection accountCreatedSuccess;
QMetaObject::Connection accountNotCreated;
std::string accointId;

@synthesize accountModel;

-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil accountmodel:(lrc::api::NewAccountModel*) accountModel {
    if (self =  [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.accountModel = accountModel;
    }
    return self;
}

- (void)show
{
    self.username = userNameField.stringValue = @"";
    self.password = passwordTextField.stringValue = @"";
    self.accountManager = accountManagerField.stringValue = @"";
    [self.delegate showView:initialContainer];
}

- (void)showError
{
    [self.delegate showView:errorContainer];
}
- (void)showLoading
{
    [progressBar startAnimation:nil];
    [self.delegate showView:loadingContainer];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
}

- (IBAction)dismissViewWithError:(id)sender
{
    [self.delegate didSignInSuccess:NO];
}

- (IBAction)startAgain:(id)sender
{
    [self show];
}


- (IBAction)signIn:(id)sender
{
    QObject::disconnect(accountCreatedSuccess);
    QObject::disconnect(accountNotCreated);
    accountCreatedSuccess = QObject::connect(self.accountModel,
                                      &lrc::api::NewAccountModel::accountAdded,
                                      [self] (const std::string& accountID) {
                                          if(accountID.compare(accointId) != 0) {
                                              return;
                                          }
                                          [self.delegate didSignInSuccess:YES];
                                          lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(accountID);
                                          accountProperties.Ringtone.ringtonePath = [defaultRingtonePath() UTF8String];
                                          self.accountModel->setAccountConfig(accountID, accountProperties);
                                          QObject::disconnect(accountCreatedSuccess);
                                          QObject::disconnect(accountNotCreated);
                                      });
    accountNotCreated = QObject::connect(self.accountModel,
                                      &lrc::api::NewAccountModel::accountRemoved,
                                      [self] (const std::string& accountID) {
                                          if(accountID.compare(accointId) == 0) {
                                              [self showError];
                                          }
                                      });
    accountNotCreated = QObject::connect(self.accountModel,
                                      &lrc::api::NewAccountModel::invalidAccountDetected,
                                      [self] (const std::string& accountID) {
                                          if(accountID.compare(accointId) == 0) {
                                              [self showError];
                                          }
                                      });

    [self showLoading];

    accointId = self.accountModel->connectToAccountManager([userNameField.stringValue UTF8String], [passwordTextField.stringValue UTF8String], [accountManagerField.stringValue UTF8String]);
}

@end
