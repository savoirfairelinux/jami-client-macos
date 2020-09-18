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
#include <qstring.h>

namespace lrc {
    namespace api {
        class ConversationModel;

        namespace conversation {
            struct Info;
        }
    }
}

@interface SmartViewVC : NSViewController <NSTextFieldDelegate>

@property (unsafe_unretained) IBOutlet NSTabView* tabbar;

- (BOOL)setConversationModel:(lrc::api::ConversationModel *)conversationModel;

- (void)startCallForRow:(id)sender;

/**
 * This method is meant to be used by RingWindowController to set selected conversation in case
 * a selection is triggered not by user but by LRC signal. If conversation is already selected, this method
 * returns immediatly without changing any state.
 * @param conv selected conversation
 * @param model model responsible for conversation
 */
-(void)selectConversation:(const lrc::api::conversation::Info&)conv model:(lrc::api::ConversationModel*)model;

/**
 * Deselect any selected conversation
 */
-(void)deselect;

/**
 * Change list selection to Conversation
 */
-(void)selectConversationList;

/**
 * Change list selection to Pending
 */
-(void)selectPendingList;
/**
 * clear conversation when account list is empty
 */
-(void) clearConversationModel;

-(void) reloadConversationWithUid:(NSString *)uid;
-(void) reloadConversationWithURI:(NSString *)uri;
-(QString)getSelectedUID;

@end
