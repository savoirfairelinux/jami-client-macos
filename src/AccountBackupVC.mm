/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
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

#import "AccountBackupVC.h"
#import "Constants.h"

//LRC
#import <api/lrc.h>
#import <api/newaccountmodel.h>

@interface AccountBackupVC () {
    __unsafe_unretained IBOutlet NSView* initialView;
    __unsafe_unretained IBOutlet NSView* errorView;
    __unsafe_unretained IBOutlet NSButton* skipBackupButton;
}

@end

@implementation AccountBackupVC
@synthesize accountModel, accountToBackup;

-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil accountmodel:(lrc::api::NewAccountModel*) accountModel {
    if (self =  [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.accountModel = accountModel;
    }
    return self;
}

-(void)show {
    [self.view setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    [initialView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    [errorView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    BOOL skipBackup = [[NSUserDefaults standardUserDefaults] boolForKey: SkipBackUpPage];
    [skipBackupButton setState: !skipBackup];
    [self.delegate showView: initialView];
}

- (IBAction)skip:(id)sender
{
    [self.delegate completedWithSuccess:YES];
}

- (IBAction)startAgain:(id)sender
{
    [self.delegate showView: initialView];
}

- (IBAction)alwaysSkipBackup:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:![sender state] forKey:SkipBackUpPage];
}

- (IBAction)exportAccount:(id)sender
{
    NSSavePanel* filePicker = [NSSavePanel savePanel];
    NSString* name  = [self.accountToBackup.toNSString() stringByAppendingString: @".gz"];
    [filePicker setNameFieldStringValue: name];
    if ([filePicker runModal] != NSFileHandlingPanelOKButton) {
        return;
    }
    NSString *password = @"";
    const char* fullPath = [[filePicker URL] fileSystemRepresentation];
    lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(self.accountToBackup);
    if(accountProperties.archiveHasPassword) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert addButtonWithTitle:@"Cancel"];
        [alert setMessageText: NSLocalizedString(@"Enter account password",
                                                 @"Backup enter password")];
        NSTextField *input = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 20)];
        [alert setAccessoryView:input];
        if ([alert runModal] != NSAlertFirstButtonReturn) {
            return;
        }
        password = [input stringValue];
    }
    if (self.accountModel->exportToFile(self.accountToBackup, fullPath, [password UTF8String])) {
        [self.delegate completedWithSuccess:YES];
    } else {
        [self.delegate showView: errorView];
    }
}

@end
