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

#import <map>

#import <Foundation/Foundation.h>
#import "NSString+Extensions.h"
#import "views/NSColor+RingTheme.h"


// new lrc
#import <api/conversation.h>
#import <api/conversationmodel.h>
#import <api/account.h>
#import <api/contactmodel.h>
#import <api/contact.h>

// old lrc
#import <QSortFilterProxyModel>
#import <accountmodel.h>

static inline NSString* bestIDForConversation(const lrc::api::conversation::Info& conv, const lrc::api::ConversationModel& model)
{
    try {
        auto contact = model.owner.contactModel->getContact(conv.participants[0]);
        if (!contact.registeredName.empty()) {
            contact.registeredName.erase(std::remove(contact.registeredName.begin(), contact.registeredName.end(), '\n'), contact.registeredName.end());
            contact.registeredName.erase(std::remove(contact.registeredName.begin(), contact.registeredName.end(), '\r'), contact.registeredName.end());
            return [@(contact.registeredName.c_str()) removeEmptyLinesAtBorders];
        }
        else {
            return [@(contact.profileInfo.uri.c_str()) removeEmptyLinesAtBorders];
        }
    } catch (std::out_of_range& e) {
        NSLog(@"bestIDForConversation: getContact - out of range");
    }
}

static inline NSString* bestIDForAccount(const lrc::api::account::Info& account)
{
    if (!account.registeredName.empty()) {
        return [@(account.registeredName.c_str()) removeEmptyLinesAtBorders];
    }
    return [@(account.profileInfo.uri.c_str()) removeEmptyLinesAtBorders];
}

static inline NSString* bestNameForAccount(const lrc::api::account::Info& account)
{
    if (account.profileInfo.alias.empty()) {
        return bestIDForAccount(account);
    }
    return @(account.profileInfo.alias.c_str());
}

static inline NSString* bestIDForContact(const lrc::api::contact::Info& contact)
{
    if (!contact.registeredName.empty()) {
        return [@(contact.registeredName.c_str()) removeEmptyLinesAtBorders];
    }
    return [@(contact.profileInfo.uri.c_str()) removeEmptyLinesAtBorders];
}

static inline NSString* bestNameForContact(const lrc::api::contact::Info& contact)
{
    if (contact.profileInfo.alias.empty()) {
        return bestIDForContact(contact);
    }
    return @(contact.profileInfo.alias.c_str());
}

static inline NSString* bestNameForConversation(const lrc::api::conversation::Info& conv, const lrc::api::ConversationModel& model)
{
    try {
        auto contact = model.owner.contactModel->getContact(conv.participants[0]);
        if (contact.profileInfo.alias.empty()) {
            return bestIDForConversation(conv, model);
        }
        auto alias = contact.profileInfo.alias;
        alias.erase(std::remove(alias.begin(), alias.end(), '\n'), alias.end());
        alias.erase(std::remove(alias.begin(), alias.end(), '\r'), alias.end());
        if(alias.length() == 0) {
            return bestIDForConversation(conv, model);
        }
        return @(alias.c_str());
    } catch (std::out_of_range& e) {
        NSLog(@"bestNameForConversation: getContact - out of range");
    }
}

static inline lrc::api::profile::Type profileType(const lrc::api::conversation::Info& conv, const lrc::api::ConversationModel& model)
{
    @try {
        auto contact = model.owner.contactModel->getContact(conv.participants[0]);
        return contact.profileInfo.type;
    }
    @catch (NSException *exception) {
        lrc::api::profile::Type::INVALID;
    }
}

/**
 * This function return an iterator pointing to a Conversation::Info in ConversationModel given its uid. If not found
 * the iterator is invalid thus it needs to be checked by caller.
 * @param uid UID of conversation being searched
 * @param model ConversationModel in which to do the lookup
 * @return iterator pointing to corresponding Conversation if any. Points to past-the-end element otherwise.
 */
static inline lrc::api::ConversationModel::ConversationQueue::const_iterator getConversationFromUid(const std::string& uid, const lrc::api::ConversationModel& model) {
    return std::find_if(model.allFilteredConversations().begin(), model.allFilteredConversations().end(),
                        [&] (const lrc::api::conversation::Info& conv) {
                            return uid == conv.uid;
                        });
}

/**
 * This function return an iterator pointing to a Conversation::Info in ConversationModel given its participant uri. Will not work for group chat.
 * @param uri URI of participant
 * @param model ConversationModel in which to do the lookup
 * @return iterator pointing to corresponding Conversation if any. Points to past-the-end element otherwise.
 */
static inline lrc::api::ConversationModel::ConversationQueue::const_iterator getConversationFromURI(const std::string& uri, const lrc::api::ConversationModel& model) {
    return std::find_if(model.allFilteredConversations().begin(), model.allFilteredConversations().end(),
                        [&] (const lrc::api::conversation::Info& conv) {
                            return uri == conv.participants[0];
                        });
}

static inline bool isUrlAccessibleFromSandbox(NSURL* url)
{
    NSFileManager* fileManager = [[NSFileManager alloc] init];
    NSArray* urlPathsMusic = [fileManager URLsForDirectory:NSMusicDirectory
                                                 inDomains:NSUserDomainMask];
    NSArray* urlPathsPictures = [fileManager URLsForDirectory:NSPicturesDirectory
                                                    inDomains:NSUserDomainMask];
    NSArray* urlPathsDownloads = [fileManager URLsForDirectory:NSDownloadsDirectory
                                                     inDomains:NSUserDomainMask];
    NSArray* urlPathsMovies = [fileManager URLsForDirectory:NSMoviesDirectory
                                                  inDomains:NSUserDomainMask];
    NSArray* availablePaths = [[[urlPathsMusic arrayByAddingObjectsFromArray: urlPathsPictures] arrayByAddingObjectsFromArray: urlPathsDownloads] arrayByAddingObjectsFromArray: urlPathsMovies];
    if([availablePaths containsObject:url]) {
        return YES;
    }
    for (NSURL* availableUrl in availablePaths) {
        if ([url.path containsString:availableUrl.path]) {
            return YES;
        }
    }
    return NO;
}

static inline bool appSandboxed()
{
    NSString* bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSString* url = [[NSURL fileURLWithPath:NSHomeDirectory()] path];
    NSString* appPath = [@"Library/Containers/" stringByAppendingString:bundleID];
    if ([url containsString: appPath]) {
        return YES;
    }
    return NO;
}

static inline NSColor* colorForAccountStatus(const lrc::api::account::Status status)
{
    NSColor *accountStatusColor = [NSColor unregisteredColor];
    switch (status) {
        case  lrc::api::account::Status::REGISTERED:
            accountStatusColor = [NSColor presenceColor];
            break;
        case  lrc::api::account::Status::TRYING:
            accountStatusColor = [NSColor orangeColor];
            break;
        default:
            break;
    }
    return accountStatusColor;
}
