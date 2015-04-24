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
#import "AccSecurityVC.h"

#import <QUrl>
#import <certificate.h>
#import <tlsmethodmodel.h>
#import <qitemselectionmodel.h>
#import <ciphermodel.h>

#import "QNSTreeController.h"
#import "CertificateWC.h"

// Tags for views
#define PVK_PASSWORD_TAG 0
#define OUTGOING_TLS_SRV_NAME 1
#define TLS_NEGOTIATION_TAG 2

#define COLUMNID_NAME @"CipherNameColumn"

@interface AccSecurityVC ()

@property Account* privateAccount;
@property NSTreeController *treeController;
@property (unsafe_unretained) IBOutlet NSOutlineView *cipherListView;
@property (unsafe_unretained) IBOutlet NSButton *useTLS;
@property (unsafe_unretained) IBOutlet NSView *tlsContainer;
@property (unsafe_unretained) IBOutlet NSSecureTextField *pvkPasswordField;
@property (unsafe_unretained) IBOutlet NSTextField *outgoingTlsServerName;
@property (unsafe_unretained) IBOutlet NSTextField *tlsNegotiationTimeout;
@property (unsafe_unretained) IBOutlet NSStepper *tlsNegotiationTimeoutStepper;

@property CertificateWC* certificateWC;

@property (unsafe_unretained) IBOutlet NSPathControl *caListPathControl;
@property (unsafe_unretained) IBOutlet NSPathControl *certificatePathControl;
@property (unsafe_unretained) IBOutlet NSPathControl *pvkPathControl;
@property (unsafe_unretained) IBOutlet NSPopUpButton *tlsMethodList;
@property (unsafe_unretained) IBOutlet NSButton *srtpRTPFallback;
@property (unsafe_unretained) IBOutlet NSButton *useSRTP;

@end

@implementation AccSecurityVC
@synthesize privateAccount;
@synthesize treeController;
@synthesize cipherListView;
@synthesize certificateWC;
@synthesize tlsContainer;
@synthesize useTLS;
@synthesize useSRTP;
@synthesize srtpRTPFallback;
@synthesize pvkPasswordField;
@synthesize tlsNegotiationTimeout;
@synthesize tlsNegotiationTimeoutStepper;
@synthesize outgoingTlsServerName;
@synthesize caListPathControl;
@synthesize certificatePathControl;
@synthesize pvkPathControl;

- (void)awakeFromNib
{
    NSLog(@"INIT Security VC");
    [pvkPasswordField setTag:PVK_PASSWORD_TAG];
    [outgoingTlsServerName setTag:OUTGOING_TLS_SRV_NAME];
    [tlsNegotiationTimeoutStepper setTag:TLS_NEGOTIATION_TAG];
    [tlsNegotiationTimeout setTag:TLS_NEGOTIATION_TAG];

}

- (void)loadAccount:(Account *)account
{
    privateAccount = account;

    [self updateControlsWithTag:PVK_PASSWORD_TAG];
    [self updateControlsWithTag:OUTGOING_TLS_SRV_NAME];
    [self updateControlsWithTag:TLS_NEGOTIATION_TAG];

    QModelIndex qTlsMethodIdx = privateAccount->tlsMethodModel()->selectionModel()->currentIndex();
    [self.tlsMethodList removeAllItems];
    [self.tlsMethodList addItemWithTitle:qTlsMethodIdx.data(Qt::DisplayRole).toString().toNSString()];

    treeController = [[QNSTreeController alloc] initWithQModel:privateAccount->cipherModel()];
    [treeController setAvoidsEmptySelection:NO];
    [treeController setAlwaysUsesMultipleValuesMarker:YES];
    [treeController setChildrenKeyPath:@"children"];

    [cipherListView bind:@"content" toObject:treeController withKeyPath:@"arrangedObjects" options:nil];
    [cipherListView bind:@"sortDescriptors" toObject:treeController withKeyPath:@"sortDescriptors" options:nil];
    [cipherListView bind:@"selectionIndexPaths" toObject:treeController withKeyPath:@"selectionIndexPaths" options:nil];

    [useTLS setState:privateAccount->isTlsEnabled()];
    [tlsContainer setHidden:!privateAccount->isTlsEnabled()];

    [useSRTP setState:privateAccount->isSrtpEnabled()];
    [srtpRTPFallback setState:privateAccount->isSrtpRtpFallback()];
    [srtpRTPFallback setEnabled:useSRTP.state];

    NSArray * pathComponentArray = [self pathComponentArray];

    if(privateAccount->tlsCaListCertificate() != nil) {
            NSLog(@"CA ==> %@", privateAccount->tlsCaListCertificate()->path().toNSURL());
        [caListPathControl setURL:privateAccount->tlsCaListCertificate()->path().toNSURL()];
    } else {
        [caListPathControl setURL:nil];
    }

    if(privateAccount->tlsCertificate() != nil) {
        NSLog(@" CERT ==> %@", privateAccount->tlsCertificate()->path().toNSURL());
        [certificatePathControl setURL:privateAccount->tlsCertificate()->path().toNSURL()];
    } else {
        [certificatePathControl setURL:nil];
    }

    if(privateAccount->tlsPrivateKeyCertificate() != nil) {
        NSLog(@" PVK ==> %@", privateAccount->tlsPrivateKeyCertificate()->path().toNSURL());
        [pvkPathControl setURL:privateAccount->tlsPrivateKeyCertificate()->path().toNSURL()];
    } else {
        [pvkPathControl setURL:nil];
    }
}

