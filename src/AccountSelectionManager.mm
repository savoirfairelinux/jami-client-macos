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

// LRC
#import <api/newaccountmodel.h>
#import <api/account.h>

#import "AccountSelectionManager.h"

@implementation AccountSelectionManager {

    const lrc::api::NewAccountModel* accMdl_;

}

NSString* const savedUserAccountKey = @"savedUserSelectedAccountKey";

- (id) initWithAccountModel:(const lrc::api::NewAccountModel*) accMdl {
    accMdl_ = accMdl;
    return [self init];
}

- (void) saveAccountWithId:(NSString*)accId
{
    [[NSUserDefaults standardUserDefaults] setObject:accId forKey:savedUserAccountKey];
}

- (NSString*) getSavedAccountId
{
    return [[NSUserDefaults standardUserDefaults] stringForKey:savedUserAccountKey];
}

- (const lrc::api::account::Info&) savedAccount
{
    NSString* savedAccountId = [self getSavedAccountId];
    if (savedAccountId == nil) {
        auto accId = accMdl_->getAccountList().front();
        [self saveAccountWithId:@(accId.c_str())];
        return accMdl_->getAccountInfo(accId);
    } else
        return accMdl_->getAccountInfo(std::string([savedAccountId UTF8String]));
}

- (void) setSavedAccount:(const lrc::api::account::Info&) acc
{
    if (acc.profileInfo.type == lrc::api::profile::Type::INVALID)
        return;

    [self saveAccountWithId:@(acc.id.c_str())];
}

@end
