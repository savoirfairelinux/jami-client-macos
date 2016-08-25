/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
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

#import "AccDevicesVC.h"

//Qt
#import <qitemselectionmodel.h>

//LRC
#import <accountmodel.h>
#import <ringdevicemodel.h>
#import <account.h>

#import "QNSTreeController.h"
#import "ExportPasswordWC.h"

@interface AccDevicesVC () <ExportPasswordDelegate>

@property QNSTreeController* devicesTreeController;
@property ExportPasswordWC* passwordWC;

@property (unsafe_unretained) IBOutlet NSOutlineView* deviceDetailsView;

@end

@implementation AccDevicesVC

@synthesize passwordWC;

NSInteger const TAG_NAME        =   100;
NSInteger const TAG_DEVICE_IDS  =   200;

- (void)awakeFromNib
{
    NSLog(@"INIT Devices VC");

    QObject::connect(AccountModel::instance().selectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {
                         if(!current.isValid())
                             return;
                         [self loadAccount];
                     });
}


- (void)loadAccount
{
    auto account = AccountModel::instance().selectedAccount();
    self.devicesTreeController = [[QNSTreeController alloc] initWithQModel:(QAbstractItemModel*)account->ringDeviceModel()];
    [self.devicesTreeController setAvoidsEmptySelection:NO];
    [self.devicesTreeController setChildrenKeyPath:@"children"];

    [self.deviceDetailsView bind:@"content" toObject:self.devicesTreeController withKeyPath:@"arrangedObjects" options:nil];
    [self.deviceDetailsView bind:@"sortDescriptors" toObject:self.devicesTreeController withKeyPath:@"sortDescriptors" options:nil];
    [self.deviceDetailsView bind:@"selectionIndexPaths" toObject:self.devicesTreeController withKeyPath:@"selectionIndexPaths" options:nil];
}

- (IBAction)startExportOnRing:(id)sender
{
    NSButton* btbAdd = (NSButton *) sender;

    self.account = AccountModel::instance().selectedAccount();
    [self showPasswordPrompt];
}
#pragma mark - Export methods

- (void)showPasswordPrompt
{
    auto account = AccountModel::instance().selectedAccount();
    passwordWC = [[ExportPasswordWC alloc] initWithDelegate:self actionCode:1];
    [passwordWC setAccount: account];
#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_9
    [self.view.window beginSheet:passwordWC.window completionHandler:nil];
#else
    [NSApp beginSheet: passwordWC.window
       modalForWindow: self.view.window
        modalDelegate: self
       didEndSelector: nil
          contextInfo: nil];
#endif
}


#pragma mark - NSOutlineViewDelegate methods

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
    return YES;
}

- (NSTableRowView *)outlineView:(NSOutlineView *)outlineView rowViewForItem:(id)item
{
    return [outlineView makeViewWithIdentifier:@"HoverRowView" owner:nil];
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    NSTableView* result = [outlineView makeViewWithIdentifier:@"DeviceView" owner:self];

    QModelIndex qIdx = [self.devicesTreeController toQIdx:((NSTreeNode*)item)];
    if(!qIdx.isValid())
        return result;

    NSTextField* nameLabel = [result viewWithTag:TAG_NAME];
    NSTextField* deviceIDLabel = [result viewWithTag:TAG_DEVICE_IDS];

    auto account = AccountModel::instance().selectedAccount();

    NSString* string = account->ringDeviceModel()->data(qIdx,Qt::DisplayRole).toString().toNSString();

    [nameLabel setStringValue:account->alias().toNSString()];
    [deviceIDLabel setStringValue:string];

    return result;
}

@end