/*
 Assemble a set of custom cells to display into an array to pass to the path control.
 */
- (NSArray *)pathComponentArray
{
    NSMutableArray *pathComponentArray = [[NSMutableArray alloc] init];

    NSFileManager *fileManager = [[NSFileManager alloc] init];

    NSURL* desktopURL = [fileManager URLForDirectory:NSDesktopDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
    NSURL* documentsURL = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
    NSURL* userURL = [fileManager URLForDirectory:NSUserDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];

    NSPathComponentCell *componentCell;

    // Use utility method to obtain a NSPathComponentCell based on icon, title and URL.
    componentCell = [self componentCellForType:kGenericFolderIcon withTitle:@"Desktop" URL:desktopURL];
    [pathComponentArray addObject:componentCell];

    componentCell = [self componentCellForType:kGenericFolderIcon withTitle:@"Documents" URL:documentsURL];
    [pathComponentArray addObject:componentCell];

    componentCell = [self componentCellForType:kUserFolderIcon withTitle:NSUserName() URL:userURL];
    [pathComponentArray addObject:componentCell];

    return pathComponentArray;
}

/*
 This method is used by pathComponentArray to create a NSPathComponent cell based on icon, title and URL information.
 Each path component needs an icon, URL and title.
 */
- (NSPathComponentCell *)componentCellForType:(OSType)withIconType withTitle:(NSString *)title URL:(NSURL *)url
{
    NSPathComponentCell *componentCell = [[NSPathComponentCell alloc] init];

    NSImage *iconImage = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(withIconType)];
    [componentCell setImage:iconImage];
    [componentCell setURL:url];
    [componentCell setTitle:title];

    return componentCell;
}

- (IBAction)chooseTlsMethod:(id)sender {
    int index = [sender indexOfSelectedItem];
    QModelIndex qIdx = privateAccount->tlsMethodModel()->index(index, 0);
    privateAccount->tlsMethodModel()->selectionModel()->setCurrentIndex(qIdx, QItemSelectionModel::ClearAndSelect);
}

- (IBAction)toggleUseTLS:(id)sender {
    privateAccount->setTlsEnabled([sender state]);
    [tlsContainer setHidden:![sender state]];
}

- (IBAction)toggleUseSRTP:(id)sender {
    privateAccount->setSrtpEnabled([sender state]);
    [srtpRTPFallback setEnabled:[sender state]];
}
- (IBAction)toggleRTPFallback:(id)sender {
    privateAccount->setSrtpRtpFallback([sender state]);
}

- (void) updateControlsWithTag:(NSInteger) tag
{
    switch (tag) {
        case PVK_PASSWORD_TAG:
            [pvkPasswordField setStringValue:privateAccount->tlsPassword().toNSString()];
            break;
        case OUTGOING_TLS_SRV_NAME:
            [outgoingTlsServerName setStringValue:privateAccount->tlsServerName().toNSString()];
            break;
        case TLS_NEGOTIATION_TAG:
            [tlsNegotiationTimeout setIntegerValue:privateAccount->tlsNegotiationTimeoutSec()];
            [tlsNegotiationTimeoutStepper setIntegerValue:privateAccount->tlsNegotiationTimeoutSec()];
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
        case PVK_PASSWORD_TAG:
            privateAccount->setTlsPassword([[sender stringValue] UTF8String]);
            break;
        case OUTGOING_TLS_SRV_NAME:
            privateAccount->setTlsServerName([[sender stringValue] UTF8String]);
            break;
        case TLS_NEGOTIATION_TAG:
            privateAccount->setTlsNegotiationTimeoutSec([sender integerValue]);
            break;
        default:
            break;
    }
    [self updateControlsWithTag:[sender tag]];
}

