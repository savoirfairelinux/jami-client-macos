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

#define CA_CERT_PANEL   1
#define CERT_PANEL      2
#define PRVKEY_PANEL    3

#define COLUMNID_NAME @"CipherNameColumn"

@interface AccSecurityVC ()

@property Account* privateAccount;
@property NSTreeController *treeController;
@property (unsafe_unretained) IBOutlet NSOutlineView *cipherListView;

@property (strong) IBOutlet NSPanel *certificatePanel;
@property (unsafe_unretained) IBOutlet NSPathControl *caListPathControl;
@property (unsafe_unretained) IBOutlet NSPathControl *certificatePathControl;
@property (unsafe_unretained) IBOutlet NSPathControl *pvkPathControl;
@property (unsafe_unretained) IBOutlet NSPopUpButton *tlsMethodList;

@end

@implementation AccSecurityVC
@synthesize privateAccount;
@synthesize treeController;
@synthesize cipherListView;

- (void)awakeFromNib
{
    NSLog(@"INIT Security VC");
}

- (void)loadAccount:(Account *)account
{
    privateAccount = account;

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
}

- (IBAction)chooseTlsMethod:(id)sender {
    int index = [sender indexOfSelectedItem];
    QModelIndex qIdx = privateAccount->tlsMethodModel()->index(index, 0);
    privateAccount->tlsMethodModel()->selectionModel()->setCurrentIndex(qIdx, QItemSelectionModel::ClearAndSelect);
}

#pragma mark - NSPathControl delegate methods
- (IBAction)caListPathControlSingleClick:(id)sender {
    NSURL* fileURL = [[sender clickedPathComponentCell] URL];
    [self.caListPathControl setURL:fileURL];
    privateAccount->setTlsCaListCertificate(QUrl::fromNSURL(fileURL).toString());
}

- (IBAction)certificatePathControlSingleClick:(id)sender {
    // Select that chosen component of the path.
    NSURL* fileURL = [[sender clickedPathComponentCell] URL];
    [self.certificatePathControl setURL:fileURL];
    privateAccount->setTlsCaListCertificate(QUrl::fromNSURL(fileURL).toString());
}

- (IBAction)pvkFilePathControlSingleClick:(id)sender {
    NSURL* fileURL = [[sender clickedPathComponentCell] URL];
    [self.pvkPathControl setURL:fileURL];
    privateAccount->setTlsPrivateKeyCertificate(QUrl::fromNSURL(fileURL).toString());
    

   // qDebug() << "TEST" << privateAccount->tlsPrivateKeyCertificate()->hasPrivateKey();
}

- (IBAction)showCA:(id)sender
{
    [NSApp beginSheet:self.certificatePanel modalForWindow:self.view.window modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

- (IBAction)showEndpointCertificate:(id)sender
{
    [NSApp beginSheet:self.certificatePanel modalForWindow:self.view.window modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

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

- (IBAction)closePanel:(id)sender
{
    [NSApp endSheet:self.certificatePanel];
    [self.certificatePanel orderOut:self];
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
