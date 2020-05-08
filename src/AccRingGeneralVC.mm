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
#import "AccRingGeneralVC.h"

//cocoa
#import <Quartz/Quartz.h>
#import <AVFoundation/AVFoundation.h>


//Qt
#import <QSize>
#import <QtMacExtras/qmacfunctions.h>
#import <QPixmap>

//LRC
#import <api/lrc.h>
#import <api/newaccountmodel.h>
#import <api/newdevicemodel.h>
#import <interfaces/pixmapmanipulatori.h>

#import "RegisterNameWC.h"
#import "views/NSColor+RingTheme.h"
#import "views/NSImage+Extensions.h"
#import "views/HoverTableRowView.h"
#import "views/RoundedTextField.h"
#import "ExportPasswordWC.h"
#import "utils.h"
#import "Constants.h"

@interface AccRingGeneralVC ()

@property (unsafe_unretained) IBOutlet NSTextField *displayNameField;
@property (unsafe_unretained) IBOutlet NSTextField *ringIDField;
@property (unsafe_unretained) IBOutlet NSTextField *registeredNameField;
@property (unsafe_unretained) IBOutlet NSTextField *passwordField;
@property (unsafe_unretained) IBOutlet RoundedTextField *accountStatus;
@property (unsafe_unretained) IBOutlet NSButton *registerNameButton;
@property (unsafe_unretained) IBOutlet NSButton* photoView;
@property (unsafe_unretained) IBOutlet NSButton* passwordButton;
@property (unsafe_unretained) IBOutlet NSButton* linkDeviceButton;
@property (unsafe_unretained) IBOutlet NSButton* removeAccountButton;
@property (unsafe_unretained) IBOutlet NSButton* exportAccountButton;
@property (unsafe_unretained) IBOutlet NSImageView* addProfilePhotoImage;
@property (unsafe_unretained) IBOutlet NSTableView* devicesTableView;
@property (unsafe_unretained) IBOutlet NSTableView* blockedContactsTableView;
@property (assign) IBOutlet NSLayoutConstraint* buttonRegisterWidthConstraint;
@property (assign) IBOutlet NSLayoutConstraint* bannedContactHeightConstraint;
@property (assign) IBOutlet NSLayoutConstraint* advancedButtonMarginConstraint;


@property AbstractLoadingWC* accountModal;
@property PasswordChangeWC* passwordModal;
@property QString selectedAccountID;

@end

@implementation AccRingGeneralVC

QMetaObject::Connection deviceAddedSignal;
QMetaObject::Connection deviceRevokedSignal;
QMetaObject::Connection deviceUpdatedSignal;
QMetaObject::Connection contactBlockedSignal;
QMetaObject::Connection bannedContactsChangedSignal;
QMetaObject::Connection accountStateChangedSignal;


@synthesize displayNameField;
@synthesize ringIDField;
@synthesize registeredNameField;
@synthesize photoView;
@synthesize addProfilePhotoImage;
@synthesize accountModel;
@synthesize registerNameButton, passwordButton, removeAccountButton;
@synthesize buttonRegisterWidthConstraint;
@synthesize accountModal;
@synthesize delegate;
@synthesize devicesTableView;
@synthesize blockedContactsTableView;
@synthesize linkDeviceButton;
@synthesize passwordField;
@synthesize exportAccountButton;

typedef NS_ENUM(NSInteger, TagViews) {
    DISPLAYNAME = 100,
    DEVICE_NAME_TAG = 200,
    DEVICE_ID_TAG = 300,
    DEVICE_EDIT_TAG = 400,
    DEVICE_REVOKE_TAG = 500,
    BANNED_CONTACT_NAME_TAG = 600,
    BANNED_CONTACT_ID_TAG = 700,
    UNBLOCK_CONTACT_TAG = 800
};

-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil accountmodel:(lrc::api::NewAccountModel*) accountModel
{
    if (self =  [self initWithNibName: nibNameOrNil bundle:nibBundleOrNil])
    {
        self.accountModel= accountModel;
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [addProfilePhotoImage setWantsLayer: YES];
    devicesTableView.delegate = self;
    devicesTableView.dataSource = self;
    blockedContactsTableView.delegate = self;
    blockedContactsTableView.dataSource= self;
    [[self view] setAutoresizingMask: NSViewMinXMargin | NSViewMaxXMargin | NSViewWidthSizable];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self updateView];
}

