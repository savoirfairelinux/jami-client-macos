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

#import "RingWizardNewAccountVC.h"


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

#import "AppDelegate.h"
#import "Constants.h"
#import "views/NSImage+Extensions.h"
#import "views/NSColor+RingTheme.h"

@interface RingWizardNewAccountVC ()
@end

@implementation RingWizardNewAccountVC
{
    __unsafe_unretained IBOutlet NSButton* photoView;
    __unsafe_unretained IBOutlet NSTextField* nicknameField;
    __unsafe_unretained IBOutlet NSSecureTextField* passwordField;
    __unsafe_unretained IBOutlet NSProgressIndicator* progressBar;
    __unsafe_unretained IBOutlet NSTextField* indicationLabel;
    __unsafe_unretained IBOutlet NSTextField* passwordLabel;
    __unsafe_unretained IBOutlet NSButton* createButton;
    __unsafe_unretained IBOutlet NSButton* cancelButton;

    __unsafe_unretained IBOutlet NSButton* cbSignupRing;
    __unsafe_unretained IBOutlet NSImageView* ivLookupResult;
    __unsafe_unretained IBOutlet NSTextField* lbLookupResult;
    __unsafe_unretained IBOutlet NSProgressIndicator* indicatorLookupResult;
    __unsafe_unretained IBOutlet NSView* vLookupResult;

    Account* accountToCreate;
    NSTimer* errorTimer;
    QMetaObject::Connection stateChanged;
    QMetaObject::Connection registrationEnded;
    QMetaObject::Connection registeredNameFound;


    BOOL usernameAvailable;
    BOOL lookupQueued;
    NSString* username_waiting_for_lookup_result;
}

NSInteger const NICKNAME_TAG        = 1;


- (void)show
{
    AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
    [nicknameField setTag:NICKNAME_TAG];
    //if(![appDelegate checkForRingAccount]) {

        [nicknameField setStringValue:NSFullUserName()];
        [self controlTextDidChange:[NSNotification notificationWithName:@"PlaceHolder" object:nicknameField]];
    //}

    NSData* imgData = [[[ABAddressBook sharedAddressBook] me] imageData];
    if (imgData != nil) {
        [photoView setImage:[[NSImage alloc] initWithData:imgData]];
    } else
        [photoView setImage:[NSImage imageNamed:@"default_user_icon"]];

    [photoView setWantsLayer: YES];
    photoView.layer.cornerRadius = photoView.frame.size.width / 2;
    photoView.layer.masksToBounds = YES;
}



- (IBAction)editPhoto:(id)sender
{
   auto pictureTaker = [IKPictureTaker pictureTaker];

    [pictureTaker beginPictureTakerSheetForWindow:[self.delegate window]
                                     withDelegate:self
                                   didEndSelector:@selector(pictureTakerDidEnd:returnCode:contextInfo:)
                                      contextInfo:nil];

}

- (void)pictureTakerDidEnd:(IKPictureTaker *) picker
                 returnCode:(NSInteger) code
                contextInfo:(void*) contextInfo
{
    if (auto outputImage = [picker outputImage]) {
        [photoView setImage:outputImage];
    } else
        [photoView setImage:[NSImage imageNamed:@"default_user_icon"]];
}

- (IBAction)shareRingID:(id)sender {
    auto sharingServicePicker = [[NSSharingServicePicker alloc] initWithItems:[NSArray arrayWithObject:[nicknameField stringValue]]];
    [sharingServicePicker showRelativeToRect:[sender bounds]
                                      ofView:sender
                               preferredEdge:NSMinYEdge];
}

- (IBAction)createRingAccount:(id)sender
{
    [nicknameField setHidden:YES];
    [progressBar setHidden:NO];
    [createButton setHidden:YES];
    [photoView setHidden:YES];
    [passwordField setHidden:YES];
    [passwordLabel setHidden:YES];
    [cancelButton setHidden:YES];
    [progressBar startAnimation:nil];
    [indicationLabel setStringValue:NSLocalizedString(@"Just a moment...",
                                                      @"Indication for user")];



    if ([self.alias isEqualToString:@""]) {
        self.alias = NSLocalizedString(@"Unknown", @"Name used when user leave field empty");
    }
    accountToCreate = AccountModel::instance().add(QString::fromNSString(self.alias), Account::Protocol::RING);

    accountToCreate->setAlias([self.alias UTF8String]);
    accountToCreate->setDisplayName([self.alias UTF8String]);

    if (auto profile = ProfileModel::instance().selectedProfile()) {
        profile->person()->setFormattedName([self.alias UTF8String]);
        QPixmap p;
        auto smallImg = [NSImage imageResize:[photoView image] newSize:{100,100}];
        if (p.loadFromData(QByteArray::fromNSData([smallImg TIFFRepresentation]))) {
            profile->person()->setPhoto(QVariant(p));
        }
        profile->save();
    }

    QModelIndex qIdx =  AccountModel::instance().protocolModel()->selectionModel()->currentIndex();

    [self setCallback];

    [self performSelector:@selector(saveAccount) withObject:nil afterDelay:1];
    [self registerDefaultPreferences];
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
    accountToCreate->setArchivePassword(QString::fromNSString(passwordField.stringValue));
    accountToCreate->setUpnpEnabled(YES); // Always active upnp
    accountToCreate << Account::EditAction::SAVE;
}

