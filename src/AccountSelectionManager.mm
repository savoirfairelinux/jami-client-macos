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

// LRC
#import <accountmodel.h>
#import <account.h>
#import <AvailableAccountModel.h>
#import <QItemSelectionModel.h>

#import "AccountSelectionManager.h"

@implementation AccountSelectionManager

NSString* const savedUserAccountKey = @"savedUserSelectedAccountKey";

- (void) saveAccountWithIndex:( int )ind {
    QModelIndex index = AvailableAccountModel::instance().selectionModel()->model()->index(ind, 0);
    if(!index.isValid()) {
        return;
    }
    AvailableAccountModel::instance().selectionModel()->setCurrentIndex(index, QItemSelectionModel::ClearAndSelect);
    QByteArray accountID = index.data(static_cast<int>(Account::Role::Id)).toByteArray();
    if (accountID.isEmpty()) {
        return;
    }
    NSString* accountToNSString = QString::QString(accountID).toNSString();
    [[NSUserDefaults standardUserDefaults] setObject:accountToNSString forKey:savedUserAccountKey];
}

- (void) reselectSavedAccount {
    QModelIndex index = [self savedAccountIndex];
    if(index.isValid())
        AvailableAccountModel::instance().selectionModel()->setCurrentIndex(index, QItemSelectionModel::ClearAndSelect);

}
- (Account *) getSavedAccount {
    QModelIndex index = [self savedAccountIndex];
    Account* account = nil;
    if(index.isValid())
        account =  index.data(static_cast<int>(Account::Role::Object)).value<Account*>();
    return account;
}

-(QModelIndex )savedAccountIndex
{
    NSString* savedAccount = [[NSUserDefaults standardUserDefaults] stringForKey:savedUserAccountKey];
    QModelIndex savedIndex = QModelIndex::QModelIndex();
    if(savedAccount && savedAccount.length > 0) {
        const char* secondName = [savedAccount UTF8String];
        QByteArray assountToarray = QByteArray::QByteArray(secondName);
        if (strlen(assountToarray) > 0) {
            if (auto account = AccountModel::instance().getById(assountToarray)) {
                savedIndex = AvailableAccountModel::instance().mapFromSource(account->index());
                if (savedIndex.isValid())
                    return savedIndex;
                // if account is not saved, try first select RING account
                if (auto account = AvailableAccountModel::instance().currentDefaultAccount(URI::SchemeType::RING)) {
                    savedIndex = AvailableAccountModel::instance().mapFromSource(account->index());
                }
                if (savedIndex.isValid())
                    return savedIndex;
                if (auto account = AvailableAccountModel::instance().currentDefaultAccount(URI::SchemeType::SIP)) {
                    savedIndex = AvailableAccountModel::instance().mapFromSource(account->index());

                }
                if (savedIndex.isValid())
                    return savedIndex;
            }
        }
    }

    return savedIndex;
}
@end