- (void) setSelectedAccount:(const QString&) account {
    self.selectedAccountID = account;
    [self connectSignals];
    [self updateView];
    [self hideBannedContacts];
}

-(void) updateView {
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
    [ringIDField setStringValue: account.profileInfo.uri.toNSString()];

    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    bool hideLocalAccountConfig = !accountProperties.managerUri.isEmpty();
    [passwordButton setHidden:hideLocalAccountConfig];
    [linkDeviceButton setHidden:hideLocalAccountConfig];
    [passwordField setHidden:hideLocalAccountConfig];
    [exportAccountButton setHidden: hideLocalAccountConfig];

    if(account.registeredName.isEmpty() && !hideLocalAccountConfig) {
        [registerNameButton setHidden:NO];
        buttonRegisterWidthConstraint.constant = 260.0;
    } else {
        buttonRegisterWidthConstraint.constant = 0.0;
        [registerNameButton setHidden:YES];
    }

    [registeredNameField setStringValue:account.registeredName.toNSString()];
    
    NSString *title = accountProperties.archiveHasPassword ?
    NSLocalizedString(@"Change password", @"Password button title") :
    NSLocalizedString(@"Create password", @"Password button title");

    [passwordButton setTitle:title];
    self.accountEnabled = account.enabled;

    NSMutableAttributedString *colorTitle = [[NSMutableAttributedString alloc] initWithAttributedString:[removeAccountButton attributedTitle]];
    NSRange titleRange = NSMakeRange(0, [colorTitle length]);
    [colorTitle addAttribute:NSForegroundColorAttributeName value:[NSColor errorColor] range:titleRange];
    [removeAccountButton setAttributedTitle:colorTitle];
    [devicesTableView reloadData];
    [blockedContactsTableView reloadData];
    self.accountStatus.bgColor = colorForAccountStatus(accountModel->getAccountInfo(self.selectedAccountID).status);
    [self.accountStatus setNeedsDisplay:YES];
}

-(void) connectSignals {
    QObject::disconnect(deviceAddedSignal);
    QObject::disconnect(deviceRevokedSignal);
    QObject::disconnect(deviceUpdatedSignal);
    QObject::disconnect(bannedContactsChangedSignal);
    QObject::disconnect(accountStateChangedSignal);
    deviceAddedSignal = QObject::connect(&*(self.accountModel->getAccountInfo(self.selectedAccountID)).deviceModel,
                                         &lrc::api::NewDeviceModel::deviceAdded,
                                         [self] (const QString& id) {
                                             [devicesTableView reloadData];
                                         });
    deviceRevokedSignal = QObject::connect(&*(self.accountModel->getAccountInfo(self.selectedAccountID)).deviceModel,
                                           &lrc::api::NewDeviceModel::deviceRevoked,
                                           [self] (const QString& id, const lrc::api::NewDeviceModel::Status status) {
                                               switch (status) {
                                                   case lrc::api::NewDeviceModel::Status::SUCCESS:
                                                       [devicesTableView reloadData];
                                                       break;
                                                   case lrc::api::NewDeviceModel::Status::WRONG_PASSWORD:
                                                       [self showAlertWithTitle: @"" andText: NSLocalizedString(@"Device revocation failed with error: Wrong password", @"Device revocation error")];
                                                       break;
                                                   case lrc::api::NewDeviceModel::Status::UNKNOWN_DEVICE:
                                                       [self showAlertWithTitle: @"" andText: NSLocalizedString(@"Device revocation failed with error: Unknown device", @"Device revocation error")];
                                                       break;
                                               }
                                           });
    deviceUpdatedSignal = QObject::connect(&*(self.accountModel->getAccountInfo(self.selectedAccountID)).deviceModel,
                                           &lrc::api::NewDeviceModel::deviceUpdated,
                                           [self] (const QString& id) {
                                               [devicesTableView reloadData];
                                           });
    bannedContactsChangedSignal = QObject::connect(&*(self.accountModel->getAccountInfo(self.selectedAccountID)).contactModel,
                                                   &lrc::api::ContactModel::bannedStatusChanged,
                                                   [self] (const QString& contactUri, bool banned) {
                                                       [blockedContactsTableView reloadData];
                                                   });
    accountStateChangedSignal = QObject::connect(self.accountModel,
                                                   &lrc::api::NewAccountModel::accountStatusChanged,
                                                   [self] (const QString& accountID) {
                                                       if(accountID != self.selectedAccountID) {
                                                           return;
                                                       }
                                                       self.accountStatus.bgColor = colorForAccountStatus(accountModel->getAccountInfo(accountID).status);
                                                       [self.accountStatus setNeedsDisplay:YES];
                                                   });
}

