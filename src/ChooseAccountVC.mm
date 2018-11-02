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
#import "views/NSColor+RingTheme.h"

@interface NSMenu ()
- (void) _setHasPadding: (BOOL) pad onEdge: (int) whatEdge;
@end

@interface ChooseAccountVC () <NSMenuDelegate>

@end

@implementation ChooseAccountVC {

    __unsafe_unretained IBOutlet NSImageView*   profileImage;
    __unsafe_unretained IBOutlet NSTextField*    accountStatus;
    __unsafe_unretained IBOutlet NSPopUpButton* accountSelectionButton;
    lrc::api::NewAccountModel* accMdl_;
    AccountSelectionManager* accountSelectionManager_;
}
Boolean menuIsOpen;
Boolean menuNeedsUpdate;
NSMenu* accountsMenu;
NSMenuItem* selectedMenuItem;
NSMutableDictionary* menuItemsTags;

//-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil model:(lrc::api::NewAccountModel*) accMdl delegate:(id <ChooseAccountDelegate> )mainWindow
//{
//    accMdl_ = accMdl;
//    accountSelectionManager_ = [[AccountSelectionManager alloc] initWithAccountModel:accMdl_];
//    self.delegate = mainWindow;
//    return [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
//}

-(void) updateWithDelegate:(id <ChooseAccountDelegate> )mainWindow andModel:(lrc::api::NewAccountModel*) accMdl {
    accMdl_ = accMdl;
        accountSelectionManager_ = [[AccountSelectionManager alloc] initWithAccountModel:accMdl_];
        self.delegate = mainWindow;
    [self initView];

}

