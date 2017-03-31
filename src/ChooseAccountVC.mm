/*
 *  Copyright (C) 2015-2017 Savoir-faire Linux Inc.
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

#import "ChooseAccountVC.h"

//Qt
#import <QSize>
#import <QtMacExtras/qmacfunctions.h>
#import <QPixmap>

//LRC
#import <profilemodel.h>
#import <profile.h>
#import <person.h>
#import <globalinstances.h>
#import <accountmodel.h>
#import <account.h>
#import <QItemSelectionModel.h>
#import <interfaces/pixmapmanipulatori.h>
//RING
#import "views/AccountMenuItemView.h"
#import "PendingContactRequestVC.h"

@interface ChooseAccountVC () <NSMenuDelegate>

@end

@implementation ChooseAccountVC {
    __unsafe_unretained IBOutlet NSImageView*   profileImage;
    __unsafe_unretained IBOutlet NSPopUpButton* accountSelectionButton;
}
Boolean menuIsOpen;
Boolean menuNeedsUpdate;
NSMenu* accountsMenu;
NSMenuItem* selectedMenuItem;
QMetaObject::Connection accountUpdate;

- (void)awakeFromNib
{
    [profileImage setWantsLayer: YES];
    profileImage.layer.cornerRadius = profileImage.frame.size.width / 2;
    profileImage.layer.masksToBounds = YES;

    if (auto pro = ProfileModel::instance().selectedProfile()) {
        auto photo = GlobalInstances::pixmapManipulator().contactPhoto(pro->person(), {140,140});
        [profileImage setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(photo))];
    }

    accountsMenu = [[NSMenu alloc] initWithTitle:@""];
    [accountsMenu setDelegate:self];
    accountSelectionButton.menu = accountsMenu;
    [self updateAndChangeChosenAccount: YES];

    QObject::disconnect(accountUpdate);
    accountUpdate = QObject::connect(&AccountModel::instance(),
                                     &AccountModel::dataChanged,
                                     [=] {
                                          [self updateAndChangeChosenAccount: YES];
                                     });

    QObject::connect(AccountModel::instance().userSelectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {
                          [self updateAndChangeChosenAccount: NO];
                     });
}

-(void) updateMenu {
    [accountsMenu removeAllItems];
    QList<Account*> allAccounts = AccountModel::instance().getAccountsByProtocol(Account::Protocol::RING);
    NSInteger count = allAccounts.count();
    AccountModel::instance().remo
    NSLog(@"numberOfAccount, %d",count);

    for (auto account : allAccounts) {
        NSMenuItem* menuBarItem = [[NSMenuItem alloc]
                                   initWithTitle:[self itemTitleForAccount:account] action:NULL keyEquivalent:@""];
        menuBarItem.attributedTitle = [self attributedItemTitleForAccount:account];
        AccountMenuItemView *itemView = [[AccountMenuItemView alloc] initWithFrame:CGRectZero];
        [itemView.accountLabel setStringValue:account->alias().toNSString()];
        NSString* userNameString = [self nameForAccount: account];
        [itemView.userNameLabel setStringValue:userNameString];
        [itemView.accountTypeLabel setStringValue:@"Ring"];
        auto humanState = account->toHumanStateName();
        [itemView.accountStatus setStringValue:humanState.toNSString()];
        [menuBarItem setView:itemView];
        [accountsMenu addItem:menuBarItem];
        [accountsMenu addItem:[NSMenuItem separatorItem]];

    }
}

-(NSString*) nameForAccount:(Account*) account {
    auto name = account->registeredName();
    NSString* userNameString = nullptr;
    if (!name.isNull() && !name.isEmpty()) {
        userNameString = name.toNSString();
    } else {
        userNameString = account->username().toNSString();
    }
    return userNameString;
}

-(NSString*) itemTitleForAccount:(Account*) account {
    NSString* alias = account->alias().toNSString();
    alias = [NSString stringWithFormat: @"%@\n", alias];
    NSString* userNameString = [self nameForAccount: account];
    return [alias stringByAppendingString:userNameString];
}

- (NSAttributedString*) attributedItemTitleForAccount:(Account*) account {
    NSString* alias = account->alias().toNSString();
    alias = [NSString stringWithFormat: @"%@\n", alias];
    NSString* userNameString = [self nameForAccount: account];
    NSFont *fontAlias = [NSFont userFontOfSize:14.0];
    NSFont *fontUserName = [NSFont userFontOfSize:11.0];
    NSColor *colorAlias = [NSColor labelColor];
    NSColor *colorAUserName = [NSColor secondaryLabelColor];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    NSDictionary *aliasAttrs = [NSDictionary dictionaryWithObjectsAndKeys:fontAlias,NSFontAttributeName,
                                colorAlias,NSForegroundColorAttributeName,
                                paragraphStyle,NSParagraphStyleAttributeName, nil];
    NSDictionary *userNameAttrs = [NSDictionary dictionaryWithObjectsAndKeys:fontUserName,NSFontAttributeName,
                                   colorAUserName,NSForegroundColorAttributeName,
                                   paragraphStyle,NSParagraphStyleAttributeName, nil];
    NSAttributedString* attributedString = [[NSAttributedString alloc] initWithString:alias attributes:aliasAttrs];
    NSAttributedString* attributedStringSecond= [[NSAttributedString alloc] initWithString:userNameString attributes:userNameAttrs];
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
    [result appendAttributedString:attributedString];
    [result appendAttributedString:attributedStringSecond];
    return result;
}

-(Account *)selectedAccount {
    Account* finalChoice = nullptr;
    finalChoice = AccountModel::instance().userChosenAccount();

    if(finalChoice == nil) {
        Account* registered = nullptr;
        Account* enabled = nullptr;
        auto ringList = AccountModel::instance().getAccountsByProtocol(Account::Protocol::RING);
        for (int i = 0 ; i < ringList.size() && !registered ; ++i) {
            auto account = ringList.value(i);
            if (account->isEnabled()) {
                if(!enabled) {
                    enabled = finalChoice = account;
                }
                if (account->registrationState() == Account::RegistrationState::READY) {
                    registered = enabled = finalChoice = account;
                }
            } else {
                if (!finalChoice) {
                    finalChoice = account;
                }
            }
        }
    }
    return finalChoice;
}


-(void) updateAndChangeChosenAccount:(Boolean)shouldUpdateChosenAccount {

    [self updateMenu];
    [self selectMenuItemAndUpdatechoosenAccount:shouldUpdateChosenAccount];
}

-(void) selectMenuItemAndUpdatechoosenAccount:(Boolean) shouldUpdateChosenAccount {
    if(accountsMenu.itemArray.count == 0) {
        [self.view setHidden:YES];
        return;
    }
    Account* selectedAccount = [self selectedAccount];
    if([accountSelectionButton itemWithTitle:[self itemTitleForAccount:selectedAccount]]){
        [accountSelectionButton selectItemWithTitle:[ self itemTitleForAccount:selectedAccount]];
        if (!shouldUpdateChosenAccount) {
            return;
        }
        AccountModel::instance().setUserChosenAccount(selectedAccount);
    }
}

#pragma mark - NSPopUpButton item selection

- (IBAction)itemChanged:(id)sender {
    NSInteger index = [(NSPopUpButton *)sender indexOfSelectedItem];
     QList<Account*> allAccounts = AccountModel::instance().getAccountsByProtocol(Account::Protocol::RING);
    // menu contains accounts and separation lines, so divide it by 2 to get account index
    Account *selectedAccount = allAccounts.at(index/2);
    AccountModel::instance().setUserChosenAccount(selectedAccount);
}

#pragma mark - NSMenuDelegate
- (void)menuWillOpen:(NSMenu *)menu {
    menuIsOpen = true;
    // remember selected item to remove highlighting when menu is open
    selectedMenuItem = [accountSelectionButton selectedItem];
}
- (void)menuDidClose:(NSMenu *)menu {

    menuIsOpen = false;
}

- (void)menu:(NSMenu *)menu willHighlightItem:(nullable NSMenuItem *)item {
    if (!selectedMenuItem || selectedMenuItem == item) {
        return;
    }
    // remove item to clean hihlighting
    if(![menu indexOfItem:selectedMenuItem]) {
        return;
    }
    int index = [menu indexOfItem:selectedMenuItem];
    [menu removeItemAtIndex:index];
    [menu insertItem:selectedMenuItem atIndex:index];
    [accountSelectionButton selectItemAtIndex:index];
    selectedMenuItem = nil;
}

@end