-(void) showAlertWithTitle: (NSString *) title andText: (NSString *)text {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:title];
    [alert setInformativeText:text];
    [alert runModal];
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
        auto image = [picker inputImage];
        CGFloat newSize = MIN(MIN(image.size.height, image.size.width), MAX_IMAGE_SIZE);
        outputImage = [outputImage imageResizeInsideMax: newSize];
        [photoView setImage: [outputImage roundCorners: outputImage.size.height * 0.5]];
        [photoView setBordered:NO];
        [addProfilePhotoImage setHidden:YES];
        auto imageToBytes = QByteArray::fromNSData([outputImage TIFFRepresentation]).toBase64();
        self.accountModel->setAvatar(self.selectedAccountID, QString(imageToBytes));
    } else if(!photoView.image) {
        [photoView setBordered:YES];
        [addProfilePhotoImage setHidden:NO];
    }
}

#pragma mark - RegisterNameDelegate methods

- (void) didRegisterName:(NSString *) name withSuccess:(BOOL) success
{
    [self.accountModal close];
    if(!success) {
        return;
    }

    if(name.length == 0) {
        return;
    }
    buttonRegisterWidthConstraint.constant = 0.0;
    [registerNameButton setHidden:YES];
    [registeredNameField setStringValue:name];
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
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
    self.accountModel->setAlias(self.selectedAccountID, QString::fromNSString(displayName));
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
}

#pragma mark - NSTableViewDataSource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if(tableView == devicesTableView) {
        return self.accountModel->getAccountInfo(self.selectedAccountID).deviceModel->getAllDevices().size();
    } else if (tableView == blockedContactsTableView){
        return self.accountModel->getAccountInfo(self.selectedAccountID).contactModel->getBannedContacts().size();
    }
    return 0;
}

#pragma mark - NSTableViewDelegate methods
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if(tableView == devicesTableView) {
        NSTableCellView* deviceView = [tableView makeViewWithIdentifier:@"TableCellDeviceItem" owner:self];
        NSTextField* nameLabel = [deviceView viewWithTag: DEVICE_NAME_TAG];
        NSTextField* idLabel = [deviceView viewWithTag: DEVICE_ID_TAG];
        NSButton* revokeButton = [deviceView viewWithTag: DEVICE_REVOKE_TAG];
        NSButton* editButton = [deviceView viewWithTag: DEVICE_EDIT_TAG];
        [editButton setAction:@selector(editDevice:)];
        [editButton setTarget:self];
        [revokeButton setAction:@selector(startDeviceRevocation:)];
        [revokeButton setTarget:self];
        auto devices = self.accountModel->getAccountInfo(self.selectedAccountID).deviceModel->getAllDevices();
        auto device = devices[row];

        auto name = device.name;
        auto deviceID = device.id;

        [nameLabel setStringValue: name.toNSString()];
        [idLabel setStringValue: deviceID.toNSString()];
        [revokeButton setHidden: device.isCurrent];
        [editButton setHidden: !device.isCurrent];
        return deviceView;
    } else if (tableView == blockedContactsTableView) {
        NSTableCellView* contactView = [tableView makeViewWithIdentifier:@"TableCellBannedContactItem" owner:self];
        NSTextField* nameLabel = [contactView viewWithTag: BANNED_CONTACT_NAME_TAG];
        NSTextField* idLabel = [contactView viewWithTag: BANNED_CONTACT_ID_TAG];
        NSButton* revokeButton = [contactView viewWithTag: UNBLOCK_CONTACT_TAG];
        auto contacts = self.accountModel->getAccountInfo(self.selectedAccountID).contactModel->getBannedContacts();
        auto contactID = contacts[row];
        [idLabel setStringValue: contactID.toNSString()];
        try {
            auto contact = self.accountModel->getAccountInfo(self.selectedAccountID).contactModel->getContact(contactID);
            [nameLabel setStringValue: bestNameForContact(contact)];
        } catch (std::out_of_range& e) {
            NSLog(@"contact out of range");
        }
        [revokeButton setAction:@selector(unblockContact:)];
        [revokeButton setTarget:self];
        return contactView;
    }
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    if(tableView == devicesTableView) {
        return tableView.rowHeight;
    } else if (tableView == blockedContactsTableView) {
        CGFloat height = self.bannedContactHeightConstraint.constant;
        if(height == 150) {
            return 52;
        } else {
            return 1;
        }
    }
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    return [tableView makeViewWithIdentifier:@"HoverRowView" owner:nil];
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

