/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
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

#import <Foundation/Foundation.h>
#import <api/conversation.h>
#import <api/conversationmodel.h>
#import <api/account.h>
#import <api/contactmodel.h>
#import <api/contact.h>

static inline NSString* bestIDForConversation(const lrc::api::conversation::Info& conv, const lrc::api::ConversationModel& model)
{
    auto contact = model.owner.contactModel->getContact(conv.participants[0]);
    if (!contact.registeredName.empty())
        return @(contact.registeredName.c_str());
    else
        return @(contact.profileInfo.uri.c_str());
}

static inline NSString* bestNameForConversation(const lrc::api::conversation::Info& conv, const lrc::api::ConversationModel& model)
{
    auto contact = model.owner.contactModel->getContact(conv.participants[0]);
    if (!contact.profileInfo.alias.empty())
        return @(contact.profileInfo.alias.c_str());
    else
        return bestIDForConversation(conv, model);
}
