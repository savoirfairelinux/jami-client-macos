/*
 *  Copyright (C) 2015-2016 Savoir-faire Linux Inc.
 *  Author: Alexandre Lision <alexandre.lision@savoirfairelinux.com>
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
#import "RingWizardWC.h"

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

@implementation RingWizardWC {

    __unsafe_unretained IBOutlet NSButton* photoView;
    __unsafe_unretained IBOutlet NSTextField* nicknameField;
    __unsafe_unretained IBOutlet NSProgressIndicator* progressBar;
    __unsafe_unretained IBOutlet NSTextField* indicationLabel;
    __unsafe_unretained IBOutlet NSButton* createButton;

    Account* accountToCreate;
}

NSInteger const NICKNAME_TAG        = 1;

- (void)windowDidLoad {
    [super windowDidLoad];

    [nicknameField setTag:NICKNAME_TAG];

    [self.window setBackgroundColor:[NSColor ringGreyHighlight]];

    AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];

    if(![appDelegate checkForRingAccount]) {
        accountToCreate = AccountModel::instance().add(QString::fromNSString(NSFullUserName()), Account::Protocol::RING);

        [nicknameField setStringValue:NSFullUserName()];
        [self controlTextDidChange:[NSNotification notificationWithName:@"PlaceHolder" object:nicknameField]];
    }

    NSData* imgData = [[[ABAddressBook sharedAddressBook] me] imageData];
    if (imgData != nil) {
        [photoView setImage:[[NSImage alloc] initWithData:imgData]];
    } else
        [photoView setImage:[NSImage imageNamed:@"default_user_icon"]];

    [photoView setWantsLayer: YES];
    photoView.layer.cornerRadius = photoView.frame.size.width / 2;
    photoView.layer.masksToBounds = YES;
}

- (IBAction) editPhoto:(id)sender
{
    auto pictureTaker = [IKPictureTaker pictureTaker];
    [pictureTaker beginPictureTakerSheetForWindow:self.window
                                     withDelegate:self
                                   didEndSelector:@selector(pictureTakerDidEnd:returnCode:contextInfo:)
                                      contextInfo:nil];
}

- (void) pictureTakerDidEnd:(IKPictureTaker *) picker
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
    [progressBar startAnimation:nil];
    [indicationLabel setStringValue:NSLocalizedString(@"Just a moment...",
                                                      @"Indication for user")];

    if (auto profile = ProfileModel::instance().selectedProfile()) {
        profile->person()->setFormattedName([[nicknameField stringValue] UTF8String]);
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
- (void) registerDefaultPreferences
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

- (void) saveAccount
{
    accountToCreate->setUpnpEnabled(YES); // Always active upnp
    accountToCreate << Account::EditAction::SAVE;
}

- (void) setCallback
{
    QObject::connect(&AccountModel::instance(),
                     &AccountModel::accountStateChanged,
                     [=](Account *account, const Account::RegistrationState state) {
                         [self.window close];
                         AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
                         [appDelegate showMainWindow];
                     });
}

- (IBAction)goToApp:(id)sender
{
    [self.window close];
    AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
    [appDelegate showMainWindow];
}

#pragma mark - NSOpenSavePanelDelegate delegate methods

- (BOOL)panel:(id)sender validateURL:(NSURL *)url error:(NSError **)outError
{
    return YES;
}

#pragma mark - NSTextFieldDelegate methods

-(void)controlTextDidChange:(NSNotification *)notif
{
    NSTextField* textField = [notif object];
    // else it is NICKNAME_TAG field
    NSString* alias = textField.stringValue;
    if ([alias isEqualToString:@""]) {
        alias = NSLocalizedString(@"Unknown", @"Name used when user leave field empty");
    }
    accountToCreate->setAlias([alias UTF8String]);
    accountToCreate->setDisplayName([alias UTF8String]);
}

# pragma NSWindowDelegate methods

- (void)windowWillClose:(NSNotification *)notification
{
    AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
    if ([appDelegate checkForRingAccount]) {
        [appDelegate showMainWindow];
    }
}

@end
