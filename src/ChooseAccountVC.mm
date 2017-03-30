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
QList<Account*> accounts;
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
    accountsMenu.removeAllItems;
    accountSelectionButton.menu = [self createMenu];
    [self.view setHidden:(accounts.length() == 0)];
    [self setSelection];

    QObject::disconnect(accountUpdate);
    accountUpdate = QObject::connect(&AccountModel::instance(),
                                     &AccountModel::dataChanged,
                                     [=] {
                                         [self accountDataChanged];
                                     });

    QObject::connect(AccountModel::instance().userSelectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {
                         if(!current.isValid())
                             return;
                         [self chosenAccoundWasChanged];
                     });
}

-(NSMenu*) createMenu {
    accounts.clear();
    QList<Account*> allAccounts = AccountModel::instance().getAccountsByProtocol(Account::Protocol::RING);
    for (auto account : allAccounts) {
        if(!account->isEnabled()) {
            continue;
        }
        accounts.append(account);
        NSMenuItem* menuBarItem = [[NSMenuItem alloc]
                                   initWithTitle:account->alias().toNSString() action:NULL keyEquivalent:@""];
        AccountMenuItemView *itemView = [[AccountMenuItemView alloc] initWithFrame:CGRectZero];
        [itemView.accountLabel setStringValue:account->alias().toNSString()];
        auto name = account->registeredName();
        NSString* userNameString = nullptr;
        if (!name.isNull() && !name.isEmpty()) {
            userNameString = name.toNSString();
        } else {
            userNameString = account->username().toNSString();
        }
        [itemView.userNameLabel setStringValue:userNameString];
        [itemView.accountTypeLabel setStringValue:@"Ring"];
        [menuBarItem setView:itemView];
        [accountsMenu addItem:menuBarItem];
        [accountsMenu addItem:[NSMenuItem separatorItem]];

    }
    return accountsMenu;
}

-(void) setSelection {
    Account* selectedAccount = [self selectedAccount];
    if(accounts.count() > 0) {
        [accountSelectionButton selectItemWithTitle:selectedAccount->alias().toNSString()];
        AccountModel::instance().setUserChosenAccount(selectedAccount);
    }
}

-(Account *)selectedAccount {
    Account* registered = nullptr;
    Account* enabled = nullptr;
    Account* finalChoice = nullptr;

    finalChoice = AccountModel::instance().userChosenAccount();

    if(finalChoice == nil || !finalChoice->isEnabled()) {
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

-(Account*) newChosenAccount {
    NSMenuItem *item = [accountSelectionButton selectedItem];
    Account *selectedAccount = AccountModel::instance().userChosenAccount();
    if(!selectedAccount || !selectedAccount->isEnabled()) {
        return nil;
    }
    if(item && [selectedAccount->alias().toNSString() isEqualToString:item.title]) {
        return nil;
    }
    return selectedAccount;
}

-(Boolean) shouldUpdateMenuSelection {
    NSMenuItem *item = [accountSelectionButton selectedItem];
    Account *selectedAccount = AccountModel::instance().userChosenAccount();
    if(!selectedAccount || !selectedAccount->isEnabled()) {
        return true;
    }
    if(item && [selectedAccount->alias().toNSString() isEqualToString:item.title]) {
        return false;
    }

    return true;
}

#pragma mark - received signals

-(void) chosenAccoundWasChanged {
    Account* newChosenAccount = [self newChosenAccount];
    if(newChosenAccount) {
        if([accountSelectionButton itemWithTitle:newChosenAccount->alias().toNSString()])
            [accountSelectionButton selectItemWithTitle:newChosenAccount->alias().toNSString()];
    }
}

-(void) accountDataChanged {
    if(!menuIsOpen) {
        if(![self shouldUpdateMenuSelection]) {
            NSString *string = [accountSelectionButton selectedItem].title;
            [accountsMenu removeAllItems];
            accountSelectionButton.menu = [self createMenu];
            [accountSelectionButton selectItemWithTitle:string];
            return;
        }
        [accountsMenu removeAllItems];
        accountSelectionButton.menu = [self createMenu];
        [self.view setHidden:(accounts.length() == 0)];
        [self setSelection];
    } else {
        menuNeedsUpdate = true;
    }
}
#pragma mark - NSPopUpButton item selection

- (IBAction)itemChanged:(id)sender {
    NSInteger index = [(NSPopUpButton *)sender indexOfSelectedItem];
    Account *selectedAccount = accounts.at(index/2);
    AccountModel::instance().setUserChosenAccount(selectedAccount);
    Account *account = [self selectedAccount];
    [accountSelectionButton selectItemWithTitle:account->alias().toNSString()];
}

#pragma mark - NSMenuDelegate
- (void)menuWillOpen:(NSMenu *)menu {
    menuIsOpen = true;
    selectedMenuItem = [accountSelectionButton selectedItem];
    if(menuNeedsUpdate) {
        [self accountDataChanged];
    }
}
- (void)menuDidClose:(NSMenu *)menu {

    menuIsOpen = false;
}

- (void)menu:(NSMenu *)menu willHighlightItem:(nullable NSMenuItem *)item {
    if(selectedMenuItem) {
        if(selectedMenuItem != item) {
            int index = [menu indexOfItem:selectedMenuItem];
            [menu removeItemAtIndex:index];
            [menu insertItem:selectedMenuItem atIndex:index];
            [accountSelectionButton selectItemAtIndex:index];
            selectedMenuItem = nil;
        }
    }
}

@end
