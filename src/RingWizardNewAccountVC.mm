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

#import "RingWizardNewAccountVC.h"


//Cocoa
#import <Quartz/Quartz.h>
#import <AVFoundation/AVFoundation.h>

//Qt
#import <QUrl>
#import <QPixmap>
#import <QSize>
#import <QtMacExtras/qmacfunctions.h>

//LRC
#import <api/lrc.h>
#import <api/newaccountmodel.h>
#import <api/account.h>
#import <interfaces/pixmapmanipulatori.h>
#import <namedirectory.h>

#import "Constants.h"
#import "views/NSImage+Extensions.h"
#import "views/NSColor+RingTheme.h"
#import "utils.h"

@interface RingWizardNewAccountVC ()
@end

@implementation RingWizardNewAccountVC
{
    __unsafe_unretained IBOutlet NSView* loadingView;
    __unsafe_unretained IBOutlet NSView* creationView;

    __unsafe_unretained IBOutlet NSButton* photoView;
    __unsafe_unretained IBOutlet NSButton* registerInfoButton;
    __unsafe_unretained IBOutlet NSButton* enableUsername;
    __unsafe_unretained IBOutlet NSTextField* displayNameField;
    __unsafe_unretained IBOutlet NSTextField* registeredNameField;
    __unsafe_unretained IBOutlet NSTextField* registeredNameError;
    __unsafe_unretained IBOutlet NSTextField* passwordError;
    __unsafe_unretained IBOutlet NSSecureTextField* passwordField;
    __unsafe_unretained IBOutlet NSSecureTextField* passwordRepeatField;
    __unsafe_unretained IBOutlet NSImageView* addProfilePhotoImage;

    __unsafe_unretained IBOutlet NSProgressIndicator* progressBar;

    __unsafe_unretained IBOutlet NSProgressIndicator* indicatorLookupResult;

    __unsafe_unretained IBOutlet NSPopover* helpBlockchainContainer;
    __unsafe_unretained IBOutlet NSPopover* helpPasswordContainer;
    __unsafe_unretained IBOutlet NSLayoutConstraint* buttonTopConstraint;
    __unsafe_unretained IBOutlet NSButton* passwordButton;
    __unsafe_unretained IBOutlet NSStackView* repeatPasswordView;
    __unsafe_unretained IBOutlet NSStackView* passwordButtonContainer;

    QMetaObject::Connection registeredNameFound;
    QMetaObject::Connection accountCreated;
    QMetaObject::Connection accountRemoved;

    BOOL lookupQueued;
    NSString* usernameWaitingForLookupResult;
    QString accountToCreate;
}

NSInteger const DISPLAY_NAME_TAG                = 1;
NSInteger const BLOCKCHAIN_NAME_TAG             = 2;
NSInteger const PASSWORD_TAG                    = 3;
NSInteger const REPEAT_PASSWORD_TAG             = 4;

//ERROR CODE for textfields validations
NSInteger const ERROR_PASSWORD_TOO_SHORT        = -1;
NSInteger const ERROR_REPEAT_MISMATCH           = -2;

BOOL isRendevous = false;

@synthesize accountModel;

