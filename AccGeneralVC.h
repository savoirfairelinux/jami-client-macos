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
#ifndef ACCGENERALVC_H
#define ACCGENERALVC_H

#import <Cocoa/Cocoa.h>

#include <account.h>

@interface AccGeneralVC : NSViewController <NSTextFieldDelegate> {
    NSTextField *aliasTextField;
    NSTextField *serverHostTextField;
    NSTextField *usernameTextField;
    NSSecureTextField *passwordTextField;
    NSButton *upnpButton;
    NSButton *autoAnswerButton;
    NSButton *userAgentButton;
    NSTextField *userAgentTextField;
    NSView *boxingAccount;
    NSView *boxingParameters;
    NSTextField *typeLabel;
}

@property (assign) IBOutlet NSView *boxingAccount;
@property (assign) IBOutlet NSView *boxingParameters;

@property (assign) IBOutlet NSTextField *aliasTextField;
@property (assign) IBOutlet NSTextField *typeLabel;

@property (assign) IBOutlet NSTextField *serverHostTextField;
@property (assign) IBOutlet NSTextField *usernameTextField;
@property (assign) IBOutlet NSSecureTextField *passwordTextField;

@property (assign) IBOutlet NSButton *upnpButton;
@property (assign) IBOutlet NSButton *autoAnswerButton;
@property (assign) IBOutlet NSButton *userAgentButton;



@property (assign) IBOutlet NSTextField *userAgentTextField;

- (IBAction)toggleUpnp:(NSButton *)sender;
- (IBAction)toggleAutoAnswer:(NSButton *)sender;
- (IBAction)toggleCustomAgent:(NSButton *)sender;

- (void)loadAccount:(Account *)account;

@end

#endif // ACCGENERALVC_H