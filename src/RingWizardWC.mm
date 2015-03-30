/*
 *  Copyright (C) 2015 Savoir-Faire Linux Inc.
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
#import "RingWizardWC.h"

#import <accountmodel.h>
#import <protocolmodel.h>
#import <QItemSelectionModel>
#import <account.h>

#import "AppDelegate.h"


@interface RingWizardWC ()
@property (assign) IBOutlet NSButton *goToAppButton;
@property (assign) IBOutlet NSTextField *nickname;
@property (assign) IBOutlet NSProgressIndicator *progressBar;
@property (assign) IBOutlet NSTextField *indicationLabel;
@property (assign) IBOutlet NSButton *createButton;
@end

@implementation RingWizardWC
@synthesize goToAppButton;
@synthesize nickname;
@synthesize progressBar;
@synthesize indicationLabel;
@synthesize createButton;

- (void)windowDidLoad {
    [super windowDidLoad];

    [self.window makeKeyAndOrderFront:nil];
    [self.window setLevel:NSStatusWindowLevel];
    [self.window makeMainWindow];
    [self checkForRingAccount];
}

- (void) checkForRingAccount
{
    for (int i = 0 ; i < AccountModel::instance()->rowCount() ; ++i) {
        QModelIndex idx = AccountModel::instance()->index(i);
        Account* acc = AccountModel::instance()->getAccountByModelIndex(idx);
        if(acc->protocol() == Account::Protocol::RING) {
            [indicationLabel setStringValue:@"Ring is already ready to work"];
            [self displayHash:acc->username().toNSString()];
        }
    }
}

- (void) displayHash:(NSString* ) hash
{
    [nickname setFrameSize:NSMakeSize(400, nickname.frame.size.height)];
    [nickname setStringValue:hash];
    [nickname setEditable:NO];
    [nickname setHidden:NO];

    [goToAppButton setHidden:NO];

    NSSharingService* emailSharingService = [NSSharingService sharingServiceNamed:NSSharingServiceNameComposeEmail];

    [createButton setTitle:@"Share by mail"];
    //[createButton setImage:emailSharingService.image];
    [createButton setAlternateImage:emailSharingService.alternateImage];
    [createButton setAction:@selector(shareByEmail)];
}

- (IBAction)createRingAccount:(id)sender {

    [nickname setHidden:YES];
    [progressBar setHidden:NO];
    [createButton setEnabled:NO];
    [indicationLabel setStringValue:@"Just a moment..."];

    QModelIndex qIdx =  AccountModel::instance()->protocolModel()->selectionModel()->currentIndex();

    [self setCallback];
    [self performSelector:@selector(saveAccount) withObject:nil afterDelay:1];

}

- (void) saveAccount
{
    NSString* newAccName = @"My Ring";
    Account* newAcc = AccountModel::instance()->add([newAccName UTF8String], Account::Protocol::RING);
    newAcc->setAlias([[nickname stringValue] UTF8String]);
    newAcc << Account::EditAction::SAVE;
}

- (void) setCallback
{
    QObject::connect(AccountModel::instance(),
                     &AccountModel::accountStateChanged,
                     [=](Account *account, const Account::RegistrationState state) {
                         NSLog(@"Account created!");
                         [progressBar setHidden:YES];
                         [createButton setEnabled:YES];
                         [indicationLabel setStringValue:@"This is your number, share it with your friends!"];
                         [self displayHash:account->username().toNSString()];
                     });
}

- (IBAction)goToApp:(id)sender {
    [self.window close];
    AppDelegate *appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
    [appDelegate showMainWindow];
}

- (void) shareByEmail
{
    /*
     Create the array of items to share.
     Start with just the content of the text view. If there's an image, add that too.
     */
    NSMutableArray *shareItems = [[NSMutableArray alloc] initWithObjects:[nickname stringValue], nil];
    NSSharingService* emailSharingService = [NSSharingService sharingServiceNamed:NSSharingServiceNameComposeEmail];

    /*
     Perform the service using the array of items.
     */
    [emailSharingService performWithItems:shareItems];
}


# pragma NSWindowDelegate methods

- (BOOL)windowShouldClose:(id)sender
{
   NSLog(@"windowShouldClose");
    return YES;
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
    NSLog(@"windowDidBecomeKey");
}

- (void)windowDidResignKey:(NSNotification *)notification
{
    NSLog(@"windowDidResignKey");
}

- (void)windowDidBecomeMain:(NSNotification *)notification
{
    NSLog(@"windowDidBecomeMain");
}

- (void)windowDidResignMain:(NSNotification *)notification
{
    NSLog(@"windowDidResignMain");
    [self.window close];
}

- (void)windowWillClose:(NSNotification *)notification
{
    //NSLog(@"windowWillClose");
    AppDelegate *appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
    [appDelegate showMainWindow];
}

@end