- (void)initView
{
    [profileImage setWantsLayer: YES];
    profileImage.layer.cornerRadius = profileImage.frame.size.width / 2;
    profileImage.layer.masksToBounds = YES;
    profileImage.layer.backgroundColor = [[NSColor ringGreyLight] CGColor];

    accountsMenu = [[NSMenu alloc] initWithTitle:@""];
    if ([accountsMenu respondsToSelector: @selector(_setHasPadding:onEdge:)])
    {
        [accountsMenu _setHasPadding: NO onEdge: 1];
        [accountsMenu _setHasPadding: NO onEdge: 3];
    }
    [accountsMenu setDelegate:self];
    accountSelectionButton.menu = accountsMenu;
    [accountSelectionButton setAutoenablesItems:NO];
    menuItemsTags = [[NSMutableDictionary alloc] init];
    [self update];


    QObject::connect(accMdl_,
                     &lrc::api::NewAccountModel::accountAdded,
                     [self] (const std::string& accountID) {
                         [self update];
                         @try {
                             auto& account = [self selectedAccount];
                             [self.delegate selectAccount:account currentRemoved: NO];
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
                             [self.delegate selectAccount:account currentRemoved: YES];
                         }
                         @catch (NSException * e) {
                             [self.delegate allAccountsDeleted];
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
                         [self updateMenuItemForAccount:accountID];
                         if([self selectedAccount].id == accountID) {
                             // update account state
                             [self updatePhoto];
                             [self setPopUpButtonSelection];
                         }
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
            [accountSelectionManager_ setSavedAccount:fallbackAccount];
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

-(void) updateMenuItemForAccount: (const std::string&) accountID {
    NSMenuItem *item  =[accountsMenu itemWithTag:[menuItemsTags[@(accountID.c_str())] intValue]];
    if(!item) {return;}
    AccountMenuItemView *itemView =item.view;
    if(!itemView) {return;}
    [self configureView:itemView forAccount:accountID forMenuItem: item];
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

        AccountMenuItemView *itemView = [[AccountMenuItemView alloc] initWithFrame:CGRectZero];
        [self configureView:itemView forAccount:accId forMenuItem: menuBarItem];
        int itemTag = arc4random_uniform(1000);
        menuItemsTags[@(accId.c_str())] = [NSNumber numberWithInt: itemTag];
        [menuBarItem setTag:itemTag];
        [menuBarItem setView:itemView];
        [accountsMenu addItem:menuBarItem];
    }

    // create "add a new account" menu item
    NSMenuItem* menuBarItem = [[NSMenuItem alloc]
                               initWithTitle:@"Add Account"
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
    [profileImage setHidden:accList.empty()];
    [accountStatus setHidden:accList.empty()];
}

-(void) configureView: (AccountMenuItemView *) itemView forAccount:(const std::string&) accountId forMenuItem:(NSMenuItem *) item {
    auto& account = accMdl_->getAccountInfo(accountId);
    item.attributedTitle = [self attributedItemTitleForAccount:account];
    [itemView.accountLabel setStringValue:@(account.profileInfo.alias.c_str())];
    NSString* userNameString = [self nameForAccount: account];
    [itemView.userNameLabel setStringValue:userNameString];
    NSData *imageData = [[NSData alloc] initWithBase64EncodedString:@(account.profileInfo.avatar.c_str()) options:NSDataBase64DecodingIgnoreUnknownCharacters];
    NSImage *image = [[NSImage alloc] initWithData:imageData];
    if(image) {
        [itemView.accountAvatar setImage: image];
    } else {
        [itemView.accountAvatar setImage: [NSImage imageNamed:@"default_avatar_overlay.png"]];
    }
    [itemView.accountStatus setHidden:!account.enabled];
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
    [itemView.createNewAccount setHidden:YES];
    [itemView.createNewAccountImage setHidden:YES];
}


- (void)createNewAccount:(id)sender {
    [accountSelectionButton.menu cancelTrackingWithoutAnimation];
    [self.delegate createNewAccount];
}

-(void) updatePhoto
{
    @try {
        auto& account = [self selectedAccount];
        if(account.profileInfo.type == lrc::api::profile::Type::INVALID)
            return;
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:@(account.profileInfo.avatar.c_str()) options:NSDataBase64DecodingIgnoreUnknownCharacters];
        NSImage *image = [[NSImage alloc] initWithData:imageData];
        if(image) {
            [profileImage setImage: image];
        } else {
            [profileImage setImage: [NSImage imageNamed:@"default_avatar_overlay.png"]];
        }
        [accountStatus setHidden:!account.enabled];
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
    if([alias isEqualToString:userNameString] || [userNameString length] == 0) {
        return alias;
    }
    alias = [NSString stringWithFormat: @"%@\n", alias];
    return [alias stringByAppendingString:userNameString];
}

- (NSAttributedString*) attributedItemTitleForAccount:(const lrc::api::account::Info&) account {
    NSString* alias = bestNameForAccount(account);
    NSString* userNameString = [self nameForAccount: account];
    NSFont *fontAlias = [NSFont fontWithName:@"Helvetica Neue" size:16.0];
    NSFont *fontUserName = [NSFont fontWithName:@"Helvetica Neue Light" size:13.0];
    NSColor *colorAlias = [NSColor labelColor];
    NSColor *colorAUserName = [NSColor secondaryLabelColor];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    paragraphStyle.lineSpacing = 3;
    NSDictionary *aliasAttrs = [NSDictionary dictionaryWithObjectsAndKeys:fontAlias,NSFontAttributeName,
                                colorAlias,NSForegroundColorAttributeName,
                                paragraphStyle,NSParagraphStyleAttributeName, nil];
    NSDictionary *userNameAttrs = [NSDictionary dictionaryWithObjectsAndKeys:fontUserName,NSFontAttributeName,
                                   colorAUserName,NSForegroundColorAttributeName,
                                   paragraphStyle,NSParagraphStyleAttributeName, nil];

    if([alias isEqualToString:userNameString] || [userNameString length] == 0) {
        paragraphStyle.paragraphSpacingBefore = 20;
        aliasAttrs = [NSDictionary dictionaryWithObjectsAndKeys:fontAlias,NSFontAttributeName,
                      colorAlias,NSForegroundColorAttributeName,
                      paragraphStyle,NSParagraphStyleAttributeName, nil];
        return [[NSAttributedString alloc] initWithString:alias attributes:aliasAttrs];
    }
    alias = [NSString stringWithFormat: @"%@\n", alias];
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
        [accountSelectionButton selectItemWithTag:[menuItemsTags[@(account.id.c_str())] intValue]];
    }
    @catch (NSException *ex) {
        NSLog(@"Caught exception %@: %@", [ex name], [ex reason]);
    }
}

#pragma mark - NSPopUpButton item selection

- (IBAction)itemChanged:(id)sender {
    NSInteger row = [(NSPopUpButton *)sender indexOfSelectedItem];
    auto accList = accMdl_->getAccountList();
    if (row >= accList.size())
        return;

    auto& account = accMdl_->getAccountInfo(accList[row]);
    [accountSelectionManager_ setSavedAccount:account];
    [self.delegate selectAccount:account currentRemoved: NO];
    [self updatePhoto];
}

- (IBAction)openMenu:(id)sender {
    [accountSelectionButton performClick:nil];
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
