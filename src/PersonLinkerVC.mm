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

#import "PersonLinkerVC.h"

@interface PersonLinkerVC () <NSTextFieldDelegate, NSComboBoxDelegate, NSComboBoxDataSource> {

    __unsafe_unretained IBOutlet NSTextField *contactMethodLabel;
    __unsafe_unretained IBOutlet NSTableView *personsView;
    __unsafe_unretained IBOutlet NSTextField *firstNameField;
    __unsafe_unretained IBOutlet NSTextField *lastNameField;
    __unsafe_unretained IBOutlet NSButton *createNewContactButton;
    __unsafe_unretained IBOutlet NSComboBox *categoryComboBox;
    __unsafe_unretained IBOutlet NSView *linkToExistingSubview;
    __unsafe_unretained IBOutlet NSView *addCloudContactMsg;

    IBOutlet NSView *createContactSubview;
}

@end

@implementation PersonLinkerVC

//Tags for views
NSInteger const FIRSTNAME_TAG = 1;
NSInteger const LASTNAME_TAG = 2;
NSInteger const IMAGE_TAG = 100;
NSInteger const DISPLAYNAME_TAG = 200;
NSInteger const DETAILS_TAG = 300;

-(void) awakeFromNib
{
    NSLog(@"INIT PersonLinkerVC");

    [firstNameField setTag:FIRSTNAME_TAG];
    [lastNameField setTag:LASTNAME_TAG];

    [categoryComboBox selectItemAtIndex:0];
    [personsView setTarget:self];
    [personsView setDoubleAction:@selector(addToContact:)];
}

- (IBAction)presentNewContactForm:(id)sender {
    [createContactSubview setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [addCloudContactMsg setHidden:TRUE];

    [createContactSubview setFrame:linkToExistingSubview.frame];
    [linkToExistingSubview setHidden:YES];
    [self.view addSubview:createContactSubview];

    [[[NSApplication sharedApplication] mainWindow] makeFirstResponder:firstNameField];
    [firstNameField setNextKeyView:lastNameField];
    [lastNameField setNextKeyView:createNewContactButton];
    [createNewContactButton setNextKeyView:firstNameField];
}

#pragma mark - NSTextFieldDelegate

- (void)controlTextDidChange:(NSNotification *) notification
{
    if ([notification.object tag] == FIRSTNAME_TAG || [notification.object tag] == LASTNAME_TAG) {
        NSTextView *textView = notification.userInfo[@"NSFieldEditor"];
        BOOL enableCreate = textView.textStorage.string.length > 0;
        [createNewContactButton setEnabled:enableCreate];
    } else {
        NSTextView *textView = notification.userInfo[@"NSFieldEditor"];
        // TODO filter
        [personsView scrollToBeginningOfDocument:nil];
    }
}

@end
