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

//Qt
#import <QUrl>

//LRC
#import <accountmodel.h>
#import <protocolmodel.h>
#import <QItemSelectionModel>
#import <account.h>
#import <certificate.h>

#import "AppDelegate.h"
#import "Constants.h"
#import "views/NSColor+RingTheme.h"

@implementation RingWizardWC {
    __unsafe_unretained IBOutlet NSTextField* nicknameField;
    __unsafe_unretained IBOutlet NSProgressIndicator* progressBar;
    __unsafe_unretained IBOutlet NSTextField* indicationLabel;
    __unsafe_unretained IBOutlet NSButton* createButton;
    __unsafe_unretained IBOutlet NSButton* showCustomCertsButton;
    IBOutlet NSView *securityContainer;

    __unsafe_unretained IBOutlet NSButton* shareButton;
    __unsafe_unretained IBOutlet NSSecureTextField* passwordField;
    __unsafe_unretained IBOutlet NSView* pvkContainer;
    __unsafe_unretained IBOutlet NSPathControl* certificatePathControl;
    __unsafe_unretained IBOutlet NSPathControl* caListPathControl;
    __unsafe_unretained IBOutlet NSPathControl* pvkPathControl;
    BOOL isExpanded;
    Account* accountToCreate;
}

NSInteger const PVK_PASSWORD_TAG    = 0;
NSInteger const NICKNAME_TAG        = 1;

- (void)windowDidLoad {
    [super windowDidLoad];

    [passwordField setTag:PVK_PASSWORD_TAG];
    [nicknameField setTag:NICKNAME_TAG];

    isExpanded = false;
    [self.window setBackgroundColor:[NSColor ringGreyHighlight]];

    AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];

    if(![appDelegate checkForRingAccount]) {
        accountToCreate = AccountModel::instance().add(QString::fromNSString(NSFullUserName()), Account::Protocol::RING);
        [nicknameField setStringValue:NSFullUserName()];
        [self controlTextDidChange:[NSNotification notificationWithName:@"PlaceHolder" object:nicknameField]];
    } else {
        [indicationLabel setStringValue:NSLocalizedString(@"Ring is already ready to work",
                                                          @"Display message to user")];
        auto accList = AccountModel::instance().getAccountsByProtocol(Account::Protocol::RING);
        [self displayHash:accList[0]->username().toNSString()];
    }

    [caListPathControl setDelegate:self];
    [certificatePathControl setDelegate:self];
    [pvkPathControl setDelegate:self];
}

- (void) displayHash:(NSString* ) hash
{
    [nicknameField setFrameSize:NSMakeSize(400, nicknameField.frame.size.height)];
    [nicknameField setStringValue:hash];
    [nicknameField setEditable:NO];
    [nicknameField setHidden:NO];

    [showCustomCertsButton setHidden:YES];

    [shareButton setHidden:NO];
    [shareButton sendActionOn:NSLeftMouseDownMask];

    NSSharingService* emailSharingService = [NSSharingService sharingServiceNamed:NSSharingServiceNameComposeEmail];

    [createButton setTitle:NSLocalizedString(@"Continue",
                                             @"Continue button")];
    [createButton setAction:@selector(goToApp:)];
}

- (IBAction)shareRingID:(id)sender {
    NSSharingServicePicker* sharingServicePicker = [[NSSharingServicePicker alloc] initWithItems:[NSArray arrayWithObject:[nicknameField stringValue]]];
    [sharingServicePicker showRelativeToRect:[sender bounds]
                                      ofView:sender
                               preferredEdge:NSMinYEdge];
}

