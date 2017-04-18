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
#import <AvailableAccountModel.h>

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
    [self update];

    QObject::disconnect(accountUpdate);
    accountUpdate =
    QObject::connect(&AccountModel::instance(),
                     &AccountModel::dataChanged,
                     [=] {
                         [self update];
                     });
    QObject::connect(
                     &AvailableAccountModel::instance(),
                     &AvailableAccountModel::currentDefaultAccountChanged,
                     [self] (Account* a)
                     {
                         [self update];
                     });
}

-(void) updateMenu {
    [accountsMenu removeAllItems];
    int number =  AvailableAccountModel::instance().rowCount();
    for (int i = 0; i < number; i++) {

        QModelIndex index = AvailableAccountModel::instance().selectionModel()->model()->index(i, 0);
        Account* account = index.data(static_cast<int>(Account::Role::Object)).value<Account*>();
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

-(void) update {
    if(menuIsOpen) {
        return;
    }
    [self updateMenu];
    [self setPopUpButtonSelection];
}

-(void) setPopUpButtonSelection {
    if(accountsMenu.itemArray.count == 0) {
        [self.view setHidden:YES];
        return;
    }
    [self.view setHidden:NO];
    QModelIndex index = AvailableAccountModel::instance().selectionModel()->currentIndex();
    Account* account = index.data(static_cast<int>(Account::Role::Object)).value<Account*>();
    if(account == nil){
        return;
    }
    [accountSelectionButton selectItemWithTitle:[self itemTitleForAccount:account]];
}

#pragma mark - NSPopUpButton item selection

- (IBAction)itemChanged:(id)sender {
    NSInteger row = [(NSPopUpButton *)sender indexOfSelectedItem] / 2;
    QModelIndex index = AvailableAccountModel::instance().selectionModel()->model()->index(row, 0);
    AvailableAccountModel::instance().selectionModel()->setCurrentIndex(index, QItemSelectionModel::ClearAndSelect);
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
    int index = [menu indexOfItem:selectedMenuItem];
    [menu removeItemAtIndex:index];
    [menu insertItem:selectedMenuItem atIndex:index];
    [accountSelectionButton selectItemAtIndex:index];
    selectedMenuItem = nil;
}

@end
