/************************************************************************************
 *   Copyright (C) 2014-2015 by Savoir-Faire Linux                                  *
 *   Author : Alexandre Lision <alexandre.lision@savoirfairelinux.com>              *
 *                                                                                  *
 *   This library is free software; you can redistribute it and/or                  *
 *   modify it under the terms of the GNU Lesser General Public                     *
 *   License as published by the Free Software Foundation; either                   *
 *   version 2.1 of the License, or (at your option) any later version.             *
 *                                                                                  *
 *   This library is distributed in the hope that it will be useful,                *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of                 *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU              *
 *   Lesser General Public License for more details.                                *
 *                                                                                  *
 *   You should have received a copy of the GNU Lesser General Public               *
 *   License along with this library; if not, write to the Free Software            *
 *   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA *
 ***********************************************************************************/

#import "AccSecurityVC.h"

#import <qitemselectionmodel.h>

#import <ciphermodel.h>
#import <tlsmethodmodel.h>
#import <account.h>
#import <certificatemodel.h>

@interface AccSecurityVC ()

@property Account* privateAccount;
@property (assign) IBOutlet NSPopUpButton *protocolList;
@property (assign) IBOutlet NSPopUpButton *cipherList;

@end

@implementation AccSecurityVC
@synthesize privateAccount;
@synthesize protocolList;
@synthesize cipherList;

- (void)awakeFromNib
{
    NSLog(@"INIT Security VC");
}

- (void)loadAccount:(Account *)account
{
    privateAccount = account;

    QModelIndex protocolIdx = privateAccount->tlsMethodModel()->selectionModel()->currentIndex();
    [protocolList addItemWithTitle:privateAccount->tlsMethodModel()->data(protocolIdx, Qt::DisplayRole).toString().toNSString()];

}

#pragma mark - NSPathControl delegate methods

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
    [openPanel setTitle:NSLocalizedString(@"Choose a file", @"Open panel title")];
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

- (void)panel:(id)sender didChangeToDirectoryURL:(NSURL *)url
{
    //NSLog(@"didChangeToDirectoryURL");
}

#pragma mark - NSMenuDelegate methods

- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(NSInteger)index shouldCancel:(BOOL)shouldCancel
{
    if([menu.title isEqualToString:@"tlsmethods"]) {
        QModelIndex qIdx = privateAccount->tlsMethodModel()->index(index);
    [item setTitle:privateAccount->tlsMethodModel()->data(qIdx, Qt::DisplayRole).toString().toNSString()];
    } else {
        QModelIndex qIdx = privateAccount->cipherModel()->index(index);
        [item setTitle:privateAccount->tlsMethodModel()->data(qIdx, Qt::DisplayRole).toString().toNSString()];
    }

    return YES;
}

- (NSInteger)numberOfItemsInMenu:(NSMenu *)menu
{
    if([menu.title isEqualToString:@"tlsmethods"])
        return privateAccount->tlsMethodModel()->rowCount();
    else
        return privateAccount->cipherModel()->rowCount();
}

@end
