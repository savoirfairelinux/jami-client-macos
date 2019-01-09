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
#import "BackupAccountWC.h"

//LRC
#import <api/lrc.h>
#import <api/newaccountmodel.h>

//Ring
#import "views/ITProgressIndicator.h"

@interface BackupAccountWC() <NSTextFieldDelegate> {
    __unsafe_unretained IBOutlet NSPathControl* path;
    __unsafe_unretained IBOutlet ITProgressIndicator* progressIndicator;
    __unsafe_unretained IBOutlet NSButton* cancelButton;
}

@end

@implementation BackupAccountWC {
    struct {
        unsigned int didCompleteExport:1;
    } delegateRespondsTo;
}

@synthesize accountModel;

-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil accountmodel:(lrc::api::NewAccountModel*) accountModel
{
    if (self = [self initWithWindowNibName:nibNameOrNil])
    {
        self.accountModel= accountModel;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    NSArray * paths = NSSearchPathForDirectoriesInDomains (NSDownloadsDirectory, NSUserDomainMask, YES);
    if(paths.count <= 0) {
        return;
    }
    NSString * downloadPath = [paths objectAtIndex:0];
    [path setURL: [NSURL URLWithString: downloadPath]];
}

- (void)setDelegate:(id <BackupAccountDelegate>)aDelegate
{
    if (self.delegate != aDelegate) {
        [super setDelegate: aDelegate];
        delegateRespondsTo.didCompleteExport = [self.delegate respondsToSelector:@selector(didCompleteExportWithPath:)];
    }
}

- (void) setAllowFileSelection:(BOOL) b
{
    _allowFileSelection = b;
    [path setAllowedTypes:_allowFileSelection ? nil : [NSArray arrayWithObject:@"public.folder"]];
}

- (IBAction)completeAction:(id)sender
{
    auto finalURL = [path.URL URLByAppendingPathComponent:[@"Account_" stringByAppendingString: @(std::string(self.selectedAccountID + ".gz").c_str())]];
    [self showLoading];
    if (self.accountModel->exportToFile(self.selectedAccountID, finalURL.path.UTF8String)) {
        if (delegateRespondsTo.didCompleteExport) {
            [((id<BackupAccountDelegate>)self.delegate) didCompleteExportWithPath:finalURL];
        }
        [self close];
        [self.window.sheetParent endSheet: self.window];
    } else {
        [self showError];
    }
}

- (void)showLoading
{
    [progressIndicator setNumberOfLines:30];
    [progressIndicator setWidthOfLine:2];
    [progressIndicator setLengthOfLine:5];
    [progressIndicator setInnerMargin:20];
    [super showLoading];
}

- (IBAction)pathControlSingleClick:(id)sender {
    [path setURL:[[path clickedPathComponentCell] URL]];
}

#pragma mark - NSPathControlDelegate

- (void)pathControl:(NSPathControl *)pathControl willPopUpMenu:(NSMenu *)menu {
    while ([[menu itemArray] count] >= 4) {
        [menu removeItemAtIndex:3];
    }
}
- (void)pathControl:(NSPathControl *)pathControl willDisplayOpenPanel:(NSOpenPanel *)openPanel
{
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setResolvesAliases:YES];
    NSArray * paths = NSSearchPathForDirectoriesInDomains (NSDownloadsDirectory, NSUserDomainMask, YES);
    if(paths.count <= 0) {
        return;
    }
    NSString * downloadPath = [paths objectAtIndex:0];
    [openPanel setDirectoryURL:[NSURL URLWithString: downloadPath]];
    [openPanel setDelegate:self];
}

@end
