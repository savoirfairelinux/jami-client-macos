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
#import "ExportPasswordWC.h"

//LRC
#import <account.h>

//Ring
#import "views/ITProgressIndicator.h"
@interface ExportPasswordWC() <NSTextFieldDelegate>{
    __unsafe_unretained IBOutlet NSSecureTextField* passwordField;
    __unsafe_unretained IBOutlet NSTextField* resultField;
    __unsafe_unretained IBOutlet NSTextField* errorField;
    __unsafe_unretained IBOutlet ITProgressIndicator* progressIndicator;
}
@end

@implementation ExportPasswordWC {
    struct {
        unsigned int didStart:1;
        unsigned int didComplete:1;
    } delegateRespondsTo;
}

@synthesize account;
QMetaObject::Connection accountConnection;


#pragma mark - Initialize
- (id)initWithDelegate:(id <ExportPasswordDelegate>) del actionCode:(NSInteger) code
{
    return [super initWithWindowNibName:@"ExportPasswordWindow" delegate:del actionCode:code];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
}

- (void)setDelegate:(id <ExportPasswordDelegate>)aDelegate
{
    if (super.delegate != aDelegate) {
        [super setDelegate: aDelegate];
        delegateRespondsTo.didStart = [aDelegate respondsToSelector:@selector(didStartWithPassword:)];
        delegateRespondsTo.didComplete = [aDelegate respondsToSelector:@selector(didCompleteWithPin:Password:)];
    }
}

- (void)showError:(NSString*) errorMessage
{
    [errorField setStringValue:errorMessage];
    [super showError];
}

- (void)showLoading
{
    [progressIndicator setNumberOfLines:30];
    [progressIndicator setWidthOfLine:2];
    [progressIndicator setLengthOfLine:5];
    [progressIndicator setInnerMargin:20];
    [super showLoading];
}

#pragma mark - Events Handlers
- (IBAction)completeAction:(id)sender
{
    // Check to avoid exporting an old account (not supported by daemon)
    if (account->needsMigration()) {
        [self showError:NSLocalizedString(@"You have to migrate your account before exporting", @"Error shown to user")];
    } else {
        NSString* password = passwordField.stringValue;
        [self showLoading];
        QObject::disconnect(accountConnection);
        accountConnection = QObject::connect(account,
                                             &Account::exportOnRingEnded,
                                             [=](Account::ExportOnRingStatus status,const QString &pin) {
                                                 NSLog(@"Export ended!");
                                                 switch (status) {
                                                     case Account::ExportOnRingStatus::SUCCESS:{
                                                         NSString *nsPin = pin.toNSString();
                                                         NSLog(@"Export ended with Success, pin is %@",nsPin);
                                                         [resultField setAttributedStringValue:[self formatPinMessage:nsPin]];
                                                         [self showFinal];
                                                     }
                                                         break;
                                                     case Account::ExportOnRingStatus::WRONG_PASSWORD:{
                                                         NSLog(@"Export ended with Wrong Password");
                                                         [self showError:NSLocalizedString(@"Export ended with Wrong Password", @"Error shown to the user" )];
                                                     }
                                                         break;
                                                     case Account::ExportOnRingStatus::NETWORK_ERROR:{
                                                         NSLog(@"Export ended with NetworkError!");
                                                         [self showError:NSLocalizedString(@"A network error occured during the export", @"Error shown to the user" )];
                                                     }
                                                         break;
                                                     default:{
                                                         NSLog(@"Export ended with Unknown status!");
                                                         [self showError:NSLocalizedString(@"An error occured during the export", @"Error shown to the user" )];
                                                     }
                                                         break;
                                                 }
                                             });
        account->exportOnRing(QString::fromNSString(password));
    }
}

//TODO: Move String formatting to a dedicated Utility Classes
- (NSAttributedString *)formatPinMessage:(NSString*) pin
{
    NSMutableAttributedString* hereIsThePin = [[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"Your generated pin:","Title shown to user to concat with Pin")];
    NSMutableAttributedString* thePin = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"\n%@\n", pin]];
    [thePin beginEditing];
    NSRange range = NSMakeRange(0, [thePin length]);
    [thePin addAttribute:NSFontAttributeName value:[NSFont fontWithName:@"Helvetica-Bold" size:12.0] range:range];
    [hereIsThePin appendAttributedString:thePin];
    NSMutableAttributedString* infos = [[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"This pin and the account password should be entered on your new device within 5 minutes. On most client, this is done from \"Existing Ring account\" menu. You may generate a new pin at any moment.","Infos on how to use the pin")];
    [hereIsThePin appendAttributedString:infos];

    return hereIsThePin;
}

@end
