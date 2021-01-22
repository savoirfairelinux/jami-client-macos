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
#import "AccAdvancedRingVC.h"
#import "utils.h"

//LRC
#import <api/lrc.h>
#import <api/newaccountmodel.h>
#import <api/newdevicemodel.h>
#import <api/contactmodel.h>
#import <api/contact.h>
#import <globalinstances.h>
#import <api/conversationmodel.h>

#import "delegates/ImageManipulationDelegate.h"

//Qt
#import <QtMacExtras/qmacfunctions.h>
#import <QPixmap>

@interface AccAdvancedRingVC () {
    __unsafe_unretained IBOutlet NSButton *allowIncoming;
    __unsafe_unretained IBOutlet NSTextField *nameServerField;
    __unsafe_unretained IBOutlet NSTextField *proxyServerField;
    __unsafe_unretained IBOutlet NSTextField *bootstrapServerField;
    __unsafe_unretained IBOutlet NSTextField *noDefaultModeratorsLabel;
    __unsafe_unretained IBOutlet NSButton *enableProxyButton;
    __unsafe_unretained IBOutlet NSButton *enableLocalModeratorButton;
    __unsafe_unretained IBOutlet NSButton *togleRendezVous;
     IBOutlet NSTableView* defaultModeratorsView;
     IBOutlet NSPopover* contactPickerPopoverVC;
}
@end

@implementation AccAdvancedRingVC

//Tags for views
const NSInteger  NAME_SERVER_TAG         = 100;
const NSInteger  PROXY_SERVER_TAG        = 200;
const NSInteger  BOOTSTRAP_SERVER_TAG    = 300;

-(void) updateView {
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    [allowIncoming setState: accountProperties.DHT.PublicInCalls];
    [nameServerField setStringValue: accountProperties.RingNS.uri.toNSString()];
    [proxyServerField setStringValue: accountProperties.proxyServer.toNSString()];
    [bootstrapServerField setStringValue: accountProperties.hostname.toNSString()];
    [enableProxyButton setState: accountProperties.proxyEnabled];
    [proxyServerField setEditable:accountProperties.proxyEnabled];
    [togleRendezVous setState: accountProperties.isRendezVous];
    [enableLocalModeratorButton setState: self.accountModel->isLocalModeratorsEnabled(self.selectedAccountID)];
    noDefaultModeratorsLabel.hidden = self.accountModel->getDefaultModerators(self.selectedAccountID).size() > 0;
}

-(void) viewDidLoad {
    [super viewDidLoad];
    defaultModeratorsView.delegate = self;
    defaultModeratorsView.dataSource = self;
    [[self view] setAutoresizingMask: NSViewMinXMargin | NSViewMaxXMargin | NSViewWidthSizable];
    [self updateView];
}

- (void) setSelectedAccount:(const QString&) account {
    [super setSelectedAccount: account];
    [self updateView];
}

#pragma mark - Actions

- (IBAction)allowCallFromUnknownPeer:(id)sender {
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    if(accountProperties.DHT.PublicInCalls != [sender state]) {
        accountProperties.DHT.PublicInCalls = [sender state];
        self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
    }
}

- (IBAction)enableRendezVous:(id)sender {
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    if(accountProperties.isRendezVous != [sender state]) {
        accountProperties.isRendezVous = [sender state];
        self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
    }
}

- (IBAction)enableLocalModerators:(id)sender {
    self.accountModel->enableLocalModerators(self.selectedAccountID, [sender state]);
}

- (IBAction)enableProxy:(id)sender {
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);
    if(accountProperties.proxyEnabled != [sender state]) {
        accountProperties.proxyEnabled = [sender state];
        self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
    }
    [proxyServerField setEditable:[sender state]];
}

- (IBAction) valueDidChange: (id) sender
{
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.selectedAccountID);

    switch ([sender tag]) {
        case NAME_SERVER_TAG:
            if(accountProperties.RingNS.uri != QString::fromNSString([sender stringValue])) {
                accountProperties.RingNS.uri = QString::fromNSString([sender stringValue]);
                self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
            }
            return;
        case PROXY_SERVER_TAG:
            if(accountProperties.proxyServer != QString::fromNSString([sender stringValue])) {
                accountProperties.proxyServer = QString::fromNSString([sender stringValue]);
                self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
            }
            return;
        case BOOTSTRAP_SERVER_TAG:
            if(accountProperties.hostname != QString::fromNSString([sender stringValue])) {
                accountProperties.hostname = QString::fromNSString([sender stringValue]);
                self.accountModel->setAccountConfig(self.selectedAccountID, accountProperties);
            }
            return;
        default:
            break;
    }

    [super valueDidChange:sender];
}

