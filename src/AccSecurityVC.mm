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
#import "AccSecurityVC.h"

#import <QUrl>
#import <certificate.h>
#import <tlsmethodmodel.h>
#import <qitemselectionmodel.h>
#import <ciphermodel.h>
#import <accountmodel.h>

#import "QNSTreeController.h"
#import "CertificateWC.h"

#define COLUMNID_NAME   @"CipherNameColumn"
#define COLUMNID_STATE  @"CipherStateColumn"

@interface AccSecurityVC () {
    __unsafe_unretained IBOutlet NSOutlineView *cipherListView;
    __unsafe_unretained IBOutlet NSButton *useTLS;
    __unsafe_unretained IBOutlet NSView *tlsContainer;
    __unsafe_unretained IBOutlet NSLayoutConstraint* tlsContainerHeight;

    __unsafe_unretained IBOutlet NSView *pvkContainer;
    __unsafe_unretained IBOutlet NSImageView *pvkPasswordValidation;

    __unsafe_unretained IBOutlet NSButton *showUserCertButton;
    __unsafe_unretained IBOutlet NSButton *showCAButton;
    __unsafe_unretained IBOutlet NSSecureTextField *pvkPasswordField;
    __unsafe_unretained IBOutlet NSTextField *outgoingTlsServerName;
    __unsafe_unretained IBOutlet NSTextField *tlsNegotiationTimeout;
    __unsafe_unretained IBOutlet NSStepper *tlsNegotiationTimeoutStepper;
    __unsafe_unretained IBOutlet NSPathControl *caListPathControl;
    __unsafe_unretained IBOutlet NSPathControl *certificatePathControl;
    __unsafe_unretained IBOutlet NSPathControl *pvkPathControl;
    __unsafe_unretained IBOutlet NSPopUpButton *tlsMethodList;
    __unsafe_unretained IBOutlet NSButton *srtpRTPFallback;
    __unsafe_unretained IBOutlet NSButton *useSRTP;

    __unsafe_unretained IBOutlet NSButton *verifyCertAsClientButton;
    __unsafe_unretained IBOutlet NSButton *verifyCertAsServerButton;
    __unsafe_unretained IBOutlet NSButton *requireCertButton;
}

@property QNSTreeController *treeController;
@property CertificateWC* certificateWC;

@end

@implementation AccSecurityVC
@synthesize treeController;
@synthesize certificateWC;

// Tags for views
NS_ENUM(NSInteger, TagViews) {
    PVK_PASSWORD            = 0,
    OUTGOING_TLS_SRV_NAME   = 1,
    TLS_NEGOTIATION         = 2
};

- (void)awakeFromNib
{
    NSLog(@"INIT Security VC");
    [pvkPasswordField setTag:TagViews::PVK_PASSWORD];
    [outgoingTlsServerName setTag:TagViews::OUTGOING_TLS_SRV_NAME];
    [tlsNegotiationTimeoutStepper setTag:TagViews::TLS_NEGOTIATION];
    [tlsNegotiationTimeout setTag:TagViews::TLS_NEGOTIATION];

    QObject::connect(AccountModel::instance().selectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {
                         if(!current.isValid())
                             return;
                         [self loadAccount];
                     });
}

- (Account*) currentAccount
{
    auto accIdx = AccountModel::instance().selectionModel()->currentIndex();
    return AccountModel::instance().getAccountByModelIndex(accIdx);
}

