/*
 *  Copyright (C) 2018-2019 by Savoir-faire Linux Inc.
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
#import <string>

namespace lrc {
    namespace api {
        class AVModel;
        class ConversationModel;
    }
}

@protocol LeaveMessageDelegate

-(void) messageCompleted;

@end

@interface LeaveMessageVC : NSViewController

@property (retain, nonatomic) id <LeaveMessageDelegate> delegate;

-(void)setConversationUID:(const std::string) convUid conversationModel:(lrc::api::ConversationModel*) convModel;
-(void) hide;
-(void) initFrame;
-(void) setAVModel: (const lrc::api::AVModel*) avmodel;

@end