-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil accountmodel:(lrc::api::NewAccountModel*) accountModel {
    if (self =  [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.accountModel = accountModel;
    }
    return self;
}

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

- (void)prepareViewToShow:(BOOL)isRendevousAccount {
    isRendevous = isRendevousAccount;
    [self.view setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    [creationView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    [loadingView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    [passwordField setHidden: YES];
    [repeatPasswordView setHidden: YES];
    buttonTopConstraint.constant = isRendevous ? 15 : 25;
}

- (void)show {
    NSString *buttonTitle = isRendevous ?
    NSLocalizedString(@"Choose a name for your rendezvous point", @"Choose registered name for rendezvous") :
    NSLocalizedString(@"Choose a username for your account", @"Choose registered name for account");
    [enableUsername setTitle:buttonTitle];
    [passwordButtonContainer setHidden: isRendevous];
    [registerInfoButton setHidden: isRendevous];
    [displayNameField setTag:DISPLAY_NAME_TAG];
    [registeredNameField setTag:BLOCKCHAIN_NAME_TAG];
    [photoView setWantsLayer: YES];
    photoView.layer.cornerRadius = photoView.frame.size.width / 2;
    photoView.layer.masksToBounds = YES;
    self.signUpBlockchainState = YES;
    [self toggleSignupRing:nil];
    [addProfilePhotoImage setWantsLayer: YES];
    [photoView setBordered:YES];
    [passwordButton setState: NSControlStateValueOff];
    self.registeredName = @"";
    self.password = @"";
    self.repeatPassword = @"";
    [self display:creationView];
}

- (void)display:(NSView *)view
{
    [self.delegate showView:view];
}

- (IBAction)editPhoto:(id)sender
{
    auto pictureTaker = [IKPictureTaker pictureTaker];
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 101400
    if (@available(macOS 10.14, *)) {
        AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        if(authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied)
        {
            [pictureTaker setValue:0 forKey:IKPictureTakerAllowsVideoCaptureKey];
        }

        if(authStatus == AVAuthorizationStatusNotDetermined)
        {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if(!granted){
                    [pictureTaker setValue:0 forKey:IKPictureTakerAllowsVideoCaptureKey];
                }
            }];
        }
    }
#endif
    [pictureTaker beginPictureTakerSheetForWindow:[self.delegate window]
                                     withDelegate:self
                                   didEndSelector:@selector(pictureTakerDidEnd:returnCode:contextInfo:)
                                      contextInfo:nil];

}

- (void)pictureTakerDidEnd:(IKPictureTaker *) picker
                returnCode:(NSInteger) code
               contextInfo:(void*) contextInfo
{
    //do nothing when editing canceled 
    if (code == 0) {
        return;
    }
    if (auto outputImage = [picker outputImage]) {
        [photoView setBordered:NO];
        auto image = [picker inputImage];
        CGFloat newSize = MIN(MIN(image.size.height, image.size.width), MAX_IMAGE_SIZE);
        outputImage = [outputImage imageResizeInsideMax: newSize];
        [photoView setImage:outputImage];
        [addProfilePhotoImage setHidden:YES];
    } else if(!photoView.image) {
        [photoView setBordered:YES];
        [addProfilePhotoImage setHidden:NO];
    }
}

#pragma mark - Input validation

- (BOOL)isPasswordValid
{
    return self.password.length >= 6 || self.password.length == 0;
}

- (BOOL)isRepeatPasswordValid
{
    return [self.password isEqualToString:self.repeatPassword] || ([self.password length] == 0 && [self.repeatPassword length] == 0);
}

- (BOOL)validateRepeatPassword:(NSError **)error
{
    if (!self.isRepeatPasswordValid){
        passwordError.stringValue = NSLocalizedString(@"Passwords don't match",
                                                      @"Indication for user");
        return [self produceError:error
                         withCode:ERROR_REPEAT_MISMATCH
                       andMessage:NSLocalizedString(@"Passwords don't match",
                                                    @"Indication for user")];
    }
    passwordError.stringValue = @"";
    return YES;
}

- (BOOL)validatePassword:(NSError **)error
{
    if (!self.isPasswordValid){
        passwordError.stringValue = NSLocalizedString(@"Password is too short",
                                                      @"Indication for user");
        return [self produceError:error
                         withCode:ERROR_PASSWORD_TOO_SHORT
                       andMessage:NSLocalizedString(@"Password is too short",
                                                    @"Indication for user")];
    }
    passwordError.stringValue = @"";
    return YES;
}

- (BOOL)validateUserInputPassword:(NSError **)error
{
    return [self validatePassword:error] && [self validateRepeatPassword:error];
}

- (IBAction)createRingAccount:(id)sender
{
    QObject::disconnect(accountCreated);
    QObject::disconnect(accountRemoved);
    accountCreated = QObject::connect(self.accountModel,
                                      &lrc::api::NewAccountModel::accountAdded,
                                      [self] (const QString& accountID) {
                                          if(accountID.compare(accountToCreate) != 0) {
                                              return;
                                          }
                                          QObject::disconnect(accountCreated);
                                          QObject::disconnect(accountRemoved);
                                          //set account avatar
                                          if([photoView image]) {
                                              NSImage *avatarImage = [photoView image];
                                              NSData* imageData = [avatarImage TIFFRepresentation];
                                              NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData: imageData];
                                              NSDictionary *properties = [[NSDictionary alloc] init];
                                              imageData = [imageRep representationUsingType:NSPNGFileType properties: properties];
                                              NSString * dataString = [imageData base64EncodedStringWithOptions:0];
                                              self.accountModel->setAvatar(accountID, QString::fromNSString(dataString));
                                          }
                                          //register username
                                          if (self.registeredName && ![self.registeredName isEqualToString:@""]) {
                                              NSString *passwordString = self.password ? self.password: @"";
                                              NSString *usernameString = self.registeredName;
                                              self.accountModel->registerName(accountID,
                                                                              QString::fromNSString(passwordString),
                                                                              QString::fromNSString(usernameString));
                                          }
                                          lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(accountID);
                                          accountProperties.Ringtone.ringtonePath = QString::fromNSString(defaultRingtonePath());
                                          accountProperties.isRendezVous = isRendevous;
                                          self.accountModel->setAccountConfig(accountID, accountProperties);
                                          [self registerDefaultPreferences];
                                          [self.delegate didCreateAccountWithSuccess:YES accountId: accountToCreate];
                                      });
    //if account creation failed remove loading view
    accountRemoved = QObject::connect(self.accountModel,
                                      &lrc::api::NewAccountModel::accountRemoved,
                                      [self] (const QString& accountID) {
                                          if(accountID.compare(accountToCreate) != 0) {
                                              return;
                                          }
                                          QObject::disconnect(accountCreated);
                                          QObject::disconnect(accountRemoved);
                                          [self.delegate didCreateAccountWithSuccess:NO accountId: accountToCreate];
                                      });
    [self display:loadingView];
    [progressBar startAnimation:nil];

    accountToCreate = self.accountModel->createNewAccount(lrc::api::profile::Type::RING, QString::fromNSString(displayNameField.stringValue),"",QString::fromNSString(passwordField.stringValue), "");
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

- (IBAction)cancel:(id)sender
{
    [self.delegate didCreateAccountWithSuccess:NO accountId: accountToCreate];
}

#pragma mark - UserNameRegistration delegate methods

- (IBAction)toggleSignupRing:(id)sender
{
    if (self.withBlockchain) {
        [self lookupUserName];
    }
}

- (IBAction)togglePasswordButton:(NSButton *)sender
{
    [passwordField setHidden: !passwordField.hidden];
    [repeatPasswordView setHidden: !repeatPasswordView.hidden];
    buttonTopConstraint.constant = repeatPasswordView.hidden ? 25 : 15;
    [self display:creationView];
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
    if (registeredNameField.stringValue.length > 0) {
        registeredNameError.stringValue = message;
    }
    [indicatorLookupResult setHidden:YES];
    [indicatorLookupResult stopAnimation:nil];
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
    registeredNameError.stringValue = @"";
    if (registeredNameField.stringValue.length > 0) {
        [indicatorLookupResult setHidden:NO];
        [indicatorLookupResult startAnimation:nil];
    }
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
                                                       message = @"";
                                                       isAvailable = YES;
                                                       break;
                                                   }
                                                   case NameDirectory::LookupStatus::INVALID_NAME:
                                                   {
                                                       message = NSLocalizedString(@"Invalid username.",
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
    BOOL result = NameDirectory::instance().lookupName(QString(), QString::fromNSString(usernameWaitingForLookupResult));

}

#pragma mark - NSTextFieldDelegate delegate methods

- (void)controlTextDidChange:(NSNotification *)notif
{
    NSTextField* textField = [notif object];
    if (textField.tag == PASSWORD_TAG) {
        NSError *error = nil;
        [self validatePassword: &error];
        return;
    }
    if (textField.tag == REPEAT_PASSWORD_TAG) {
        NSError *error = nil;
        [self validateRepeatPassword: &error];
        return;
    }
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
