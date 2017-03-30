/*
 *  Copyright (C) 2015-2016 Savoir-faire Linux Inc.
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

#import "AccountChangingVC.h"

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

#import "Constants.h"
#import "views/NSImage+Extensions.h"
#import "delegates/ImageManipulationDelegate.h"

#import "views/AccountMenuItemView.h"

@interface AccountChangingVC () <NSMenuDelegate>

@end

@implementation AccountChangingVC {
    __unsafe_unretained IBOutlet NSImageView*   profileImage;
    __unsafe_unretained IBOutlet NSPopUpButton* accountSelectionButton;
}
Boolean menuIsOpen;
Boolean menuNeedsUpdate;
NSMenu* accountsMenu;
NSMenuItem* selectedMenuItem;
QMetaObject::Connection accountUpdate;
@synthesize accounts;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

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
    [self.view setHidden:(accounts.length() < 1)];
    [self chooseSelectedAccount];

    QObject::disconnect(accountUpdate);
    accountUpdate = QObject::connect(&AccountModel::instance(),
                                     &AccountModel::dataChanged,
                                     [=] {
                                         [self accountDataChanged];
                                     });
    QObject::connect(&AccountModel::instance(),
                     &AccountModel::selectedAccountChanged,
                     [=] {
                         [self selectionWasChanged];
                     });
}

-(NSMenu*) createMenu {
    accounts.clear();
    QList<Account*> allAccounts = AccountModel::instance().getAccountsByProtocol(Account::Protocol::RING);
    for (auto account : allAccounts) {
        if(account->isEnabled()) {
            accounts.append(account);
            NSMenuItem* menuBarItem = [[NSMenuItem alloc]
                                       initWithTitle:account->alias().toNSString() action:NULL keyEquivalent:@""];
            AccountMenuItemView *itemView = [[AccountMenuItemView alloc] initWithFrame:CGRectZero];

            [itemView.accountLabel setStringValue:account->alias().toNSString()];
            [itemView.userNameLabel setStringValue:account->registeredName().toNSString()];
            [itemView.accountTypeLabel setStringValue:@"Ring"];
            [menuBarItem setView:itemView];
            [accountsMenu addItem:menuBarItem];
            [accountsMenu addItem:[NSMenuItem separatorItem]];
        }
    }
    return accountsMenu;
}

-(void) chooseSelectedAccount {
    Account* selectedAccount = [self selectedAccount];
    if(accounts.count() > 0) {
        [accountSelectionButton selectItemWithTitle:selectedAccount->alias().toNSString()];
        AccountModel::instance().setSelectedAccount(selectedAccount);
    }
    [self.delegate updateRingIDWithAccount:selectedAccount];
}

-(Account *)selectedAccount {
    Account* registered = nullptr;
    Account* enabled = nullptr;
    Account* finalChoice = nullptr;

    finalChoice = AccountModel::instance().selectedAccount();

    if(finalChoice == nil || !finalChoice->isEnabled())
    {
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

-(void) selectionWasChanged {
    Account* newSelectedAccount = [self selectedAccountWaschanged];
    if(newSelectedAccount) {
        [accountSelectionButton selectItemWithTitle:newSelectedAccount->alias().toNSString()];
        [self.delegate updateRingIDWithAccount:newSelectedAccount];
    }
}

-(Account*) selectedAccountWaschanged {
    NSMenuItem *item = [accountSelectionButton selectedItem];
    Account *selectedAccount = AccountModel::instance().selectedAccount();
    if(!selectedAccount || !selectedAccount->isEnabled()) {
        return nil;
    }
    if(item && [selectedAccount->alias().toNSString() isEqualToString:item.title]) {
        return nil;
    }
    return selectedAccount;
}

-(void) accountDataChanged {
    if(!menuIsOpen) {
        Account *newSelectedAccount = [self selectedAccountWaschanged];
        if(newSelectedAccount) {
            NSString *string = AccountModel::instance().selectedAccount()->alias().toNSString();
            [accountsMenu removeAllItems];
            accountSelectionButton.menu = [self createMenu];
            [accountSelectionButton selectItemWithTitle:string];
            return;
        }
        [accountsMenu removeAllItems];
        accountSelectionButton.menu = [self createMenu];
        [self.view setHidden:(accounts.length() < 1)];
        [self chooseSelectedAccount];
    } else {
        menuNeedsUpdate = true;
    }
}
#pragma mark - NSPopUpButton item selection

- (IBAction)itemChanged:(id)sender {
    NSInteger index = [(NSPopUpButton *)sender indexOfSelectedItem];
    Account *selectedAccount = accounts.at(index/2);
    AccountModel::instance().setSelectedAccount(selectedAccount);
    [self.delegate updateRingIDWithAccount:selectedAccount];

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
