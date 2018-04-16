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

#import "AccountsVC.h"

// Qt
#import <QItemSelectionModel>
#import <QSortFilterProxyModel>
#import <QtCore/qdir.h>
#import <QtCore/qstandardpaths.h>

// LRC
#import <accountmodel.h>
#import <protocolmodel.h>
#import <account.h>

#import "QNSTreeController.h"
#import "AccGeneralVC.h"
#import "AccMediaVC.h"
#import "AccAdvancedVC.h"
#import "AccSecurityVC.h"
#import "AccRingVC.h"
#import "AccDevicesVC.h"
#import "BackupAccountWC.h"
#import "RestoreAccountWC.h"
#import "RingWizardWC.h"
#import "AccBannedContactsVC.h"

@interface AccountsVC () <BackupAccountDelegate, RestoreAccountDelegate>

@property (assign) IBOutlet NSPopUpButton *protocolList;

@property (assign) IBOutlet NSTabView *configPanels;
@property (retain) IBOutlet NSTabViewItem *generalTabItem;
@property (retain) IBOutlet NSTabViewItem *mediaTabItem;
@property (retain) IBOutlet NSTabViewItem *advancedTabItem;
@property (retain) IBOutlet NSTabViewItem *securityTabItem;
@property (retain) IBOutlet NSTabViewItem *ringTabItem;
@property (retain) IBOutlet NSTabViewItem *ringDevicesTabItem;
@property (retain) IBOutlet NSTabViewItem *bannedListTabItem;

@property QNSTreeController *treeController;
@property (assign) IBOutlet NSOutlineView *accountsListView;
@property (assign) IBOutlet NSTabView *accountDetailsView;
@property (unsafe_unretained) IBOutlet NSButton* exportAccountButton;

@property AccRingVC* ringVC;
@property AccDevicesVC* devicesVC;
@property AccGeneralVC* generalVC;
@property AccMediaVC* audioVC;
@property AccAdvancedVC* advancedVC;
@property AccBannedContactsVC* bannedContactsVC;
@property AccSecurityVC* securityVC;
@property AbstractLoadingWC* accountModal;
@property RingWizardWC* wizard;

@end

@implementation AccountsVC
@synthesize protocolList;
@synthesize configPanels;
@synthesize generalTabItem;
@synthesize mediaTabItem;
@synthesize advancedTabItem;
@synthesize securityTabItem;
@synthesize ringTabItem;
@synthesize ringDevicesTabItem;
@synthesize accountsListView;
@synthesize accountDetailsView;
@synthesize treeController;
@synthesize accountModal;
@synthesize wizard;
@synthesize bannedListTabItem;

NSInteger const TAG_CHECK       =   100;
NSInteger const TAG_NAME        =   200;
NSInteger const TAG_STATUS      =   300;
NSInteger const TAG_TYPE        =   400;

QMetaObject::Connection accountChangedConnection, selectedAccountChangedConnection, accountTypeChangedConnection;


