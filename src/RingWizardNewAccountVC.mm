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
    __unsafe_unretained IBOutlet NSView* loadingView;
    __unsafe_unretained IBOutlet NSView* creationView;

    __unsafe_unretained IBOutlet NSButton* photoView;
    __unsafe_unretained IBOutlet NSTextField* displayNameField;
    __unsafe_unretained IBOutlet NSTextField* registeredNameField;
    __unsafe_unretained IBOutlet NSSecureTextField* passwordField;
    __unsafe_unretained IBOutlet NSSecureTextField* passwordRepeatField;
    __unsafe_unretained IBOutlet NSImageView* passwordCheck;
    __unsafe_unretained IBOutlet NSImageView* passwordRepeatCheck;

    __unsafe_unretained IBOutlet NSProgressIndicator* progressBar;

    __unsafe_unretained IBOutlet NSImageView* ivLookupResult;
    __unsafe_unretained IBOutlet NSProgressIndicator* indicatorLookupResult;

    __unsafe_unretained IBOutlet NSPopover* helpBlockchainContainer;
    __unsafe_unretained IBOutlet NSPopover* helpPasswordContainer;

    Account* accountToCreate;
    NSTimer* errorTimer;
    QMetaObject::Connection stateChanged;
    QMetaObject::Connection registrationEnded;
    QMetaObject::Connection registeredNameFound;

    BOOL lookupQueued;
    NSString* usernameWaitingForLookupResult;
}

NSInteger const DISPLAY_NAME_TAG                = 1;
NSInteger const BLOCKCHAIN_NAME_TAG             = 2;

//ERROR CODE for textfields validations
NSInteger const ERROR_PASSWORD_TOO_SHORT        = -1;
NSInteger const ERROR_REPEAT_MISMATCH           = -2;


- (BOOL)produceError:(NSError**)error withCode:(NSInteger)code andMessage:(NSString*)message
{
    if (error != NULL){
        NSDictionary *errorDetail = @{NSLocalizedDescriptionKey: message};
        *error = [NSError errorWithDomain:@"Input" code:code userInfo:errorDetail];
    }
    return NO;
}

- (IBAction)showBlockchainHelp:(id)sender
{
    [helpBlockchainContainer showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSMaxYEdge];
}

- (IBAction)showPasswordHelp:(id)sender
{
    [helpPasswordContainer showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSMaxYEdge];
}

- (void)show
{
    AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
    [displayNameField setTag:DISPLAY_NAME_TAG];
    [registeredNameField setTag:BLOCKCHAIN_NAME_TAG];
    [displayNameField setStringValue: NSFullUserName()];
    [self controlTextDidChange:[NSNotification notificationWithName:@"PlaceHolder" object:displayNameField]];

    NSData* imgData = [[[ABAddressBook sharedAddressBook] me] imageData];
    if (imgData != nil) {
        [photoView setImage:[[NSImage alloc] initWithData:imgData]];
    } else
        [photoView setImage:[NSImage imageNamed:@"default_user_icon"]];

    [photoView setWantsLayer: YES];
    photoView.layer.cornerRadius = photoView.frame.size.width / 2;
    photoView.layer.masksToBounds = YES;
    self.signUpBlockchainState = YES;
    [self toggleSignupRing:nil];

    [self display:creationView];
}

- (void)removeSubviews
{
    while ([self.view.subviews count] > 0){
        [[self.view.subviews firstObject] removeFromSuperview];
    }
}

- (void)display:(NSView *)view
{
    [self.delegate showView:view];
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
    } else {
        [photoView setImage:[NSImage imageNamed:@"default_user_icon"]];
    }
}

#pragma mark - Input validation

- (BOOL)isPasswordValid
{
    return self.password.length >= 6;
}

- (BOOL)isRepeatPasswordValid
{
    return [self.password isEqualToString:self.repeatPassword] || ([self.password length] == 0 && [self.repeatPassword length] == 0);
}

- (BOOL)validateRepeatPassword:(NSError **)error
{
    if (!self.isRepeatPasswordValid){
        return [self produceError:error
                         withCode:ERROR_REPEAT_MISMATCH
                       andMessage:NSLocalizedString(@"Passwords don't match",
                                                    @"Indication for user")];
    }
    return YES;
}

- (BOOL)validatePassword:(NSError **)error
{
    if (!self.isRepeatPasswordValid){
        return [self produceError:error
                         withCode:ERROR_PASSWORD_TOO_SHORT
                       andMessage:NSLocalizedString(@"Password is too short",
                                                    @"Indication for user")];
    }
    return YES;
}

- (BOOL)validateUserInputPassword:(NSError **)error
{
    return [self validatePassword:error] && [self validateRepeatPassword:error];
}

