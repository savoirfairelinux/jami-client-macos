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

@property Account* account;

@end

@implementation AccDevicesVC

@synthesize passwordWC;
@synthesize account;

NSInteger const TAG_NAME        =   100;
NSInteger const TAG_STATUS      =   300;
NSInteger const TAG_TYPE        =   400;

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
}

- (IBAction)startExportOnRing:(id)sender
{
    NSButton *btbAdd = (NSButton *) sender;

    self.account = AccountModel::instance().selectedAccount();
    [self showPasswordPrompt];

}
#pragma mark - Export methods

- (void)showPasswordPrompt
{
    passwordWC = [[ExportPasswordWC alloc] initWithDelegate:self actionCode:1];
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
- (void)passwordPromptSubmitedwithPassword:(NSString *)password
{
    account->exportOnRing(QString::fromNSString(password));
    QObject::connect(account,
                     &Account::exportOnRingEnded,
                     [=](Account::ExportOnRingStatus status,const QString &pin) {
                         NSLog(@"Export ended!");

                         switch (status) {
                             case Account::ExportOnRingStatus::SUCCESS:{
                                 NSString *nsPin = pin.toNSString();
                                 NSLog(@"Export ended with Success, pin is %@",nsPin);
                                 [self didCompleteWithPin:nsPin Password:password];
                             }
                                 break;
                             case Account::ExportOnRingStatus::WRONG_PASSWORD:{
                                 NSLog(@"Export ended with Wrong Password");
                                 [passwordWC showError:NSLocalizedString(@"Export ended with Wrong Password", @"Error shown to the user" )];
                             }
                                 break;
                             case Account::ExportOnRingStatus::NETWORK_ERROR:{
                                 NSLog(@"Export ended with NetworkError!");
                                 [passwordWC showError:NSLocalizedString(@"A network error occured during the export", @"Error shown to the user" )];
                             }
                                 break;

                             default:{
                                 NSLog(@"Export ended with Unknown status!");
                                 [passwordWC showError:NSLocalizedString(@"An error occured during the export", @"Error shown to the user" )];
                             }
                                 break;
                         }
                     });
}



- (void)passwordPromptDidCancel
{
    NSLog(@"user cancel passord prompt");
}


-(void) didCompleteWithPin:(NSString*) pin Password:(NSString*) password
{
    //TODO: Move String formatting to a dedicated Utility Classes
    NSMutableAttributedString* hereArreThePin = [[NSMutableAttributedString alloc] initWithString:@"Heare are your PIn code generated:"];
    NSMutableAttributedString* thePin = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"\n\n%@", pin]];
    [thePin beginEditing];
    NSRange range = NSMakeRange(0, [thePin length]);
    [thePin addAttribute:NSFontAttributeName value:[NSFont fontWithName:@"Helvetica-Bold" size:12.0] range:range];
    [hereArreThePin appendAttributedString:thePin];
    [passwordWC showMessage:hereArreThePin];
    [self passwordPromptSubmitedwithPassword:password];
}

-(void) didStartWithPassword:(NSString*) password
{
    [passwordWC showLoading];
    [self passwordPromptSubmitedwithPassword:password];
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
    NSTextField* stateLabel = [result viewWithTag:TAG_STATUS];

    auto account = AccountModel::instance().selectedAccount();

    account->ringDeviceModel()->data(qIdx);
    [nameLabel setStringValue:account->alias().toNSString()];
    //[stateLabel setStringValue:humanState.toNSString()];

    return result;
}

@end
