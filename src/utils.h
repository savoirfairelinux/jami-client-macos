/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
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

//Qt
#import <QtCore/QDir>
#import <qapplication.h>

static inline NSString* bestIDForConversation(const lrc::api::conversation::Info& conv, const lrc::api::ConversationModel& model)
{
    try {
        auto contact = model.owner.contactModel->getContact(conv.participants[0]);
        auto name = contact.registeredName.trimmed().replace("\r","").replace("\n","");
        if (!name.isEmpty()) {
            return [name.toNSString() removeEmptyLinesAtBorders];
        }
        else {
            return [contact.profileInfo.uri.trimmed().replace("\r","").replace("\n","").toNSString() removeEmptyLinesAtBorders];
        }
    } catch (std::out_of_range& e) {
        NSLog(@"bestIDForConversation: getContact - out of range");
        return @"";
    }
}

static inline NSString* bestIDForAccount(const lrc::api::account::Info& account)
{
    auto name = account.registeredName.trimmed().replace("\r","").replace("\n","");
    if (!name.isEmpty()) {
        return [name.toNSString() removeEmptyLinesAtBorders];
    }
    return [account.profileInfo.uri.trimmed().replace("\r","").replace("\n","").toNSString() removeEmptyLinesAtBorders];
}

static inline NSString* bestNameForAccount(const lrc::api::account::Info& account)
{
    if (account.profileInfo.alias.isEmpty()) {
        return bestIDForAccount(account);
    }
    return account.profileInfo.alias.toNSString();
}

static inline NSString* bestIDForContact(const lrc::api::contact::Info& contact)
{
    auto name = contact.registeredName.trimmed().replace("\r","").replace("\n","");
    if (!name.isEmpty()) {
        return [name.toNSString() removeEmptyLinesAtBorders];
    }
    return [contact.profileInfo.uri.trimmed().replace("\r","").replace("\n","").toNSString() removeEmptyLinesAtBorders];
}

static inline NSString* bestNameForContact(const lrc::api::contact::Info& contact)
{
    if (contact.profileInfo.alias.isEmpty()) {
        return bestIDForContact(contact);
    }
    return contact.profileInfo.alias.toNSString();
}

static inline NSString* bestNameForConversation(const lrc::api::conversation::Info& conv, const lrc::api::ConversationModel& model)
{
    try {
        qDebug() << "bestNameForConversation" << conv.participants[0];
        auto contact = model.owner.contactModel->getContact(conv.participants[0]);
        if (contact.profileInfo.alias.isEmpty()) {
            return bestIDForConversation(conv, model);
        }
        auto alias = contact.profileInfo.alias;
        if(alias.length() == 0) {
            return bestIDForConversation(conv, model);
        }
        return [alias.toNSString() removeEmptyLinesAtBorders];
    } catch (std::out_of_range& e) {
        NSLog(@"bestNameForConversation: getContact - out of range");
        return @"";
    }
}