- (IBAction)startExportOnRing:(id)sender
{
    ExportPasswordWC *passwordWC = [[ExportPasswordWC alloc] initWithNibName:@"ExportPasswordWindow" bundle: nil accountmodel: self.accountModel];
    passwordWC.selectedAccountID = self.selectedAccountID;
    accountModal = passwordWC;
    [self.view.window beginSheet: passwordWC.window completionHandler:nil];
}
- (IBAction)triggerAdwancedSettings: (NSButton *)sender {
    [self.delegate triggerAdvancedOptions];
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
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel",@"Button Action")];
    [alert setMessageText: NSLocalizedString(@"Remove account",
                                             @"Remove account alert title")];
    [alert setInformativeText:NSLocalizedString(@"By clicking \"OK\" you will remove this account on this device! This action can not be undone. Also, your registered name can be lost.",
                                                @"Remove account alert message")];

    if ([alert runModal] == NSAlertFirstButtonReturn) {
        self.accountModel->removeAccount(self.selectedAccountID);
    }
}

- (IBAction)exportAccount:(id)sender
{
    NSSavePanel* filePicker = [NSSavePanel savePanel];
    NSString* name  = [self.selectedAccountID.toNSString() stringByAppendingString: @".gz"];
    [filePicker setNameFieldStringValue: name];
    if ([filePicker runModal] != NSFileHandlingPanelOKButton) {
        return;
    }
    NSString *password = @"";
    const char* fullPath = [[filePicker URL] fileSystemRepresentation];
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    if(accountProperties.archiveHasPassword) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel",@"Button Action")];
        [alert setMessageText: NSLocalizedString(@"Enter account password",
                                                 @"Backup enter password")];
        NSTextField *input = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 20)];
        [alert setAccessoryView:input];
        if ([alert runModal] != NSAlertFirstButtonReturn) {
            return;
        }
        password = [input stringValue];
    }
    if (self.accountModel->exportToFile(self.selectedAccountID, fullPath, QString::fromNSString(password))) {
        [self didCompleteExportWithPath:[filePicker URL]];
    } else {
        [self showAlertWithTitle: @"" andText: NSLocalizedString(@"An error occured during the backup", @"Backup error")];
    }
}

- (IBAction)startNameRegistration:(id)sender
{
    RegisterNameWC* registerWC = [[RegisterNameWC alloc] initWithNibName:@"RegisterNameWindow" bundle: nil accountmodel: self.accountModel];
    registerWC.delegate = self;
    registerWC.selectedAccountID = self.selectedAccountID;
    self.accountModal = registerWC;
    [self.view.window beginSheet:registerWC.window completionHandler:nil];
}
- (IBAction)changePassword:(id)sender
{
    PasswordChangeWC* passwordWC = [[PasswordChangeWC alloc] initWithNibName:@"PasswordChange" bundle: nil accountmodel: self.accountModel];
    passwordWC.selectedAccountID = self.selectedAccountID;
    passwordWC.delegate = self;
    [self.view.window beginSheet:passwordWC.window completionHandler:nil];
    self.passwordModal = passwordWC;
}

- (IBAction)showBanned: (NSButton *)sender {
    CGFloat height = self.bannedContactHeightConstraint.constant;
    NSRect frame = self.view.frame;
    if(height == 150) {
        frame.size.height =  frame.size.height - 150 - 10;
    } else {
        frame.size.height =  frame.size.height + 150 + 10;
    }
    self.view.frame = frame;
    [self.delegate updateFrame];
    CGFloat advancedHeight = self.advancedButtonMarginConstraint.constant;
    self.advancedButtonMarginConstraint.constant = (height== 2) ? 40 : 30;
    self.bannedContactHeightConstraint.constant = (height== 2) ? 150 : 2;
    [[[[self.blockedContactsTableView superview] superview] superview] setHidden:![[[[self.blockedContactsTableView superview] superview] superview] isHidden]];
    [blockedContactsTableView reloadData];
}