- (IBAction)removeModerator:(id)sender
{
    NSInteger row = [defaultModeratorsView rowForView:sender];
    if(row < 0) {
        return;
    }
    auto moderators = self.accountModel->getDefaultModerators(self.selectedAccountID);
    if ((moderators.size()-1) < row) {
        return;
    }
    auto moderator = moderators[row];
    self.accountModel->setDefaultModerator(self.selectedAccountID, moderator, false);
    NSIndexSet *indexes = [[NSIndexSet alloc] initWithIndex:row];
    [defaultModeratorsView removeRowsAtIndexes:indexes withAnimation: NSTableViewAnimationSlideUp];
    [defaultModeratorsView noteNumberOfRowsChanged];
    noDefaultModeratorsLabel.hidden = self.accountModel->getDefaultModerators(self.selectedAccountID).size() > 0;
}

- (IBAction)selectContact:(id)sender
{
    if (contactPickerPopoverVC != nullptr) {
        [contactPickerPopoverVC performClose:self];
        contactPickerPopoverVC = NULL;
    } else {
        auto* contactSelectorVC = [[ChooseContactVC alloc] initWithNibName:@"ChooseContactVC" bundle:nil];
        auto* contModel = self.accountModel->getAccountInfo(self.selectedAccountID).contactModel.get();
        [contactSelectorVC setUpCpntactPickerwithModel:self.accountModel andAccountId:self.selectedAccountID];
        contactSelectorVC.delegate = self;
        contactPickerPopoverVC = [[NSPopover alloc] init];
        [contactPickerPopoverVC setContentSize:contactSelectorVC.view.frame.size];
        [contactPickerPopoverVC setContentViewController:contactSelectorVC];
        [contactPickerPopoverVC setAnimates:YES];
        [contactPickerPopoverVC setBehavior:NSPopoverBehaviorTransient];
        [contactPickerPopoverVC setDelegate:self];
        [contactPickerPopoverVC showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSMinYEdge];
    }
}

#pragma mark - NSTextFieldDelegate methods

-(void)controlTextDidEndEditing:(NSNotification *)notif
{
    NSTextField *textField = [notif object];
    [self valueDidChange:textField];
}

#pragma mark - NSTableViewDelegate methods
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if(tableView == defaultModeratorsView) {
        NSTableCellView* moderatorCell = [tableView makeViewWithIdentifier:@"TableCellDefaultModerator" owner:self];
        NSImageView* avatar = [moderatorCell viewWithTag: 100];
        NSTextField* nameLabel = [moderatorCell viewWithTag: 200];
        NSTextField* profileNameLabel = [moderatorCell viewWithTag: 300];
        NSButton* removeModerator = [moderatorCell viewWithTag: 400];

        auto moderators = self.accountModel->getDefaultModerators(self.selectedAccountID);
        if ((moderators.size() - 1) < row) {
            return nil;
        }
        auto moderator = moderators[row];
        auto& moderatorInfo = self.accountModel->getAccountInfo(self.selectedAccountID).contactModel->getContact(moderator);
        auto convOpt = getConversationFromURI(moderatorInfo.profileInfo.uri, *self.accountModel->getAccountInfo(self.selectedAccountID).conversationModel);
        if (convOpt.has_value()) {
            lrc::api::conversation::Info& conversation = *convOpt;
            auto& imageManip = reinterpret_cast<Interfaces::ImageManipulationDelegate&>(GlobalInstances::pixmapManipulator());
            NSImage* image = QtMac::toNSImage(qvariant_cast<QPixmap>(imageManip.conversationPhoto(conversation, self.accountModel->getAccountInfo(self.selectedAccountID))));
            if(image) {
            avatar.wantsLayer = YES;
            avatar.layer.cornerRadius = avatar.frame.size.width * 0.5;
            [avatar setImage:image];
            }
        }
        [nameLabel setStringValue: bestIDForContact(moderatorInfo)];
        [profileNameLabel setStringValue: bestNameForContact(moderatorInfo)];
        [removeModerator setAction:@selector(removeModerator:)];
        [removeModerator setTarget:self];
        return moderatorCell;
    }
    return [super tableView:tableView viewForTableColumn:tableColumn row:row];
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    if(![tableView isEnabled]) {
        return nil;
    }
    return [tableView makeViewWithIdentifier:@"HoverRowView" owner:nil];
}

#pragma mark - NSTableViewDataSource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if(tableView == defaultModeratorsView) {
        return self.accountModel->getDefaultModerators(self.selectedAccountID).size();
    }
    return [super numberOfRowsInTableView:tableView];
}

#pragma mark Popover delegate

- (void)popoverWillClose:(NSNotification *)notification
{
    if (contactPickerPopoverVC != nullptr) {
        [contactPickerPopoverVC performClose:self];
        contactPickerPopoverVC = NULL;
    }
}

# pragma mark -ChooseContactVCDelegate

-(void)contactChosen:(const QString&)contactUri {
    self.accountModel->setDefaultModerator(self.selectedAccountID, contactUri, true);
    [defaultModeratorsView reloadData];
    noDefaultModeratorsLabel.hidden = self.accountModel->getDefaultModerators(self.selectedAccountID).size() > 0;
}

@end
