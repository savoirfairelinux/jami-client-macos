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

#import <Cocoa/Cocoa.h>
#import <string>

namespace lrc {
    namespace api {
        class NewAccountModel;

        namespace account {
            struct Info;
        }
    }
}

@protocol ChooseAccountDelegate <NSObject>
- (void) selectAccount:(const lrc::api::account::Info&)accInfo currentRemoved:(BOOL) removed;
- (void) allAccountsDeleted;
- (void) createNewAccount;
@end

@interface ChooseAccountVC : NSViewController

@property (retain, nonatomic) id <ChooseAccountDelegate> delegate;

@property (readonly) const lrc::api::account::Info& selectedAccount;

-(void) enable;
-(void) disable;
-(void) selectAccountWithID:(const std::string) accountID;
-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil model:(lrc::api::NewAccountModel*) accMdl delegate:(id <ChooseAccountDelegate> )mainWindow;

@end
