/*
 *  Copyright (C) 2015-2016 Savoir-faire Linux Inc.
 *  Author: Alexandre Lision <alexandre.lision@savoirfairelinux.com>
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

#import "views/CallView.h"
#import <api/account.h>

#import "ChooseContactVC.h"
#import "CallInConferenceVC.h"

namespace lrc {
    namespace api {
        class AVModel;
    }
}

@protocol CallViewControllerDelegate

-(void) conversationInfoUpdatedFor:(const QString&) conversationID;
-(void) callFinished;

@end

@interface CurrentCallVC : NSViewController <NSSplitViewDelegate, CallDelegate, ChooseContactVCDelegate, CallInConferenceVCDelegate> {

}
@property (retain, nonatomic) id <CallViewControllerDelegate> delegate;
-(void) initFrame;
-(void) cleanUp;
-(void) showWithAnimation:(BOOL)animate;
-(void) hideWithAnimation:(BOOL)animate;
-(void) setCurrentCall:(const QString&)callUid
          conversation:(const QString&)convUid
               account:(const lrc::api::account::Info*)account
               avModel:(lrc::api::AVModel *)avModel;
@end
