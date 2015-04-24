/*
 *  Copyright (C) 2004-2015 Savoir-Faire Linux Inc.
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
 *
 *  Additional permission under GNU GPL version 3 section 7:
 *
 *  If you modify this program, or any covered work, by linking or
 *  combining it with the OpenSSL project's OpenSSL library (or a
 *  modified version of that library), containing parts covered by the
 *  terms of the OpenSSL or SSLeay licenses, Savoir-Faire Linux Inc.
 *  grants you additional permission to convey the resulting work.
 *  Corresponding Source for a non-source form of such a combination
 *  shall include the source code for the parts of OpenSSL used as well
 *  as that of the covered work.
 */

#define COLUMNID_ENABLE @"EnableColumn"
#define COLUMNID_NAME @"NameColumn"
#define COLUMNID_STATE @"StateColumn"

#import "AccountsVC.h"

// LibRingClient
#import <QSortFilterProxyModel>
#import <accountmodel.h>
#import <protocolmodel.h>
#import <QItemSelectionModel>
#import <account.h>

#import "QNSTreeController.h"
#import "AccGeneralVC.h"
#import "AccAudioVC.h"
#import "AccVideoVC.h"
#import "AccAdvancedVC.h"
#import "AccSecurityVC.h"
#import "AccRingVC.h"

// We disabled IAX protocol for now, so don't show it to the user
class ActiveProtocolModel : public QSortFilterProxyModel
{
public:
    ActiveProtocolModel(QAbstractItemModel* parent) : QSortFilterProxyModel(parent)
    {
        setSourceModel(parent);
    }
    virtual bool filterAcceptsRow(int source_row, const QModelIndex& source_parent) const
    {
        return sourceModel()->index(source_row,0,source_parent).flags() & Qt::ItemIsEnabled;
    }
};

@interface AccountsVC ()
@property (assign) IBOutlet NSPopUpButton *protocolList;

@property (assign) IBOutlet NSTabView *configPanels;
@property (retain) IBOutlet NSTabViewItem *generalTabItem;
@property (retain) IBOutlet NSTabViewItem *audioTabItem;
@property (retain) IBOutlet NSTabViewItem *videoTabItem;
@property (retain) IBOutlet NSTabViewItem *advancedTabItem;
@property (retain) IBOutlet NSTabViewItem *securityTabItem;
@property (retain) IBOutlet NSTabViewItem *ringTabItem;

@property QNSTreeController *treeController;
@property ActiveProtocolModel* proxyProtocolModel;
@property (assign) IBOutlet NSOutlineView *accountsListView;
@property (assign) IBOutlet NSTabView *accountDetailsView;

@property AccRingVC* ringVC;
@property AccGeneralVC* generalVC;
@property AccAudioVC* audioVC;
@property AccVideoVC* videoVC;
@property AccAdvancedVC* advancedVC;
@property AccSecurityVC* securityVC;

@end

@implementation AccountsVC
@synthesize protocolList;
@synthesize configPanels;
@synthesize generalTabItem;
@synthesize audioTabItem;
@synthesize videoTabItem;
@synthesize advancedTabItem;
@synthesize securityTabItem;
@synthesize ringTabItem;
@synthesize accountsListView;
@synthesize accountDetailsView;
@synthesize treeController;
@synthesize proxyProtocolModel;

- (void)awakeFromNib
{
    treeController = [[QNSTreeController alloc] initWithQModel:AccountModel::instance()];
    [treeController setAvoidsEmptySelection:NO];
    [treeController setAlwaysUsesMultipleValuesMarker:YES];
    [treeController setChildrenKeyPath:@"children"];

    [accountsListView bind:@"content" toObject:treeController withKeyPath:@"arrangedObjects" options:nil];
    [accountsListView bind:@"sortDescriptors" toObject:treeController withKeyPath:@"sortDescriptors" options:nil];
    [accountsListView bind:@"selectionIndexPaths" toObject:treeController withKeyPath:@"selectionIndexPaths" options:nil];

    QObject::connect(AccountModel::instance(),
                     &QAbstractItemModel::dataChanged,
                     [=](const QModelIndex &topLeft, const QModelIndex &bottomRight) {
                        [accountsListView reloadDataForRowIndexes:
                        [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(topLeft.row(), bottomRight.row() + 1)]
                        columnIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, accountsListView.tableColumns.count)]];

                     });

    self.proxyProtocolModel = new ActiveProtocolModel(AccountModel::instance()->protocolModel());
    QModelIndex qProtocolIdx = AccountModel::instance()->protocolModel()->selectionModel()->currentIndex();
    [self.protocolList addItemWithTitle:
                           AccountModel::instance()->protocolModel()->data(qProtocolIdx, Qt::DisplayRole).toString().toNSString()];

    self.generalVC = [[AccGeneralVC alloc] initWithNibName:@"AccGeneral" bundle:nil];
    [[self.generalVC view] setFrame:[self.generalTabItem.view frame]];
    [[self.generalVC view] setBounds:[self.generalTabItem.view bounds]];
    [self.generalTabItem setView:self.generalVC.view];

    self.audioVC = [[AccAudioVC alloc] initWithNibName:@"AccAudio" bundle:nil];
    [[self.audioVC view] setFrame:[self.audioTabItem.view frame]];
    [[self.audioVC view] setBounds:[self.audioTabItem.view bounds]];
    [self.audioTabItem setView:self.audioVC.view];

    self.videoVC = [[AccVideoVC alloc] initWithNibName:@"AccVideo" bundle:nil];
    [[self.videoVC view] setFrame:[self.videoTabItem.view frame]];
    [[self.videoVC view] setBounds:[self.videoTabItem.view bounds]];
    [self.videoTabItem setView:self.videoVC.view];

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
}