- (void)loadAccount
{
    auto account = [self currentAccount];

    [self updateControlsWithTag:TagViews::PVK_PASSWORD];
    [self updateControlsWithTag:OUTGOING_TLS_SRV_NAME];
    [self updateControlsWithTag:TagViews::TLS_NEGOTIATION];

    QModelIndex qTlsMethodIdx = account->tlsMethodModel()->selectionModel()->currentIndex();
    [tlsMethodList removeAllItems];
    [tlsMethodList addItemWithTitle:qTlsMethodIdx.data(Qt::DisplayRole).toString().toNSString()];

    treeController = [[QNSTreeController alloc] initWithQModel:account->cipherModel()];
    [treeController setAvoidsEmptySelection:NO];
    [treeController setAlwaysUsesMultipleValuesMarker:YES];
    [treeController setChildrenKeyPath:@"children"];

    [cipherListView bind:@"content" toObject:treeController withKeyPath:@"arrangedObjects" options:nil];
    [cipherListView bind:@"sortDescriptors" toObject:treeController withKeyPath:@"sortDescriptors" options:nil];
    [cipherListView bind:@"selectionIndexPaths" toObject:treeController withKeyPath:@"selectionIndexPaths" options:nil];

    [useTLS setState:account->isTlsEnabled()];
    [tlsContainer setHidden:!account->isTlsEnabled()];
    tlsContainerHeight.constant = (account->isTlsEnabled()) ? 196.0f : 0.0f;

    [useSRTP setState:account->isSrtpEnabled()];
    [srtpRTPFallback setState:account->isSrtpRtpFallback()];
    [srtpRTPFallback setEnabled:useSRTP.state];

    if(account->tlsCaListCertificate() != nil) {
        [caListPathControl setURL:[NSURL fileURLWithPath:account->tlsCaListCertificate()->path().toNSString()]];
    } else {
        [caListPathControl setURL:nil];
    }

    auto tlsCert = account->tlsCertificate();

    if(tlsCert != nil) {
        [certificatePathControl setURL:[NSURL fileURLWithPath:tlsCert->path().toNSString()]];
        if(tlsCert->requirePrivateKey()) {
            [pvkContainer setHidden:NO];
            if(!account->tlsPrivateKey().isEmpty()) {
                [pvkPathControl setURL:[NSURL fileURLWithPath:account->tlsPrivateKey().toNSString()]];
                if (tlsCert->requirePrivateKeyPassword()) {
                    [pvkPasswordField setHidden:NO];
                } else
                    [pvkPasswordField setHidden:YES];
            } else {
                [pvkPathControl setURL:nil];
            }
        } else {
            [pvkContainer setHidden:YES];
        }
    } else {
        [certificatePathControl setURL:nil];
    }

    if (account->tlsCaListCertificate())
        [showCAButton setHidden:!(account->tlsCaListCertificate()->isValid() == Certificate::CheckValues::PASSED)];
    else
        [showCAButton setHidden:YES];

    [verifyCertAsServerButton setState:account->isTlsVerifyServer()];
    [verifyCertAsClientButton setState:account->isTlsVerifyClient()];
    [requireCertButton setState:account->isTlsRequireClientCertificate()];
}

- (IBAction)chooseTlsMethod:(id)sender {
    int index = [sender indexOfSelectedItem];
    QModelIndex qIdx = [self currentAccount]->tlsMethodModel()->index(index, 0);
    [self currentAccount]->tlsMethodModel()->selectionModel()->setCurrentIndex(qIdx, QItemSelectionModel::ClearAndSelect);
}

- (IBAction)toggleUseTLS:(id)sender {
    [self currentAccount]->setTlsEnabled([sender state]);
    [tlsContainer setHidden:![sender state]];
    tlsContainerHeight.constant = ([sender state]) ? 196.0f : 0.0f;
}

- (IBAction)toggleUseSRTP:(id)sender {
    [self currentAccount]->setSrtpEnabled([sender state]);
    [srtpRTPFallback setEnabled:[sender state]];
}
- (IBAction)toggleRTPFallback:(id)sender {
    [self currentAccount]->setSrtpRtpFallback([sender state]);
}

- (IBAction)toggleVerifyCertAsClient:(id)sender {
    [self currentAccount]->setTlsVerifyClient([sender state]);
}

- (IBAction)toggleVerifyCertServer:(id)sender {
    [self currentAccount]->setTlsVerifyServer([sender state]);
}

- (IBAction)toggleRequireCert:(id)sender {
    [self currentAccount]->setTlsRequireClientCertificate([sender state]);
}

- (IBAction)toggleCipher:(id)sender {
    NSInteger row = [sender clickedRow];
    NSTableColumn *col = [sender tableColumnWithIdentifier:COLUMNID_STATE];
    NSButtonCell *cell = [col dataCellForRow:row];
    [self currentAccount]->cipherModel()->setData([self currentAccount]->cipherModel()->index(row, 0, QModelIndex()),
                                           cell.state == NSOnState ? Qt::Unchecked : Qt::Checked, Qt::CheckStateRole);
}

- (void) updateControlsWithTag:(NSInteger) tag
{
    switch (tag) {
        case TagViews::PVK_PASSWORD: {
                [pvkPasswordField setStringValue:[self currentAccount]->tlsPassword().toNSString()];
                BOOL passMatch = [self currentAccount]->tlsCertificate() &&
            [self currentAccount]->tlsCertificate()->privateKeyMatch() == Certificate::CheckValues::PASSED;
                [pvkPasswordValidation setImage:[NSImage imageNamed:passMatch?@"ic_action_accept":@"ic_action_cancel"]];
            }
            break;
        case TagViews::OUTGOING_TLS_SRV_NAME:
            [outgoingTlsServerName setStringValue:[self currentAccount]->tlsServerName().toNSString()];
            break;
        case TagViews::TLS_NEGOTIATION:
            [tlsNegotiationTimeout setIntegerValue:[self currentAccount]->tlsNegotiationTimeoutSec()];
            [tlsNegotiationTimeoutStepper setIntegerValue:[self currentAccount]->tlsNegotiationTimeoutSec()];
            break;
        default:
            break;
    }
}

