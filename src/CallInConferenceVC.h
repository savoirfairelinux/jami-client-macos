/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
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

#import <Cocoa/Cocoa.h>
#include <string>

namespace lrc {
    namespace api {
        namespace account {
            struct Info;
        }
    }
}

@protocol CallInConferenceVCDelegate
-(void)removePreviewForContactUri:(std::string)uri forCall:(std::string) callId;
@end

@interface CallInConferenceVC: NSViewController

-(id) initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
               callId:(const std::string)callId
          accountInfo:(const lrc::api::account::Info *)accInfo;
@property (retain, nonatomic) id <CallInConferenceVCDelegate> delegate;
@property std::string initialCallId;

@end