- (void)awakeFromNib
{
    treeController = [[QNSTreeController alloc] initWithQModel:&AccountModel::instance()];
    [treeController setAvoidsEmptySelection:NO];
    [treeController setAlwaysUsesMultipleValuesMarker:YES];
    [treeController setChildrenKeyPath:@"children"];

    [accountsListView bind:@"content" toObject:treeController withKeyPath:@"arrangedObjects" options:nil];
    [accountsListView bind:@"sortDescriptors" toObject:treeController withKeyPath:@"sortDescriptors" options:nil];
    [accountsListView bind:@"selectionIndexPaths" toObject:treeController withKeyPath:@"selectionIndexPaths" options:nil];

    QObject::disconnect(accountChangedConnection);
    QObject::disconnect(selectedAccountChangedConnection);

    accountChangedConnection = QObject::connect(&AccountModel::instance(),
                     &QAbstractItemModel::dataChanged,
                     [=](const QModelIndex &topLeft, const QModelIndex &bottomRight) {
                        [accountsListView reloadDataForRowIndexes:
                        [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(topLeft.row(), bottomRight.row() + 1)]
                        columnIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, accountsListView.tableColumns.count)]];
                     });

    selectedAccountChangedConnection = QObject::connect(AccountModel::instance().selectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {
                         [accountDetailsView setHidden:!current.isValid()];
                         if(!current.isValid()) {
                             [accountsListView deselectAll:nil];
                             return;
                         }

                        [treeController setSelectionQModelIndex:current];
                     });
    AccountModel::instance().selectionModel()->clearCurrentIndex();


    QModelIndex qProtocolIdx = AccountModel::instance().protocolModel()->selectionModel()->currentIndex();
    [self.protocolList addItemWithTitle:
                           AccountModel::instance().protocolModel()->data(qProtocolIdx, Qt::DisplayRole).toString().toNSString()];
    QObject::disconnect(accountTypeChangedConnection);
    accountTypeChangedConnection = QObject::connect(AccountModel::instance().protocolModel()->selectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {
                         if (!current.isValid()) {
                             return;
                         }
                         [protocolList removeAllItems];
                         [protocolList addItemWithTitle:AccountModel::instance().protocolModel()->data(current, Qt::DisplayRole).toString().toNSString()];
                     });

    self.generalVC = [[AccGeneralVC alloc] initWithNibName:@"AccGeneral" bundle:nil];
    [[self.generalVC view] setFrame:[self.generalTabItem.view frame]];
    [[self.generalVC view] setBounds:[self.generalTabItem.view bounds]];
    [self.generalTabItem setView:self.generalVC.view];

    self.audioVC = [[AccMediaVC alloc] initWithNibName:@"AccMedia" bundle:nil];
    [[self.audioVC view] setFrame:[self.mediaTabItem.view frame]];
    [[self.audioVC view] setBounds:[self.mediaTabItem.view bounds]];
    [self.mediaTabItem setView:self.audioVC.view];

    self.advancedVC = [[AccAdvancedVC alloc] initWithNibName:@"AccAdvanced" bundle:nil];
    [[self.advancedVC view] setFrame:[self.advancedTabItem.view frame]];
    [[self.advancedVC view] setBounds:[self.advancedTabItem.view bounds]];
    [self.advancedTabItem setView:self.advancedVC.view];

    self.securityVC = [[AccSecurityVC alloc] initWithNibName:@"AccSecurity" bundle:nil];
    [[self.securityVC view] setFrame:[self.securityTabItem.view frame]];
    [[self.securityVC view] setBounds:[self.securityTabItem.view bounds]];
    [self.securityTabItem setView:self.securityVC.view];

    self.ringVC = [[AccRingVC alloc] initWithNibName:@"AccRing" bundle:nil];
    [[self.ringVC view] setFrame:[self.ringTabItem.view frame]];
    [[self.ringVC view] setBounds:[self.ringTabItem.view bounds]];
    [self.ringTabItem setView:self.ringVC.view];

    self.devicesVC = [[AccDevicesVC alloc] initWithNibName:@"AccDevices" bundle:nil];
    [[self.devicesVC view] setFrame:[self.ringDevicesTabItem.view frame]];
    [[self.devicesVC view] setBounds:[self.ringDevicesTabItem.view bounds]];
    [self.ringDevicesTabItem setView:self.devicesVC.view];

    self.bannedContactsVC = [[AccBannedContactsVC alloc] initWithNibName:@"AccBannedContacts" bundle:nil];
    [[self.bannedContactsVC view] setFrame:[self.bannedListTabItem.view frame]];
    [[self.bannedContactsVC view] setBounds:[self.bannedListTabItem.view bounds]];
    [self.bannedListTabItem setView:self.bannedContactsVC.view];
}

- (void) setupSIPPanels
{
    // Start by removing all tabs
    for(NSTabViewItem* item in configPanels.tabViewItems) {
        [configPanels removeTabViewItem:item];
    }
    [configPanels insertTabViewItem:generalTabItem atIndex:0];
    [configPanels insertTabViewItem:mediaTabItem atIndex:1];
    [configPanels insertTabViewItem:advancedTabItem atIndex:2];
    [configPanels insertTabViewItem:securityTabItem atIndex:3];
}

- (void) setupRINGPanels
{
    // Start by removing all tabs
    for(NSTabViewItem* item in configPanels.tabViewItems) {
        [configPanels removeTabViewItem:item];
    }

    [configPanels insertTabViewItem:ringTabItem atIndex:0];
    [configPanels insertTabViewItem:ringDevicesTabItem atIndex:1];
    [configPanels insertTabViewItem:mediaTabItem atIndex:2];
    [configPanels insertTabViewItem:advancedTabItem atIndex:3];
    [configPanels insertTabViewItem:bannedListTabItem atIndex:4];
}

