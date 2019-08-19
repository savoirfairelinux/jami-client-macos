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
    __unsafe_unretained IBOutlet NSTextField* displayNameField;
    __unsafe_unretained IBOutlet NSTextField* registeredNameField;
    __unsafe_unretained IBOutlet NSSecureTextField* passwordField;
    __unsafe_unretained IBOutlet NSSecureTextField* passwordRepeatField;
    __unsafe_unretained IBOutlet NSImageView* passwordCheck;
    __unsafe_unretained IBOutlet NSImageView* passwordRepeatCheck;
    __unsafe_unretained IBOutlet NSImageView* addProfilePhotoImage;

    __unsafe_unretained IBOutlet NSProgressIndicator* progressBar;

    __unsafe_unretained IBOutlet NSImageView* ivLookupResult;
    __unsafe_unretained IBOutlet NSProgressIndicator* indicatorLookupResult;

    __unsafe_unretained IBOutlet NSPopover* helpBlockchainContainer;
    __unsafe_unretained IBOutlet NSPopover* helpPasswordContainer;
    __unsafe_unretained IBOutlet NSLayoutConstraint* buttonTopConstraint;
    __unsafe_unretained IBOutlet NSBox* passwordBox;
    __unsafe_unretained IBOutlet NSButton* passwordButton;

    QMetaObject::Connection registeredNameFound;
    QMetaObject::Connection accountCreated;
    QMetaObject::Connection accountRemoved;

    BOOL lookupQueued;
    NSString* usernameWaitingForLookupResult;
    std::string accountToCreate;
}

NSInteger const DISPLAY_NAME_TAG                = 1;
NSInteger const BLOCKCHAIN_NAME_TAG             = 2;

//ERROR CODE for textfields validations
NSInteger const ERROR_PASSWORD_TOO_SHORT        = -1;
NSInteger const ERROR_REPEAT_MISMATCH           = -2;

@synthesize accountModel;

#define heightWithCancelAndAdvanced 468
#define defaultHeight 408

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

- (void)show
{
    [displayNameField setTag:DISPLAY_NAME_TAG];
    [registeredNameField setTag:BLOCKCHAIN_NAME_TAG];
    [displayNameField setStringValue: NSFullUserName()];
    [self controlTextDidChange:[NSNotification notificationWithName:@"PlaceHolder" object:displayNameField]];
    [photoView setWantsLayer: YES];
    photoView.layer.cornerRadius = photoView.frame.size.width / 2;
    photoView.layer.masksToBounds = YES;
    self.signUpBlockchainState = YES;
    [self toggleSignupRing:nil];
    [addProfilePhotoImage setWantsLayer: YES];
    [photoView setBordered:YES];
    [passwordButton setState: NSControlStateValueOff];
    NSRect viewFrame = creationView.frame;
    viewFrame.size.height = defaultHeight;
    creationView.frame = viewFrame;

    buttonTopConstraint.constant = 25;
    [passwordBox setHidden: YES];
    self.registeredName = @"";
    self.password = @"";
    self.repeatPassword = @"";

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

    QObject::disconnect(accountCreated);
    QObject::disconnect(accountRemoved);
    accountCreated = QObject::connect(self.accountModel,
                                      &lrc::api::NewAccountModel::accountAdded,
                                      [self] (const std::string& accountID) {
                                          if(accountID.compare(accountToCreate) != 0) {
                                              return;
                                          }
                                          QObject::disconnect(accountCreated);
                                          QObject::disconnect(accountRemoved);
                                          //set account avatar
                                          if([photoView image]) {
                                              NSImage *avatarImage = [photoView image];
                                              auto imageToBytes = QByteArray::fromNSData([avatarImage TIFFRepresentation]).toBase64();
                                              std::string imageToString = std::string(imageToBytes.constData(), imageToBytes.length());
                                              self.accountModel->setAvatar(accountID, imageToString);
                                          }
                                          //register username
                                          if (self.registeredName && ![self.registeredName isEqualToString:@""]) {
                                              NSString *passwordString = self.password ? self.password: @"";
                                              NSString *usernameString = self.registeredName;
                                              self.accountModel->registerName(accountID, [passwordString UTF8String], [usernameString UTF8String]);
                                          }
                                          lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(accountID);
                                          accountProperties.Ringtone.ringtonePath = [defaultRingtonePath() UTF8String];
                                          self.accountModel->setAccountConfig(accountID, accountProperties);
                                          [self registerDefaultPreferences];
                                          [self.delegate didCreateAccountWithSuccess:YES];
                                      });
    //if account creation failed remove loading view
    accountRemoved = QObject::connect(self.accountModel,
                                      &lrc::api::NewAccountModel::accountRemoved,
                                      [self] (const std::string& accountID) {
                                          if(accountID.compare(accountToCreate) != 0) {
                                              return;
                                          }
                                          QObject::disconnect(accountCreated);
                                          QObject::disconnect(accountRemoved);
                                          [self.delegate didCreateAccountWithSuccess:NO];
                                      });
    [self display:loadingView];
    [progressBar startAnimation:nil];

    accountToCreate = self.accountModel->createNewAccount(lrc::api::profile::Type::RING, [displayNameField.stringValue UTF8String],"",[passwordField.stringValue UTF8String], "");
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
    [self.delegate didCreateAccountWithSuccess:NO];
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
    NSRect viewFrame = creationView.frame;
    if([sender state] == NSControlStateValueOn) {
        viewFrame.size.height = heightWithCancelAndAdvanced;
        [self.delegate updateFrame: heightWithCancelAndAdvanced];
        creationView.frame = viewFrame;
        buttonTopConstraint.constant = 85;
        [passwordBox setHidden: NO];
    } else {
        buttonTopConstraint.priority = 100;
        viewFrame.size.height = defaultHeight;
        [self.delegate updateFrame: defaultHeight];
        creationView.frame = viewFrame;
        buttonTopConstraint.constant = 25;
        buttonTopConstraint.priority = 999;
        [passwordBox setHidden: YES];
    }
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

                                           });

    //Start the lookup in a second so that the UI dosen't seem to freeze
    BOOL result = NameDirectory::instance().lookupName(QString(), QString::fromNSString(usernameWaitingForLookupResult));

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