- (IBAction)moveUp:(id)sender {
    AccountModel::instance()->moveUp();
}

- (IBAction)moveDown:(id)sender {
    AccountModel::instance()->moveDown();
}

- (IBAction)removeAccount:(id)sender {

    if(treeController.selectedNodes.count > 0) {
        QModelIndex qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
        AccountModel::instance()->remove(qIdx);
        AccountModel::instance()->save();
    }
}
- (IBAction)addAccount:(id)sender {
    QModelIndex qIdx =  AccountModel::instance()->protocolModel()->selectionModel()->currentIndex();

    NSString* newAccName = [[NSString alloc] initWithFormat:@"%@ account",
                AccountModel::instance()->protocolModel()->data(qIdx, Qt::DisplayRole).toString().toNSString(), nil];

    Account* newAcc =AccountModel::instance()->add([newAccName UTF8String], qIdx);
    AccountModel::instance()->save();
}

- (IBAction)protocolSelectedChanged:(id)sender {

    int index = [sender indexOfSelectedItem];
    QModelIndex proxyIdx = proxyProtocolModel->index(index, 0);
    AccountModel::instance()->protocolModel()->selectionModel()->setCurrentIndex(
                proxyProtocolModel->mapToSource(proxyIdx), QItemSelectionModel::ClearAndSelect);

}

- (void) setupSIPPanelsForAccount:(Account*) acc
{
    NSTabViewItem* selected = [configPanels selectedTabViewItem];

    // Start by removing all tabs
    for(NSTabViewItem* item in configPanels.tabViewItems) {
        [configPanels removeTabViewItem:item];
    }

    [configPanels insertTabViewItem:generalTabItem atIndex:0];
    [configPanels insertTabViewItem:audioTabItem atIndex:1];
    [configPanels insertTabViewItem:videoTabItem atIndex:2];
    [configPanels insertTabViewItem:advancedTabItem atIndex:3];
    [configPanels insertTabViewItem:securityTabItem atIndex:4];

    [self.generalVC loadAccount:acc];
    [self.audioVC loadAccount:acc];
    [self.videoVC loadAccount:acc];
    [self.advancedVC loadAccount:acc];
    [self.securityVC loadAccount:acc];
}

- (void) setupIAXPanelsForAccount:(Account*) acc
{
    NSTabViewItem* selected = [configPanels selectedTabViewItem];

    // Start by removing all tabs
    for(NSTabViewItem* item in configPanels.tabViewItems) {
        [configPanels removeTabViewItem:item];
    }

    [configPanels insertTabViewItem:generalTabItem atIndex:0];
    [configPanels insertTabViewItem:audioTabItem atIndex:1];
    [configPanels insertTabViewItem:videoTabItem atIndex:2];

    [self.generalVC loadAccount:acc];
    [self.audioVC loadAccount:acc];
    [self.videoVC loadAccount:acc];
}

- (void) setupRINGPanelsForAccount:(Account*) acc
{
    NSTabViewItem* selected = [configPanels selectedTabViewItem];

    // Start by removing all tabs
    for(NSTabViewItem* item in configPanels.tabViewItems) {
        [configPanels removeTabViewItem:item];
    }

    [configPanels insertTabViewItem:ringTabItem atIndex:0];
    [configPanels insertTabViewItem:audioTabItem atIndex:1];
    [configPanels insertTabViewItem:videoTabItem atIndex:2];
    [configPanels insertTabViewItem:advancedTabItem atIndex:3];
    [configPanels insertTabViewItem:securityTabItem atIndex:4];

    [self.ringVC loadAccount:acc];
    [self.audioVC loadAccount:acc];
    [self.videoVC loadAccount:acc];
    [self.advancedVC loadAccount:acc];
    [self.securityVC loadAccount:acc];
}

- (IBAction)toggleAccount:(NSOutlineView*)sender {

    if([sender clickedColumn] < 0)
        return;

    NSTableColumn* col = [sender.tableColumns objectAtIndex:[sender clickedColumn]];
    if([col.identifier isEqualToString:COLUMNID_ENABLE]) {
        NSInteger row = [sender clickedRow];
        QModelIndex accIdx = AccountModel::instance()->index(row);
        Account* toToggle = AccountModel::instance()->getAccountByModelIndex(accIdx);
        NSButtonCell *cell = [col dataCellForRow:row];
        toToggle->setEnabled(cell.state == NSOnState ? NO : YES);
        toToggle << Account::EditAction::SAVE;
    }
}