-(void) hideBannedContacts {
    CGFloat height = self.bannedContactHeightConstraint.constant;
    NSRect frame = self.view.frame;
    if(height == 150) {
        [self showBanned:nil];
    }
}

- (IBAction)startDeviceRevocation:(NSView*)sender
{
    NSInteger row = [devicesTableView rowForView:sender];
    if(row < 0) {
        return;
    }
    auto devices = self.accountModel->getAccountInfo(self.selectedAccountID).deviceModel->getAllDevices();
    if (devices.size() < row) {
        return;
    }
    auto device = devices[row];
    [self proceedDeviceRevokationAlert:device.id];
}

- (IBAction)unblockContact:(NSView*)sender
{
    NSInteger row = [blockedContactsTableView rowForView:sender];
    if(row < 0) {
        return;
    }
    auto contacts = self.accountModel->getAccountInfo(self.selectedAccountID).contactModel->getBannedContacts();
    auto contactID = contacts[row];
    try {
        auto contact = self.accountModel->getAccountInfo(self.selectedAccountID).contactModel->getContact(contactID);
        if(!contact.isBanned) {
            return;
        }
        self.accountModel->getAccountInfo(self.selectedAccountID).contactModel->addContact(contact);
    } catch (std::out_of_range& e) {
        NSLog(@"contact out of range");
    }
}

- (IBAction)editDevice:(NSView*)sender
{
    NSInteger row = [devicesTableView rowForView:sender];
    if(row < 0) {
        return;
    }

    NSTableCellView* deviceView = [devicesTableView viewAtColumn:0 row:row makeIfNecessary:NO];
    if(!deviceView || ![deviceView isKindOfClass:[NSTableCellView class]]) {
        return;
    }

    NSTextField* nameLabel = [deviceView viewWithTag: DEVICE_NAME_TAG];
    NSButton* editButton = [deviceView viewWithTag: DEVICE_EDIT_TAG];
    if ([nameLabel isEditable]) {
        self.accountModel->getAccountInfo(self.selectedAccountID).deviceModel->setCurrentDeviceName(QString::fromNSString(nameLabel.stringValue));
        [nameLabel setEditable:NO];
        [self.view.window makeFirstResponder:nil];
        editButton.image = [NSImage imageNamed:NSImageNameTouchBarComposeTemplate];
        return;
    }
    [nameLabel setEditable:YES];
    [nameLabel becomeFirstResponder];
    editButton.image = [NSImage imageNamed:NSImageNameTouchBarDownloadTemplate];
}

-(void) revokeDeviceWithID: (const QString&) deviceID password:(NSString *) password {
    self.accountModel->getAccountInfo(self.selectedAccountID).deviceModel->revokeDevice(deviceID, QString::fromNSString(password));
}

-(void) proceedDeviceRevokationAlert: (const QString&) deviceID {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Button Action")];
    [alert setMessageText:NSLocalizedString(@"Revoke Device", @"Device revocation title")];
    [alert setInformativeText:NSLocalizedString(@"Attention! This action could not be undone!",
                                                @"Device revocation message")];
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    if(accountProperties.archiveHasPassword) {
        NSSecureTextField *passwordText = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
        [passwordText setPlaceholderString:NSLocalizedString(@"Enter account password", @"Backup enter password")];
        [alert setAccessoryView:passwordText];
        if ([alert runModal] == NSAlertFirstButtonReturn) {
            [self revokeDeviceWithID:deviceID password:[passwordText stringValue]];
        }
    } else {
        if ([alert runModal] == NSAlertFirstButtonReturn) {
            [self revokeDeviceWithID:deviceID password:@""];
        }
    }
}

#pragma mark - BackupAccountDelegate methods

-(void) didCompleteExportWithPath:(NSURL*) fileUrl
{
    [[NSWorkspace sharedWorkspace] selectFile:fileUrl.path inFileViewerRootedAtPath:@""];
}

#pragma mark - PasswordChangeDelegate

-(void) paswordCreatedWithSuccess:(BOOL) success
{
    NSString *title = success ? NSLocalizedString(@"Change password", @"Password button title") :
    NSLocalizedString(@"Create password", @"Password button title");
    [passwordButton setTitle: title];
}

@end