#pragma mark - NSTextFieldDelegate methods

-(void)controlTextDidChange:(NSNotification *)notif
{
    NSTextField *textField = [notif object];
    NSRange test = [[textField currentEditor] selectedRange];

    [self valueDidChange:textField];
    //FIXME: saving account lose focus because in NSTreeController we remove and reinsert row so View selction change
    [textField.window makeFirstResponder:textField];
    [[textField currentEditor] setSelectedRange:test];
}

- (IBAction) valueDidChange: (id) sender
{
    switch ([sender tag]) {
        case TagViews::PVK_PASSWORD:
            [self currentAccount]->setTlsPassword([[sender stringValue] UTF8String]);
            break;
        case TagViews::OUTGOING_TLS_SRV_NAME:
            [self currentAccount]->setTlsServerName([[sender stringValue] UTF8String]);
            break;
        case TagViews::TLS_NEGOTIATION:
            [self currentAccount]->setTlsNegotiationTimeoutSec([sender integerValue]);
            break;
        default:
            break;
    }
    [self updateControlsWithTag:[sender tag]];
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
    [self currentAccount]->setTlsCaListCertificate([[fileURL path] UTF8String]);

    if ([self currentAccount]->tlsCaListCertificate()->isValid() == Certificate::CheckValues::PASSED) {
        [showCAButton setHidden:NO];
    } else
        [showCAButton setHidden:YES];
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
    [self currentAccount]->setTlsCertificate([[fileURL path] UTF8String]);

    auto cert = [self currentAccount]->tlsCertificate();

    if (cert) {
        [showUserCertButton setHidden:!(cert->isValid() == Certificate::CheckValues::PASSED)];
        [pvkContainer setHidden:!cert->requirePrivateKey()];
    } else {
        [showUserCertButton setHidden:YES];
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
    [self currentAccount]->setTlsPrivateKey([[fileURL path] UTF8String]);
    if([self currentAccount]->tlsCertificate()->requirePrivateKeyPassword()) {
        [pvkPasswordField setHidden:NO];
    } else {
        [pvkPasswordField setHidden:YES];
    }
}

- (IBAction)showCA:(id)sender
{
    certificateWC = [[CertificateWC alloc] initWithWindowNibName:@"CertificateWindow"];
    [certificateWC setCertificate:[self currentAccount]->tlsCaListCertificate()];
#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_9
    [self.view.window beginSheet:certificateWC.window completionHandler:nil];
#else
    [NSApp beginSheet: certificateWC.window
       modalForWindow: self.view.window
        modalDelegate: self
       didEndSelector: nil
          contextInfo: nil];
#endif
}

- (IBAction)showEndpointCertificate:(id)sender
{
    certificateWC = [[CertificateWC alloc] initWithWindowNibName:@"CertificateWindow"];
    [certificateWC setCertificate:[self currentAccount]->tlsCertificate()];
#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_9
     [self.view.window beginSheet:certificateWC.window completionHandler:nil];
#else
     [NSApp beginSheet: certificateWC.window
        modalForWindow: self.view.window
         modalDelegate: self
        didEndSelector: nil
           contextInfo: nil];
#endif
}

#pragma mark - NSPathControlDelegate methods

- (void)pathControl:(NSPathControl *)pathControl willDisplayOpenPanel:(NSOpenPanel *)openPanel
{
    NSLog(@"willDisplayOpenPanel");
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

    [openPanel setPrompt:NSLocalizedString(@"Choose CA", @"Open panel prompt for 'Choose a file'")];
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

#pragma mark - NSMenuDelegate methods

- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(NSInteger)index shouldCancel:(BOOL)shouldCancel
{
    auto qIdx = [self currentAccount]->tlsMethodModel()->index(index);
    [item setTitle:qIdx.data(Qt::DisplayRole).toString().toNSString()];
    return YES;
}

- (NSInteger)numberOfItemsInMenu:(NSMenu *)menu
{
    return [self currentAccount]->tlsMethodModel()->rowCount();
}

#pragma mark - NSOutlineViewDelegate methods

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item;
{
    return YES;
}

- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    NSCell *returnCell = [tableColumn dataCell];
    return returnCell;
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
    if ([[fieldEditor string] length] == 0) {
        // don't allow empty node names
        return NO;
    } else {
        return YES;
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    return NO;
}

- (void)outlineView:(NSOutlineView *)olv willDisplayCell:(NSCell*)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    if(!qIdx.isValid())
        return;

    if ([[tableColumn identifier] isEqualToString:COLUMNID_NAME]) {
        cell.title = qIdx.data(Qt::DisplayRole).toString().toNSString();
    }
}

@end
