/*
 *  Copyright (C) 2015-2017 Savoir-faire Linux Inc.
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Olivier Soldano <olivier.soldano@savoirfairelinux.com>
 *  Author: Anthony Léonard <anthony.leonard@savoirfairelinux.com>
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
#import <globalinstances.h>
#import <QItemSelectionModel.h>
#import <interfaces/pixmapmanipulatori.h>
#import <api/newaccountmodel.h>
#import <api/account.h>

//RING
#import "views/AccountMenuItemView.h"
#import "AccountSelectionManager.h"
#import "RingWindowController.h"
#import "utils.h"

@interface ChooseAccountVC () <NSMenuDelegate>

@end

@implementation ChooseAccountVC {

    __unsafe_unretained IBOutlet NSImageView*   profileImage;
    __unsafe_unretained IBOutlet NSPopUpButton* accountSelectionButton;
    const lrc::api::NewAccountModel* accMdl_;
    AccountSelectionManager* accountSelectionManager_;
    RingWindowController* delegate;

}
Boolean menuIsOpen;
Boolean menuNeedsUpdate;
NSMenu* accountsMenu;
NSMenuItem* selectedMenuItem;

-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil model:(const lrc::api::NewAccountModel*) accMdl delegate:(RingWindowController *)mainWindow
{
    accMdl_ = accMdl;
    accountSelectionManager_ = [[AccountSelectionManager alloc] initWithAccountModel:accMdl_];
    delegate = mainWindow;
    return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
}

- (void)awakeFromNib
{
    [profileImage setWantsLayer: YES];
    profileImage.layer.cornerRadius = profileImage.frame.size.width / 2;
    profileImage.layer.masksToBounds = YES;

    accountsMenu = [[NSMenu alloc] initWithTitle:@""];
    [accountsMenu setDelegate:self];
    accountSelectionButton.menu = accountsMenu;
    [accountSelectionButton setAutoenablesItems:NO];
    [self update];

    QObject::connect(accMdl_,
                     &lrc::api::NewAccountModel::accountAdded,
                     [self] (const std::string& accountID) {
                         [self update];
                         @try {
                             auto& account = [self selectedAccount];
                             [delegate selectAccount:account];
                         }
                         @catch (NSException * e) {
                             NSLog(@"account selection failed");
                         }
                     });
    QObject::connect(accMdl_,
                     &lrc::api::NewAccountModel::accountRemoved,
                     [self] (const std::string& accountID) {
                         if ([self selectedAccount].id.compare(accountID) == 0) {
                             [accountSelectionManager_ clearSelectedAccount];
                         }
                         @try {
                             auto& account = [self selectedAccount];
                             [delegate selectAccount:account];
                         }
                         @catch (NSException * e) {
                             [delegate allAccountsDeleted];
                         }
                         [self update];
                     });
    QObject::connect(accMdl_,
                     &lrc::api::NewAccountModel::profileUpdated,
                     [self] (const std::string& accountID) {
                         [self update];
                     });
    QObject::connect(accMdl_,
                     &lrc::api::NewAccountModel::accountStatusChanged,
                     [self] (const std::string& accountID) {
                         [self update];
                     });
}

-(const lrc::api::account::Info&) selectedAccount
{
    try {
        return [accountSelectionManager_ savedAccount];
    } catch (NSException *ex) {
        auto accountList = accMdl_->getAccountList();
        if (!accountList.empty()) {
            const auto& fallbackAccount = accMdl_->getAccountInfo(accountList.at(0));
            if (accountList.size() == 1) {
                [accountSelectionManager_ setSavedAccount:fallbackAccount];
            }
            return fallbackAccount;
        } else {
            NSException* noAccEx = [NSException
                                    exceptionWithName:@"NoAccountException"
                                    reason:@"No account in AccountModel"
                                    userInfo:nil];
            @throw noAccEx;
        }
    }
}

-(void) updateMenu {
    [accountsMenu removeAllItems];

    auto accList = accMdl_->getAccountList();

    for (std::string accId : accList) {
        auto& account = accMdl_->getAccountInfo(accId);

        NSMenuItem* menuBarItem = [[NSMenuItem alloc]
                                   initWithTitle:[self itemTitleForAccount:account]
                                   action:NULL
                                   keyEquivalent:@""];

        menuBarItem.attributedTitle = [self attributedItemTitleForAccount:account];
        AccountMenuItemView *itemView = [[AccountMenuItemView alloc] initWithFrame:CGRectZero];
        [itemView.accountLabel setStringValue:@(account.profileInfo.alias.c_str())];
        NSString* userNameString = [self nameForAccount: account];
        [itemView.userNameLabel setStringValue:userNameString];
        QByteArray ba = QByteArray::fromStdString(account.profileInfo.avatar);
        QVariant photo = GlobalInstances::pixmapManipulator().personPhoto(ba, nil);
        if(QtMac::toNSImage(qvariant_cast<QPixmap>(photo))) {
            [itemView.accountAvatar setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(photo))];
        } else {
            [itemView.accountAvatar setImage: [NSImage imageNamed:@"default_avatar_overlay.png"]];
        }
        BOOL accountNotRegistered = account.status == lrc::api::account::Status::REGISTERED ? NO : YES;
        [itemView.accountStatus setHidden:accountNotRegistered];
        switch (account.profileInfo.type) {
            case lrc::api::profile::Type::SIP:
                [itemView.accountTypeLabel setStringValue:@"SIP"];
                break;
            case lrc::api::profile::Type::RING:
                [itemView.accountTypeLabel setStringValue:@"RING"];
                break;
            default:
                break;
        }

        bool isAccountAlone = accList.size() == 1;

        [[accountSelectionButton cell] setArrowPosition: (isAccountAlone)?NSPopUpNoArrow:NSPopUpArrowAtBottom];
        [accountSelectionButton setEnabled:!isAccountAlone];

        [itemView.createNewAccount setHidden:YES];
        [itemView.createNewAccountImage setHidden:YES];
        [menuBarItem setView:itemView];
        [accountsMenu addItem:menuBarItem];
        [accountsMenu addItem:[NSMenuItem separatorItem]];
    }

    NSMenuItem* menuBarItem = [[NSMenuItem alloc]
                               initWithTitle:@""
                               action:nil
                               keyEquivalent:@""];
    AccountMenuItemView *itemView = [[AccountMenuItemView alloc] initWithFrame:CGRectZero];
    [itemView.accountAvatar setHidden:YES];
    [itemView.accountStatus setHidden:YES];
    [itemView.accountTypeLabel setHidden:YES];
    [itemView.userNameLabel setHidden:YES];
    [itemView.accountLabel setHidden:YES];
    [itemView.createNewAccount setAction:@selector(createNewAccount:)];
    [itemView.createNewAccount setTarget:self];
    [menuBarItem setView: itemView];
    [accountsMenu addItem: menuBarItem];
    [[accountSelectionButton itemAtIndex:[accountsMenu numberOfItems] -1] setEnabled:NO];
}

- (void)createNewAccount:(id)sender {
    [delegate createNewAccount];
}

-(void) updatePhoto
{
    @try {
        auto& account = [self selectedAccount];
        if(account.profileInfo.type == lrc::api::profile::Type::INVALID)
            return;

        QByteArray ba = QByteArray::fromStdString(account.profileInfo.avatar);

        QVariant photo = GlobalInstances::pixmapManipulator().personPhoto(ba, nil);
        [profileImage setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(photo))];
    }
    @catch (NSException *ex) {
        NSLog(@"Caught exception %@: %@", [ex name], [ex reason]);
    }
}

-(NSString*) nameForAccount:(const lrc::api::account::Info&) account {
    return bestIDForAccount(account);
}

-(NSString*) itemTitleForAccount:(const lrc::api::account::Info&) account {
    NSString* alias = bestNameForAccount(account);
    NSString* userNameString = [self nameForAccount: account];
    if(![alias isEqualToString:userNameString]) {
        alias = [NSString stringWithFormat: @"%@\n", alias];
    }
    return [alias stringByAppendingString:userNameString];
}

- (NSAttributedString*) attributedItemTitleForAccount:(const lrc::api::account::Info&) account {
    NSString* alias = bestNameForAccount(account);
    NSString* userNameString = [self nameForAccount: account];
     if(![alias isEqualToString:userNameString]) {
        alias = [NSString stringWithFormat: @"%@\n", alias];
    }
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
    [self updatePhoto];
}

-(void) setPopUpButtonSelection {
    if(accountsMenu.itemArray.count == 0) {
        [self.view setHidden:YES];
        return;
    }
    [self.view setHidden:NO];
    @try {
        auto& account = [self selectedAccount];
        if(account.profileInfo.type == lrc::api::profile::Type::INVALID){
            return;
        }
        [accountSelectionButton selectItemWithTitle:[self itemTitleForAccount:account]];
    }
    @catch (NSException *ex) {
        NSLog(@"Caught exception %@: %@", [ex name], [ex reason]);
    }
}

#pragma mark - NSPopUpButton item selection

- (IBAction)itemChanged:(id)sender {
    NSInteger row = [(NSPopUpButton *)sender indexOfSelectedItem] / 2;
    auto accList = accMdl_->getAccountList();
    if (row >= accList.size())
        return;

    auto& account = accMdl_->getAccountInfo(accList[row]);
    [accountSelectionManager_ setSavedAccount:account];
    [delegate selectAccount:account];
    [self updatePhoto];
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

-(void) enable {
    [accountSelectionButton setEnabled:YES];
}
-(void) disable {
    [accountSelectionButton setEnabled:NO];
}

@end