- (IBAction)toggleAccount:(NSButton*)sender {
    NSInteger row = [accountsListView rowForView:sender];
    auto accountToToggle = AccountModel::instance().getAccountByModelIndex(AccountModel::instance().index(row));
    accountToToggle->setEnabled(sender.state);
    accountToToggle << Account::EditAction::SAVE;
}

#pragma mark - NSOutlineViewDelegate methods

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item;
{
    return YES;
}

- (NSTableRowView *)outlineView:(NSOutlineView *)outlineView rowViewForItem:(id)item
{
    return [outlineView makeViewWithIdentifier:@"HoverRowView" owner:nil];
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    NSTableView* result = [outlineView makeViewWithIdentifier:@"AccountView" owner:self];

    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    if(!qIdx.isValid())
        return result;

    NSTextField* nameLabel = [result viewWithTag:TAG_NAME];
    NSTextField* stateLabel = [result viewWithTag:TAG_STATUS];
    NSButton* checkButton = [result viewWithTag:TAG_CHECK];
    NSTextField* typeLabel = [result viewWithTag:TAG_TYPE];

    auto account = AccountModel::instance().getAccountByModelIndex(qIdx);
    auto humanState = account->toHumanStateName();

    [nameLabel setStringValue:account->alias().toNSString()];
    [stateLabel setStringValue:humanState.toNSString()];

    switch (account->protocol()) {
        case Account::Protocol::SIP:
            [typeLabel setStringValue:@"SIP"];
            break;
        case Account::Protocol::RING:
            [typeLabel setStringValue:@"RING"];
            break;
        default:
            break;
    }

    switch (account->registrationState()) {
        case Account::RegistrationState::READY:
            [stateLabel setTextColor:[NSColor colorWithCalibratedRed:116/255.0 green:179/255.0 blue:93/255.0 alpha:1.0]];
            break;
        case Account::RegistrationState::TRYING:
            [stateLabel setTextColor:[NSColor redColor]];
            break;
        case Account::RegistrationState::UNREGISTERED:
            [stateLabel setTextColor:[NSColor blackColor]];
            break;
        case Account::RegistrationState::ERROR:
            [stateLabel setTextColor:[NSColor redColor]];
            break;
        default:
            [stateLabel setTextColor:[NSColor blackColor]];
            break;
    }

    [checkButton setState:qIdx.data(Qt::CheckStateRole).value<BOOL>()];

    return result;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    // ask the tree controller for the current selection
    [self.exportAccountButton setEnabled:[[treeController selectedNodes] count] > 0];
    if([[treeController selectedNodes] count] > 0) {
        auto qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
        //Update details view
        auto acc = AccountModel::instance().getAccountByModelIndex(qIdx);
        AccountModel::instance().selectionModel()->setCurrentIndex(qIdx, QItemSelectionModel::ClearAndSelect);

        switch (acc->protocol()) {
            case Account::Protocol::SIP:
                [self setupSIPPanels];
                break;
            case Account::Protocol::RING:
                [self setupRINGPanels];
                break;
            default:
                break;
        }

        [self.accountDetailsView setHidden:NO];
    } else {
        AccountModel::instance().selectionModel()->clearCurrentIndex();
    }
}

#pragma mark - Delete account

- (IBAction)removeAccount:(id)sender
{
    AccountModel::instance().remove(AccountModel::instance().selectedAccount());
    AccountModel::instance().save();
}

#pragma mark - Advanced menu methods

- (IBAction)advancedActionsClicked:(NSButton *)sender
{
    NSMenu* menu = [[NSMenu alloc] init];

    auto backupItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Backup account", @"Contextual menu entry")
                               action:@selector(backupAccount:)
                        keyEquivalent:@""];

    if(treeController.selectedNodes.count == 0) {
        // Use a fake selector, to grey out the Backup entry in the menu
        [backupItem setAction:@selector(disable:)];
    }

    [menu insertItem:backupItem atIndex:0];

    [menu insertItemWithTitle:NSLocalizedString(@"Restore account", @"Contextual menu entry")
                       action:@selector(restoreAccount:)
                keyEquivalent:@""
                      atIndex:0];

    [NSMenu popUpContextMenu:menu withEvent:[self forgedEventForButton:sender] forView:(NSButton *)sender];
}