- (void)setCallback
{
    errorTimer = [NSTimer scheduledTimerWithTimeInterval:30
                                                  target:self
                                                selector:@selector(didCreateFailed) userInfo:nil
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

                                                                     //try to register username
                                                                     if (self.signUpBlockchainState == NSOnState){
                                                                         registrationEnded = QObject::connect(
                                                                                            account,
                                                                                            &Account::nameRegistrationEnded,
                                                                                            [=] (NameDirectory::RegisterNameStatus status,  const QString& name)
                                                                                            {
                                                                                                QObject::disconnect(registrationEnded);
                                                                                                switch(status)
                                                                                                {
                                                                                                    case NameDirectory::RegisterNameStatus::WRONG_PASSWORD:
                                                                                                    case NameDirectory::RegisterNameStatus::ALREADY_TAKEN:
                                                                                                    case NameDirectory::RegisterNameStatus::NETWORK_ERROR:
                                                                                                    {
                                                                                                        [self couldNotRegisterUsername];
                                                                                                    }
                                                                                                    case NameDirectory::RegisterNameStatus::SUCCESS:
                                                                                                    {
                                                                                                        break;
                                                                                                    }
                                                                                                }

                                                                                                [self.delegate didCreateAccountWithSuccess:YES];
                                                                                            }
                                                                                        );
                                                                         usernameAvailable = account->registerName(QString::fromNSString(self.password), QString::fromNSString(self.alias));
                                                                         if (!usernameAvailable){
                                                                             NSLog(@"Could not initialize registerName operation");
                                                                             QObject::disconnect(registrationEnded);
                                                                             [self.delegate didCreateAccountWithSuccess:YES];
                                                                         }
                                                                     } else {
                                                                         [self.delegate didCreateAccountWithSuccess:YES];
                                                                     }
                                                                    break;
                                                                 }
                                                                 case Account::RegistrationState::ERROR:
                                                                     QObject::disconnect(stateChanged);
                                                                     [self.delegate didCreateAccountWithSuccess:NO];
                                                                     break;
                                                                 case Account::RegistrationState::INITIALIZING:
                                                                 case Account::RegistrationState::COUNT__:{
                                                                     //DO Nothing
                                                                     break;
                                                                 }
                                                             }
                                                         });
}

- (void)didCreateFailed
{
    [self.delegate didCreateAccountWithSuccess:NO];
}

- (IBAction)cancel:(id)sender
{
    [self.delegate didCreateAccountWithSuccess:NO];
}

#pragma mark - UserNameRegistration delegate methods
- (IBAction)toggleSignupRing:(id)sender
{
    if (self.withBlockchain){
        [self lookupUserName];
    }
}

- (void)couldNotRegisterUsername
{

}

- (BOOL)withBlockchain
{
    return self.signUpBlockchainState == NSOnState;
}


- (BOOL)userNameAvailableORNotBlockchain
{
    return (self.signUpBlockchainState == NSOffState) || (self.alias.length > 0 && usernameAvailable);
}

- (void)showUserRegistrationView
{

}

- (void)showLookUpAvailable:(BOOL)available andText:(NSString *)message
{
    [ivLookupResult setImage:[NSImage imageNamed:(available?@"ic_action_accept":@"ic_action_cancel")]] ;
    [ivLookupResult setHidden:NO];
    [ivLookupResult setToolTip:message];
    [lbLookupResult setStringValue:message];
}


- (void)onUsernameAvailabilityChangedWithNewAvailability:(BOOL)newAvailability
{
    usernameAvailable = newAvailability;
}

- (void)hideLookupSpinner
{
    [indicatorLookupResult setHidden:YES];
}
- (void)showLookupSpinner
{
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
                                           [=] ( const QString& accountId, NameDirectory::LookupStatus status,  const QString& address, const QString& name) {
                                               NSLog(@"Name lookup ended");
                                               lookupQueued = NO;
                                               //If this is the username we are waiting for, we can disconnect.
                                               if (name.compare(QString::fromNSString(username_waiting_for_lookup_result)) == 0)
                                               {
                                                 QObject::disconnect(registeredNameFound);
                                               }
                                               else
                                               {
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
                                                       message = NSLocalizedString(@"The entered username is not available", @"Text shown to user when his username is already registered");
                                                       isAvailable = NO;
                                                       break;
                                                   }
                                                   case NameDirectory::LookupStatus::NOT_FOUND:
                                                   {
                                                       message = NSLocalizedString(@"The entered username is available", @"Text shown to user when his username is available to be registered");
                                                       isAvailable = YES;
                                                       break;
                                                   }
                                                   case NameDirectory::LookupStatus::ERROR:
                                                   {
                                                       message = NSLocalizedString(@"Failed to perform lookup", @"Text shown to user when an error occur at registration");
                                                       isAvailable = NO;
                                                       break;
                                                   }
                                               }
                                               [self showLookUpAvailable:isAvailable andText: message];
                                               [self onUsernameAvailabilityChangedWithNewAvailability:NO];

                                           }
                                           );
    
    //Start the lookup in a second so that the UI dosen't seem to freeze
    BOOL result = NameDirectory::instance().lookupName(QString(), QString(), QString::fromNSString(username_waiting_for_lookup_result));

}

#pragma mark - NSOpenSavePanelDelegate delegate methods
- (BOOL)panel:(id)sender validateURL:(NSURL *)url error:(NSError **)outError
{
    return YES;
}

- (void)controlTextDidChange:(NSNotification *)notif
{
    NSTextField* textField = [notif object];
    // else it is NICKNAME_TAG field
    NSString* alias = textField.stringValue;
    if ([alias isEqualToString:@""]) {
        alias = NSLocalizedString(@"Unknown", @"Name used when user leave field empty");
    }
    self.alias = alias;
    if (self.withBlockchain && !lookupQueued){
        username_waiting_for_lookup_result = [alias  stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];

        lookupQueued = YES;
        [self lookupUserName];
    }
}

+ (NSSet *)keyPathsForValuesAffectingWithBlockchain
{
    return [NSSet setWithObjects:@"signUpBlockchainState", nil];
}


@end