#pragma mark - NSPathControl delegate methods
- (IBAction)caListPathControlSingleClick:(id)sender {
    NSURL* fileURL = [[sender clickedPathComponentCell] URL];
    NSLog(@"==> %@", fileURL);
    [self.caListPathControl setURL:fileURL];
    privateAccount->setTlsCaListCertificate(QUrl::fromNSURL(fileURL).toString());
}

- (IBAction)certificatePathControlSingleClick:(id)sender {
    // Select that chosen component of the path.
    NSURL* fileURL = [[sender clickedPathComponentCell] URL];
        NSLog(@"==> %@", fileURL);
    [self.certificatePathControl setURL:fileURL];
    privateAccount->setTlsCertificate(QUrl::fromNSURL(fileURL).toString());
}

- (IBAction)pvkFilePathControlSingleClick:(id)sender {
    NSURL* fileURL = [[sender clickedPathComponentCell] URL];
        NSLog(@"==> %@", fileURL);
    [self.pvkPathControl setURL:fileURL];
    privateAccount->setTlsPrivateKeyCertificate(QUrl::fromNSURL(fileURL).toString());
    

   // qDebug() << "TEST" << privateAccount->tlsPrivateKeyCertificate()->hasPrivateKey();
}

- (IBAction)showCA:(id)sender
{
    certificateWC = [[CertificateWC alloc] initWithWindowNibName:@"CertificateWindow"];
    [certificateWC setCertificate:privateAccount->tlsCaListCertificate()];
    [self.view.window beginSheet:certificateWC.window completionHandler:nil];
}

- (IBAction)showEndpointCertificate:(id)sender
{
    certificateWC = [[CertificateWC alloc] initWithWindowNibName:@"CertificateWindow"];
    [certificateWC setCertificate:privateAccount->tlsCertificate()];
    [self.view.window beginSheet:certificateWC.window completionHandler:nil];}

/*
 Delegate method of NSPathControl to determine how the NSOpenPanel will look/behave.
 */
- (void)pathControl:(NSPathControl *)pathControl willDisplayOpenPanel:(NSOpenPanel *)openPanel
{
    NSLog(@"willDisplayOpenPanel");
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    [openPanel setResolvesAliases:YES];

    if(pathControl == self.caListPathControl) {
        [openPanel setTitle:NSLocalizedString(@"Choose a CA list", @"Open panel title")];
    } else if (pathControl == self.certificatePathControl) {
        [openPanel setTitle:NSLocalizedString(@"Choose a certificate", @"Open panel title")];
    } else {
        [openPanel setTitle:NSLocalizedString(@"Choose a private key file", @"Open panel title")];
    }


    [openPanel setPrompt:NSLocalizedString(@"Choose", @"Open panel prompt for 'Choose a file'")];
    [openPanel setDelegate:self];
}

- (void)pathControl:(NSPathControl *)pathControl willPopUpMenu:(NSMenu *)menu
{

}

#pragma mark - NSOpenSavePanelDelegate delegate methods

- (void)panel:(id)sender willExpand:(BOOL)expanding
{
    //NSLog(@"willExpand");
}

- (NSString *)panel:(id)sender userEnteredFilename:(NSString *)filename confirmed:(BOOL)okFlag
{
    //NSLog(@"userEnteredFilename");
}

- (void)panelSelectionDidChange:(id)sender
{
    //NSLog(@"panelSelectionDidChange");
}

- (BOOL)panel:(id)sender validateURL:(NSURL *)url error:(NSError **)outError
{
    NSLog(@"validateURL");
    return YES;
}

#pragma mark - NSMenuDelegate methods

- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(NSInteger)index shouldCancel:(BOOL)shouldCancel
{
    QModelIndex qIdx;

    if([menu.title isEqualToString:@"tlsmethodlist"])
    {
        qIdx = privateAccount->tlsMethodModel()->index(index);
        [item setTitle:qIdx.data(Qt::DisplayRole).toString().toNSString()];
    }
    return YES;
}

- (NSInteger)numberOfItemsInMenu:(NSMenu *)menu
{
    if([menu.title isEqualToString:@"tlsmethodlist"])
        return privateAccount->tlsMethodModel()->rowCount();
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
    NSCell *returnCell = [tableColumn dataCell];
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
        cell.title = qIdx.data(Qt::DisplayRole).toString().toNSString();
    }
}

// -------------------------------------------------------------------------------
//	outlineViewSelectionDidChange:notification
// -------------------------------------------------------------------------------
- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    // ask the tree controller for the current selection
    if([[treeController selectedNodes] count] > 0) {

    }
}

@end