- (void) backupAccount:(NSMenuItem*) sender
{
    auto passwordWC = [[BackupAccountWC alloc] initWithDelegate:self];
#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_9
    [self.view.window beginSheet:passwordWC.window completionHandler:nil];
#else
    [NSApp beginSheet: passwordWC.window
       modalForWindow: self.view.window
        modalDelegate: self
       didEndSelector: nil
          contextInfo: nil];
#endif
    [passwordWC setAllowFileSelection:NO];
    if(treeController.selectedNodes.count > 0) {
        QStringList accounts;
        for (id item : [treeController selectedNodes]) {
            QModelIndex accIdx = [treeController toQIdx:item];
            accounts << AccountModel::instance().getAccountByModelIndex(accIdx)->id();
        }
        [passwordWC setAccounts:accounts];
    }
    [passwordWC showWindow:self];
    accountModal = passwordWC;
}

- (void) restoreAccount:(NSMenuItem*) sender
{
    auto passwordWC = [[RestoreAccountWC alloc] initWithDelegate:self];
#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_9
    [self.view.window beginSheet:passwordWC.window completionHandler:nil];
#else
    [NSApp beginSheet: passwordWC.window
       modalForWindow: self.view.window
        modalDelegate: self
       didEndSelector: nil
          contextInfo: nil];
#endif
    [passwordWC setAllowFileSelection:YES];
    [passwordWC showWindow:self];
    accountModal = passwordWC;
}

- (NSEvent*) forgedEventForButton:(NSButton*) button
{
    NSRect frame = [button frame];
    NSPoint menuOrigin = [[button superview]
                          convertPoint:NSMakePoint(frame.origin.x, frame.origin.y)
                          toView:nil];
    return [NSEvent mouseEventWithType:NSLeftMouseDown
                              location:menuOrigin
                         modifierFlags:NSLeftMouseDownMask // 0x100
                             timestamp:0
                          windowNumber:[[button window] windowNumber]
                               context:[[button window] graphicsContext]
                           eventNumber:0
                            clickCount:1
                              pressure:1];
}


#pragma mark - Account creation methods

- (IBAction)addAccountClicked:(NSButton *)sender
{
    NSMenu* menu = [[NSMenu alloc] init];
    [menu insertItemWithTitle:NSLocalizedString(@"Create RING Account", @"Contextual menu entry")
                       action:@selector(createRingAccount:)
                keyEquivalent:@""
                      atIndex:0];
    [menu insertItemWithTitle:NSLocalizedString(@"Create SIP Account", @"Contextual menu entry")
                       action:@selector(createSIPAccount:)
                keyEquivalent:@""
                      atIndex:0];

    [NSMenu popUpContextMenu:menu withEvent:[self forgedEventForButton:sender] forView:(NSButton *)sender];
}

- (void)createSIPAccount:(NSMenuItem*) sender
{
    auto acc = AccountModel::instance().add([NSLocalizedString(@"New SIP account", @"User label") UTF8String]);
    acc->setDisplayName(acc->alias());
    acc->setProtocol(Account::Protocol::SIP);
    acc->setDTMFType(DtmfType::OverSip);
    AccountModel::instance().save();
}

- (void)createRingAccount:(NSMenuItem*) sender
{
    wizard = [[RingWizardWC alloc] initWithWindowNibName:@"RingWizard"];
    [wizard showChooseWithCancelButton: YES];
    // [wizard.window makeKeyAndOrderFront:self];
#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_9
    [self.view.window beginSheet:wizard.window completionHandler:nil];
#else
    [NSApp beginSheet: wizard.window
       modalForWindow: self.view.window
        modalDelegate: self
       didEndSelector: nil
          contextInfo: nil];
#endif
    [wizard showWindow:self];
}

#pragma mark - BackupAccountDelegate methods

-(void) didCompleteExportWithPath:(NSURL*) fileUrl
{
    [[NSWorkspace sharedWorkspace] selectFile:fileUrl.path inFileViewerRootedAtPath:@""];
}

#pragma mark - RestoreAccountDelegate methods

-(void) didCompleteImport
{
    // Nothing to do here
}

@end