static inline NSString* defaultRingtonePath() {
    QDir ringtonesDir(QCoreApplication::applicationDirPath());
    ringtonesDir.cdUp();
    ringtonesDir.cd("Resources/ringtones/");
    return [ringtonesDir.path().toNSString() stringByAppendingString:@"/default.opus"];
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
 * @param includeSearchResult include search result
 * @return iterator pointing to corresponding Conversation if any. Points to past-the-end element otherwise.
 */
static inline lrc::api::ConversationModel::ConversationQueue::const_iterator getConversationFromUid(const QString& uid, const lrc::api::ConversationModel& model, bool includeSearchResult) {
     NSLog(@"***get conv from uuid%@", uid.toNSString());
    if(!includeSearchResult) {
        return std::find_if(model.allFilteredConversations().begin(), model.allFilteredConversations().end(),
        [&] (const lrc::api::conversation::Info& conv) {
            return uid == conv.uid;
        });
    } else {
        if (std::find_if(model.allFilteredConversations().begin(), model.allFilteredConversations().end(),
        [&] (const lrc::api::conversation::Info& conv) {
            return uid == conv.uid;
        }) != model.allFilteredConversations().end()) {
            NSLog(@"***conv id in contact lis, %@", uid.toNSString());
                           qDebug() << "****conv id in contact list includeSearchResult" << uid;
            return std::find_if(model.allFilteredConversations().begin(), model.allFilteredConversations().end(),
                   [&] (const lrc::api::conversation::Info& conv) {
                NSLog(@"***conv id in contact lis, %@", conv.uid.toNSString());
                qDebug() << "****conv id in contact list includeSearchResult" << conv.uid;
                       return uid == conv.uid;
                   });
        } else {
//            for (auto result in model.getAllSearchResults()) {
//                NSLog(@"***one of conv id in search lis, %@", result.uid.toNSString());
//
//            }

            for (unsigned int i = 0; i < model.getAllSearchResults().size(); ++i) {
                NSLog(@"***one of conv id in search lis, %@", model.getAllSearchResults().at(i).uid.toNSString());
                  // if (model.getAllSearchResults().at(i).uid == uid) return i;
            }
            NSLog(@"***conv id in search lis, %@", uid.toNSString());
                                      qDebug() << "****conv id in search list includeSearchResult" << uid;
            return std::find_if(model.getAllSearchResults().begin(), model.getAllSearchResults().end(),
            [&] (const lrc::api::conversation::Info& conv) {
                NSLog(@"***conv id in search lis, %@", conv.uid.toNSString());
                qDebug() << "****conv id in search list includeSearchResult" << conv.uid;
                return uid == conv.uid;
            });
        }

        qDebug() << "****** result not find";
        NSLog(@"***conv id in search lis, %@", uid.toNSString());
    }
//    auto result = std::find_if(model.allFilteredConversations().begin(), model.allFilteredConversations().end(),
//                        [&] (const lrc::api::conversation::Info& conv) {
//                            return uid == conv.uid;
//                        });
//    if (!includeSearchResult || (result != model.allFilteredConversations().end())) {
//        return result;
//    }
//    return std::find_if(model.getAllSearchResults().begin(), model.getAllSearchResults().end(),
//    [&] (const lrc::api::conversation::Info& conv) {
//        return uid == conv.uid;
//    });
}

static inline int getindexOfConversationFromUid(const QString& uid, const lrc::api::ConversationModel& model, bool includeSearchResult) {
    for (unsigned int i = 0; i < model.allFilteredConversations().size(); ++i) {
           if (model.allFilteredConversations().at(i).uid == uid) return i;
    }
    if (!includeSearchResult) {
        return -1;
    }
    for (unsigned int i = 0; i < model.getAllSearchResults().size(); ++i) {
           if (model.getAllSearchResults().at(i).uid == uid) return i;
    }
    return -1;
}

/**
 * This function true if conversation exists
 * the iterator is invalid thus it needs to be checked by caller.
 * @param conversation iterator pointing to a Conversation::Info in ConversationModel
 * @param model ConversationModel in which to do the lookup
 * @param includeSearchResult include search result
 * @return iterator pointing to corresponding Conversation if any. Points to past-the-end element otherwise.
 */
static inline bool conversationExists(lrc::api::ConversationModel::ConversationQueue::const_iterator conversation, const lrc::api::ConversationModel& model, bool includeSearchResult) {
    if (includeSearchResult){
        if (conversation != model.allFilteredConversations().end()) {
            return true;
        }
        if (conversation != model.getAllSearchResults().end()) {
            return true;
        }
    }
    if (conversation != model.allFilteredConversations().end()) {
               return true;
           }
    return false;
   // return includeSearchResult ? (conversation != model.allFilteredConversations().end() || conversation != model.getAllSearchResults().end()) : conversation != model.allFilteredConversations().end();
}

/**
 * This function return an iterator pointing to a Conversation::Info in ConversationModel given its participant uri. Will not work for group chat.
 * @param uri URI of participant
 * @param model ConversationModel in which to do the lookup
 * @return iterator pointing to corresponding Conversation if any. Points to past-the-end element otherwise.
 */
static inline lrc::api::ConversationModel::ConversationQueue::const_iterator getConversationFromURI(const QString& uri, const lrc::api::ConversationModel& model) {
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
