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

#import "BrokerVC.h"

@interface BrokerVC ()

@property BrokerMode mode;
@property (unsafe_unretained) IBOutlet NSTableView *smartView;
@end

@implementation BrokerVC

// Tags for views
NSInteger const IMAGE_TAG       =   100;
NSInteger const DISPLAYNAME_TAG =   200;
NSInteger const DETAILS_TAG     =   300;
NSInteger const CALL_BUTTON_TAG =   400;
NSInteger const TXT_BUTTON_TAG  =   500;

- (instancetype)initWithMode:(BrokerMode)m {
    self = [super init];
    if (self) {
        [self setMode:m];
    }
    return self;
}

- (NSString *)nibName
{
    return @"Broker";
}

- (void)loadView
{
    [super loadView];
    [_smartView setTarget:self];

    if ([self mode] == BrokerMode::TRANSFER) {
        [_smartView setDoubleAction:@selector(placeTransfer:)];
    } else {
        [_smartView setDoubleAction:@selector(addParticipant:)];
    }

}

// -------------------------------------------------------------------------------
// transfer on click on Contact
// -------------------------------------------------------------------------------
//TODO
- (void)placeTransfer:(id)sender
{

}

// -------------------------------------------------------------------------------
// transfer to unknown URI
// -------------------------------------------------------------------------------
//TODO
- (void) transferTo:(NSString*) uri
{

}

// -------------------------------------------------------------------------------
// place a call to the future participant on click on Contact
// -------------------------------------------------------------------------------
//TODO
- (void)addParticipant:(id)sender
{

}

// -------------------------------------------------------------------------------
// place a call to the future participant with entered URI
// -------------------------------------------------------------------------------
//TODO
- (void) addParticipantFromUri:(NSString*) uri
{

}

#pragma mark - NSTextFieldDelegate

- (BOOL)control:(NSControl *)control textView:(NSTextView *)fieldEditor doCommandBySelector:(SEL)commandSelector
{
    if (commandSelector == @selector(insertNewline:)) {
        if([fieldEditor.textStorage.string isNotEqualTo:@""]) {

            if ([self mode] == BrokerMode::TRANSFER) {
                [self transferTo:fieldEditor.textStorage.string];
            } else {
                [self addParticipantFromUri:fieldEditor.textStorage.string];
            }
            return YES;
        }
    }

    return NO;
}

- (void)controlTextDidChange:(NSNotification *) notification
{
    NSTextView *textView = notification.userInfo[@"NSFieldEditor"];
}

@end
