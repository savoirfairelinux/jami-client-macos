/*
 *  Copyright (C) 2015-2019 Savoir-faire Linux Inc.
 *  Author: Alexandre Lision <alexandre.lision@savoirfairelinux.com>
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

//cocoa
#import <Quartz/Quartz.h>
#import <AVFoundation/AVFoundation.h>

//Qt
#import <QSize>
#import <QtMacExtras/qmacfunctions.h>
#import <QPixmap>
#import <qstring.h>

//LRC
#import <api/lrc.h>
#import <api/newaccountmodel.h>
#import <api/newdevicemodel.h>
#import <interfaces/pixmapmanipulatori.h>

#import "AccSipGeneralVC.h"
#import "views/NSColor+RingTheme.h"
#import "views/NSImage+Extensions.h"
#import "Constants.h"

@interface AccSipGeneralVC ()

@property (unsafe_unretained) IBOutlet NSButton* photoView;
@property (unsafe_unretained) IBOutlet NSImageView* addProfilePhotoImage;
@property (unsafe_unretained) IBOutlet NSTextField* displayNameField;
@property (unsafe_unretained) IBOutlet NSTextField* userNameField;
@property (unsafe_unretained) IBOutlet NSSecureTextField* passwordField;
@property (unsafe_unretained) IBOutlet NSTextField* proxyField;
@property (unsafe_unretained) IBOutlet NSTextField* voicemailField;
@property (unsafe_unretained) IBOutlet NSTextField* serverField;
@property (unsafe_unretained) IBOutlet NSButton* removeAccountButton;
@property (unsafe_unretained) IBOutlet NSButton* editAccountButton;
@property QString selectedAccountID;

@end

@implementation AccSipGeneralVC

//Tags for views
typedef NS_ENUM(NSInteger, TagViews) {
    DISPLAYNAME = 100
};

@synthesize accountModel;
@synthesize delegate;
@synthesize photoView,addProfilePhotoImage,displayNameField, userNameField, passwordField,proxyField,voicemailField, serverField, removeAccountButton, editAccountButton;

-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil accountmodel:(lrc::api::NewAccountModel*) accountModel
{
    if (self =  [self initWithNibName: nibNameOrNil bundle:nibBundleOrNil])
    {
        self.accountModel= accountModel;
    }
    return self;
}

-(void)viewDidLoad {
    [super viewDidLoad];
    [[self view] setAutoresizingMask: NSViewMinXMargin | NSViewMaxXMargin];
    [addProfilePhotoImage setWantsLayer: YES];
    [self setEditingMode:NO];
    [self updateView];
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
        [photoView setImage: [outputImage roundCorners: outputImage.size.height * 0.5]];
        [addProfilePhotoImage setHidden:YES];
        auto imageToBytes = QByteArray::fromNSData([outputImage TIFFRepresentation]).toBase64();
        self.accountModel->setAvatar(self.selectedAccountID, QString(imageToBytes));
    } else if(!photoView.image) {
        [photoView setBordered:YES];
        [addProfilePhotoImage setHidden:NO];
    }
}

#pragma mark - NSTextFieldDelegate methods

- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor
{
    return YES;
}

- (IBAction)triggerAdwancedSettings: (NSButton *)sender {
     [self.delegate triggerAdvancedOptions];
}

- (void) setSelectedAccount:(const QString&) account {
    self.selectedAccountID = account;
    [self updateView];
}

-(void)updateView {
    const auto& account = accountModel->getAccountInfo(self.selectedAccountID);
    NSData *imageData = [[NSData alloc] initWithBase64EncodedString:account.profileInfo.avatar.toNSString() options:NSDataBase64DecodingIgnoreUnknownCharacters];
    NSImage *image = [[NSImage alloc] initWithData:imageData];
    if(image) {
        [photoView setBordered:NO];
        [photoView setImage: [image roundCorners: image.size.height * 0.5]];
        [addProfilePhotoImage setHidden:YES];
    } else {
        [photoView setImage:nil];
        [photoView setBordered:YES];
        [addProfilePhotoImage setHidden:NO];
    }
    NSString* displayName = account.profileInfo.alias.toNSString();
    [displayNameField setStringValue:displayName];

    NSMutableAttributedString *colorTitle = [[NSMutableAttributedString alloc] initWithAttributedString:[removeAccountButton attributedTitle]];
    NSRange titleRange = NSMakeRange(0, [colorTitle length]);
    [colorTitle addAttribute:NSForegroundColorAttributeName value:[NSColor errorColor] range:titleRange];
    [removeAccountButton setAttributedTitle:colorTitle];
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    [passwordField setStringValue: accountProperties.password.toNSString()];
    [proxyField setStringValue: accountProperties.routeset.toNSString()];
    [userNameField setStringValue: accountProperties.username.toNSString()];
    [serverField setStringValue: accountProperties.hostname.toNSString()];
    [voicemailField setStringValue: accountProperties.mailbox.toNSString()];
    self.accountEnabled = account.enabled;
}

#pragma mark - Actions

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

    [pictureTaker beginPictureTakerSheetForWindow:[self.view window]
                                     withDelegate:self
                                   didEndSelector:@selector(pictureTakerDidEnd:returnCode:contextInfo:)
                                      contextInfo:nil];

}

- (IBAction)enableAccount: (NSButton *)sender {
    const auto& account = accountModel->getAccountInfo(self.selectedAccountID);
    self.accountModel->setAccountEnabled(self.selectedAccountID, !account.enabled);
    self.accountEnabled = account.enabled;
}

- (IBAction)removeAccount:(id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setMessageText: NSLocalizedString(@"Remove account",
                                             @"Remove account alert title")];
    [alert setInformativeText:NSLocalizedString(@"By clicking \"OK\" you will remove this account on this device! This action can not be undone. Also, your registered name can be lost.",
                                                @"Remove account alert message")];

    if ([alert runModal] == NSAlertFirstButtonReturn) {
        self.accountModel->removeAccount(self.selectedAccountID);
    }
}

- (IBAction)changeEditingMode:(id)sender
{
    if([userNameField isEditable]) {
        [self setEditingMode:NO];
        [self saveAccount];
        return;
    }
    [self setEditingMode:YES];
}

-(void) setEditingMode:(BOOL) shouldEdit {
    [userNameField setEditable:shouldEdit];
    [passwordField setEditable:shouldEdit];
    [proxyField setEditable:shouldEdit];
    [voicemailField setEditable:shouldEdit];
    [serverField setEditable:shouldEdit];
    [userNameField setDrawsBackground:!shouldEdit];
    [passwordField setDrawsBackground:!shouldEdit];
    [proxyField setDrawsBackground:!shouldEdit];
    [voicemailField setDrawsBackground:!shouldEdit];
    [serverField setDrawsBackground:!shouldEdit];
    [userNameField setBezeled:shouldEdit];
    [passwordField setBezeled:shouldEdit];
    [proxyField setBezeled:shouldEdit];
    [voicemailField setBezeled:shouldEdit];
    [serverField setBezeled:shouldEdit];
    if(shouldEdit) {
        [serverField setBezelStyle:NSTextFieldSquareBezel];
        [userNameField setBezelStyle:NSTextFieldSquareBezel];
        [passwordField setBezelStyle:NSTextFieldSquareBezel];
        [proxyField setBezelStyle:NSTextFieldSquareBezel];
        [voicemailField setBezelStyle:NSTextFieldSquareBezel];
        [userNameField becomeFirstResponder];
        [editAccountButton setTitle:@"Done"];
        return;
    }
    [editAccountButton setTitle:@"Edit Account"];
    [self.view resignFirstResponder];
}

-(void) saveAccount {
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    accountProperties.hostname = [serverField.stringValue UTF8String];
    accountProperties.password = [passwordField.stringValue UTF8String];
    accountProperties.username = [userNameField.stringValue UTF8String];
    accountProperties.routeset = [proxyField.stringValue UTF8String];
    accountProperties.mailbox = [voicemailField.stringValue UTF8String];
    self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
}

#pragma mark - NSTextFieldDelegate delegate methods

- (void)controlTextDidChange:(NSNotification *)notif
{
    NSTextField* textField = [notif object];
    if (textField.tag != DISPLAYNAME) {
        return;
    }
    NSString* displayName = textField.stringValue;

    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    self.accountModel->setAlias(self.selectedAccountID, [displayName UTF8String]);
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
}

@end