- (IBAction)createRingAccount:(id)sender
{
    NSError *error = nil;
    if (![self validateUserInputPassword:&error]){
        NSAlert* alert = [NSAlert alertWithMessageText:[error localizedDescription]
                                         defaultButton:NSLocalizedString(@"Revise Input",
                                                                         @"Button title")
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:@"%@",error];

        [alert beginSheetModalForWindow:passwordField.window
                          modalDelegate:nil
                         didEndSelector:NULL
                            contextInfo:NULL];

        return;
    }

    [self display:loadingView];
    [progressBar startAnimation:nil];

    NSString* displayName = displayNameField.stringValue;
    if ([displayName isEqualToString:@""]) {
        displayName = NSLocalizedString(@"Unknown", @"Name used when user leave field empty");
    }

    accountToCreate = AccountModel::instance().add(QString::fromNSString(displayName), Account::Protocol::RING);
    accountToCreate->setAlias([displayName UTF8String]);
    accountToCreate->setDisplayName([displayName UTF8String]);

    if (auto profile = ProfileModel::instance().selectedProfile()) {
        profile->person()->setFormattedName([displayName UTF8String]);
        QPixmap p;
        auto smallImg = [NSImage imageResize:[photoView image] newSize:{100,100}];
        if (p.loadFromData(QByteArray::fromNSData([smallImg TIFFRepresentation]))) {
            profile->person()->setPhoto(QVariant(p));
        } else {
            auto defaultAvatar = [NSImage imageResize:[NSImage imageNamed:@"default_user_icon"] newSize:{100,100}];
            p.loadFromData(QByteArray::fromNSData([defaultAvatar TIFFRepresentation]));
            profile->person()->setPhoto(QVariant(p));
        }
        profile->save();
    }

    QModelIndex qIdx = AccountModel::instance().protocolModel()->selectionModel()->currentIndex();

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
    stateChanged = QObject::connect(&AccountModel::instance(),
                                    &AccountModel::accountStateChanged,
                                    [=](Account *account, const Account::RegistrationState state) {
                                        switch(state){
                                            case Account::RegistrationState::READY:
                                            case Account::RegistrationState::TRYING:
                                            case Account::RegistrationState::UNREGISTERED:{
                                                accountToCreate << Account::EditAction::RELOAD;
                                                QObject::disconnect(stateChanged);
                                                //try to register username
                                                if (self.signUpBlockchainState == NSOnState){
                                                    [self startNameRegistration:account];
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
                                                //Do Nothing
                                                break;
                                            }
                                        }
                                    });
}

- (void) startNameRegistration:(Account*) account
{
    // Dismiss this screen if after 30 seconds the name is still not registered
    errorTimer = [NSTimer scheduledTimerWithTimeInterval:30
                                                  target:self
                                                selector:@selector(nameRegistrationTimeout) userInfo:nil
                                                 repeats:NO];
    registrationEnded = QObject::connect(account,
                                         &Account::nameRegistrationEnded,
                                         [=] (NameDirectory::RegisterNameStatus status,  const QString& name) {
                                             QObject::disconnect(registrationEnded);
                                             switch(status) {
                                                 case NameDirectory::RegisterNameStatus::WRONG_PASSWORD:
                                                 case NameDirectory::RegisterNameStatus::ALREADY_TAKEN:
                                                 case NameDirectory::RegisterNameStatus::NETWORK_ERROR: {
                                                     [self couldNotRegisterUsername];
                                                     break;
                                                 }
                                                 case NameDirectory::RegisterNameStatus::SUCCESS: {
                                                     break;
                                                 }
                                             }

                                             [self.delegate didCreateAccountWithSuccess:YES];
                                         });
    self.isUserNameAvailable = account->registerName(QString::fromNSString(self.password),
                                                     QString::fromNSString(self.registeredName));
    if (!self.isUserNameAvailable){
        NSLog(@"Could not initialize registerName operation");
        QObject::disconnect(registrationEnded);
        [self.delegate didCreateAccountWithSuccess:YES];
    }
}

- (void)nameRegistrationTimeout
{
    // This callback is used when registration takes more than 30 seconds
    // It skips the wizard and brings the main window
    [self.delegate didCreateAccountWithSuccess:YES];
}

- (IBAction)cancel:(id)sender
{
    [self.delegate didCreateAccountWithSuccess:NO];
}

#pragma mark - UserNameRegistration delegate methods

- (IBAction)toggleSignupRing:(id)sender
{
    if (self.withBlockchain) {
        [self lookupUserName];
    }
}

- (void)couldNotRegisterUsername
{
    // Do nothing
}

- (BOOL)withBlockchain
{
    return self.signUpBlockchainState == NSOnState;
}

- (BOOL)userNameAvailableORNotBlockchain
{
    return !self.withBlockchain || (self.registeredName.length > 0 && self.isUserNameAvailable);
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

                                           });

    //Start the lookup in a second so that the UI dosen't seem to freeze
    BOOL result = NameDirectory::instance().lookupName(nullptr, QString(), QString::fromNSString(usernameWaitingForLookupResult));

}

#pragma mark - NSTextFieldDelegate delegate methods

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
    if (self.withBlockchain && !lookupQueued) {
        usernameWaitingForLookupResult = name;
        lookupQueued = YES;
        [self lookupUserName];
    }
}


+ (NSSet *)keyPathsForValuesAffectingUserNameAvailableORNotBlockchain
{
    return [NSSet setWithObjects:   NSStringFromSelector(@selector(signUpBlockchainState)),
            NSStringFromSelector(@selector(isUserNameAvailable)),
            nil];
}

+ (NSSet *)keyPathsForValuesAffectingWithBlockchain
{
    return [NSSet setWithObjects:   NSStringFromSelector(@selector(signUpBlockchainState)),
            nil];
}

+ (NSSet *)keyPathsForValuesAffectingIsPasswordValid
{
    return [NSSet setWithObjects:@"password", nil];
}

+ (NSSet *)keyPathsForValuesAffectingIsRepeatPasswordValid
{
    return [NSSet setWithObjects:@"password", @"repeatPassword", nil];
}
@end