#pragma mark - NSOutlineViewDelegate methods

// -------------------------------------------------------------------------------
//	shouldSelectItem:item
// -------------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item;
{
    return YES;
}

// -------------------------------------------------------------------------------
//	dataCellForTableColumn:tableColumn:item
// -------------------------------------------------------------------------------
- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    NSCell *returnCell;

    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    // Prevent user from enabling/disabling IP2IP account
    if ([[tableColumn identifier] isEqualToString:COLUMNID_ENABLE] &&
                            AccountModel::instance()->ip2ip()->index() == qIdx) {

        returnCell = [[NSCell alloc] init];
    } else {
        returnCell = [tableColumn dataCell];
    }
    return returnCell;
}

// -------------------------------------------------------------------------------
//	textShouldEndEditing:fieldEditor
// -------------------------------------------------------------------------------
- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
    if ([[fieldEditor string] length] == 0)
    {
        // don't allow empty node names
        return NO;
    }
    else
    {
        return YES;
    }
}

// -------------------------------------------------------------------------------
//	shouldEditTableColumn:tableColumn:item
//
//	Decide to allow the edit of the given outline view "item".
// -------------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    return NO;
}

// -------------------------------------------------------------------------------
//	outlineView:willDisplayCell:forTableColumn:item
// -------------------------------------------------------------------------------
- (void)outlineView:(NSOutlineView *)olv willDisplayCell:(NSCell*)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    if(!qIdx.isValid())
        return;

    if ([[tableColumn identifier] isEqualToString:COLUMNID_NAME])
    {
        cell.title = AccountModel::instance()->data(qIdx, Qt::DisplayRole).toString().toNSString();
    } else if([[tableColumn identifier] isEqualToString:COLUMNID_STATE]) {
        NSTextFieldCell* stateCell = cell;
        Account::RegistrationState state = qvariant_cast<Account::RegistrationState>(qIdx.data((int)Account::Role::RegistrationState));
        switch (state) {
            case Account::RegistrationState::READY:
                [stateCell setTextColor:[NSColor colorWithCalibratedRed:116/255.0 green:179/255.0 blue:93/255.0 alpha:1.0]];
                [stateCell setTitle:@"Ready"];
                break;
            case Account::RegistrationState::TRYING:
                [stateCell setTextColor:[NSColor redColor]];
                [stateCell setTitle:@"Trying..."];
                break;
            case Account::RegistrationState::UNREGISTERED:
                [stateCell setTextColor:[NSColor blackColor]];
                [stateCell setTitle:@"Unregistered"];
                break;
            case Account::RegistrationState::ERROR:
                [stateCell setTextColor:[NSColor redColor]];
                [stateCell setTitle:@"Error"];
                break;
            default:
                break;
        }
    } else if([[tableColumn identifier] isEqualToString:COLUMNID_ENABLE]) {
        [cell setState:qIdx.data(Qt::CheckStateRole).value<BOOL>()];
    }
}

// -------------------------------------------------------------------------------
//	outlineViewSelectionDidChange:notification
// -------------------------------------------------------------------------------
- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    // ask the tree controller for the current selection
    if([[treeController selectedNodes] count] > 0) {
        QModelIndex qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
        //Update details view
        AccountModel::instance()->selectionModel()->setCurrentIndex(qIdx, QItemSelectionModel::ClearAndSelect);
        Account* acc = AccountModel::instance()->getAccountByModelIndex(qIdx);

            switch (acc->protocol()) {
            case Account::Protocol::SIP:
                NSLog(@"SIP");
                [self setupSIPPanelsForAccount:acc];
                break;
            case Account::Protocol::IAX:
                NSLog(@"IAX");
                [self setupIAXPanelsForAccount:acc];
                break;
            case Account::Protocol::RING:
                [self setupRINGPanelsForAccount:acc];
                NSLog(@"DRING");
                break;
            default:
                break;
        }


        [self.accountDetailsView setHidden:NO];
    } else {
        [self.accountDetailsView setHidden:YES];
        AccountModel::instance()->selectionModel()->clearCurrentIndex();
    }
}

#pragma mark - NSMenuDelegate methods

- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(NSInteger)index shouldCancel:(BOOL)shouldCancel
{
    QModelIndex proxyIdx = proxyProtocolModel->index(index, 0);
    QModelIndex qIdx = AccountModel::instance()->protocolModel()->index(proxyProtocolModel->mapToSource(proxyIdx).row());
    [item setTitle:qIdx.data(Qt::DisplayRole).toString().toNSString()];

    return YES;
}

- (NSInteger)numberOfItemsInMenu:(NSMenu *)menu
{
    return proxyProtocolModel->rowCount();
}



@end