- (IBAction)createRingAccount:(id)sender
{
    [nicknameField setHidden:YES];
    [progressBar setHidden:NO];
    [createButton setHidden:YES];
    [progressBar startAnimation:nil];
    [indicationLabel setStringValue:NSLocalizedString(@"Just a moment...",
                                                      @"Indication for user")];

    QModelIndex qIdx =  AccountModel::instance().protocolModel()->selectionModel()->currentIndex();

    [self setCallback];
    if (isExpanded) {
        // retract panel
        [self chooseOwnCertificates:nil];
    }
    [showCustomCertsButton setHidden:YES];

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

- (IBAction)chooseOwnCertificates:(NSButton*)sender
{
    if (isExpanded) {
        [securityContainer removeFromSuperview];
        NSRect frame = [self.window frame];
        frame.size = CGSizeMake(securityContainer.frame.size.width, frame.size.height - securityContainer.frame.size.height);
        frame.origin.y = frame.origin.y + securityContainer.frame.size.height;
        [self.window setFrame:frame display:YES animate:YES];
        isExpanded = false;
        [sender setImage:[NSImage imageNamed:@"NSAddTemplate"]];
    } else {
        NSRect frame = [self.window frame];
        frame.size = CGSizeMake(securityContainer.frame.size.width, frame.size.height + securityContainer.frame.size.height);
        frame.origin.y = frame.origin.y - securityContainer.frame.size.height;
        [self.window setFrame:frame display:YES animate:YES];

        [securityContainer setFrameOrigin:CGPointMake(0, 50)];
        [self.window.contentView addSubview:securityContainer];
        isExpanded = true;
        [sender setImage:[NSImage imageNamed:@"NSRemoveTemplate"]];
    }
}

- (IBAction)goToApp:(id)sender
{
    [self.window close];
    AppDelegate* appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
    [appDelegate showMainWindow];
}

#pragma mark - NSPathControl delegate methods

- (IBAction)caListPathControlSingleClick:(id)sender
{
    NSURL* fileURL;
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        fileURL = nil;
    } else {
        fileURL = [[sender clickedPathComponentCell] URL];
    }
    [self->caListPathControl setURL:fileURL];
    accountToCreate->setTlsCaListCertificate([[fileURL path] UTF8String]);

}

- (IBAction)certificatePathControlSingleClick:(id)sender
{
    NSURL* fileURL;
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        fileURL = nil;
    } else {
        fileURL = [[sender clickedPathComponentCell] URL];
    }
    [self->certificatePathControl setURL:fileURL];
    accountToCreate->setTlsCertificate([[fileURL path] UTF8String]);

    auto cert = accountToCreate->tlsCertificate();

    if (cert) {
        [pvkContainer setHidden:!cert->requirePrivateKey()];
    } else {
        [pvkContainer setHidden:YES];
    }

}

- (IBAction)pvkFilePathControlSingleClick:(id)sender
{
    NSURL* fileURL;
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        fileURL = nil;
    } else {
        fileURL = [[sender clickedPathComponentCell] URL];
    }
    [self->pvkPathControl setURL:fileURL];
    accountToCreate->setTlsPrivateKey([[fileURL path] UTF8String]);

    if(accountToCreate->tlsCertificate()->requirePrivateKeyPassword()) {
        [passwordField setHidden:NO];
    } else {
        [passwordField setHidden:YES];
    }
}

/*
 Delegate method of NSPathControl to determine how the NSOpenPanel will look/behave.
 */
- (void)pathControl:(NSPathControl *)pathControl willDisplayOpenPanel:(NSOpenPanel *)openPanel
{
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    [openPanel setResolvesAliases:YES];

    if(pathControl == caListPathControl) {
        [openPanel setTitle:NSLocalizedString(@"Choose a CA list", @"Open panel title")];
    } else if (pathControl == certificatePathControl) {
        [openPanel setTitle:NSLocalizedString(@"Choose a certificate", @"Open panel title")];
    } else {
        [openPanel setTitle:NSLocalizedString(@"Choose a private key file", @"Open panel title")];
    }

    [openPanel setPrompt:NSLocalizedString(@"Choose", @"Open panel prompt for 'Choose a file'")];
    [openPanel setDelegate:self];
}

- (void)pathControl:(NSPathControl *)pathControl willPopUpMenu:(NSMenu *)menu
{
    NSMenuItem *item;
    if(pathControl == caListPathControl) {
        item = [menu addItemWithTitle:NSLocalizedString(@"Remove value", @"Contextual menu entry")
                               action:@selector(caListPathControlSingleClick:) keyEquivalent:@""];
    } else if (pathControl == certificatePathControl) {
        item = [menu addItemWithTitle:NSLocalizedString(@"Remove value", @"Contextual menu entry")
                               action:@selector(certificatePathControlSingleClick:) keyEquivalent:@""];
    } else {
        item = [menu addItemWithTitle:NSLocalizedString(@"Remove value", @"Contextual menu entry")
                               action:@selector(pvkFilePathControlSingleClick:) keyEquivalent:@""];
    }
    [item setTarget:self]; // or whatever target you want
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
    if (textField.tag == PVK_PASSWORD_TAG) {
        accountToCreate->setTlsPassword([textField.stringValue UTF8String]);
        return;
    }

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
