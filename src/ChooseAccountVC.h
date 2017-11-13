/*
 *  Copyright (C) 2015-2017 Savoir-faire Linux Inc.
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *          Olivier Soldano <olivier.soldano@savoirfairelinux.com>
 *          Anthony Léonard <anthony.leonard@savoirfairelinux.com>
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

namespace lrc {
    namespace api {
        class NewAccountModel;

        namespace account {
            struct Info;
        }
    }
}

@interface ChooseAccountVC : NSViewController

@property (readonly) const lrc::api::account::Info& selectedAccount;

-(void) enable;
-(void) disable;
-(id) initWithNibName:(NSNibName)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil model:(const lrc::api::NewAccountModel*) accMdl;

@end
