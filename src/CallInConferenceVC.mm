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

#import "CallInConferenceVC.h"
#import "views/IconButton.h"
#import "NSString+Extensions.h"

///LRC
#import <api/newcallmodel.h>
#import <api/account.h>
#import <api/contactmodel.h>
#import <api/contact.h>

@interface CallInConferenceVC () {
    std::string callUId;
    const lrc::api::account::Info *accountInfo;
}

@property (unsafe_unretained) IBOutlet NSTextField* contactNameLabel;
@property (unsafe_unretained) IBOutlet NSTextField* callStateLabel;
@property (unsafe_unretained) IBOutlet IconButton* cancelCallButton;
@property QMetaObject::Connection callStateChanged;

@end

@implementation CallInConferenceVC
@synthesize cancelCallButton,callStateLabel,contactNameLabel;

-(id) initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
               callId:(const std::string)callId
          accountInfo:(const lrc::api::account::Info *)accInfo {
    if (self =  [self initWithNibName: nibNameOrNil bundle:nibBundleOrNil])
    {
        callUId = callId;
        accountInfo = accInfo;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    auto* callModel = accountInfo->callModel.get();
    auto currentCall = callModel->getCall(callUId);
    auto uri = currentCall.peerUri;
    auto contact = accountInfo->contactModel->getContact(uri);
    NSString *name = @(contact.profileInfo.alias.c_str());
    name = [name removeEmptyLinesAtBorders];
    if (name.length == 0) {
        name = @(contact.registeredName.c_str());
    }
    name = [name removeEmptyLinesAtBorders];
    if (name.length == 0) {
        name = @(contact.profileInfo.uri.c_str());
    }
    self.contactNameLabel.stringValue = [name removeEmptyLinesAtBorders];
    QObject::disconnect(self.callStateChanged);
    self.callStateChanged = QObject::connect(callModel,
                                                &lrc::api::NewCallModel::callStatusChanged,
                                                [self](const std::string callId) {
                                                    if (callId == callUId) {
                                                        [self updateCall];
                                                    }
                                                });
}

-(void) updateCall
{
    if (accountInfo == nil)
        return;

    auto* callModel = accountInfo->callModel.get();
    if (not callModel->hasCall(callUId)) {
        return;
    }

    auto currentCall = callModel->getCall(callUId);
    using Status = lrc::api::call::Status;
    callStateLabel.stringValue = @(to_string(currentCall.status).c_str());
    switch (currentCall.status) {
        case Status::IN_PROGRESS:
        case Status::ENDED:
        case Status::TERMINATING:
        case Status::PEER_BUSY:
        case Status::TIMEOUT:
        case Status::INVALID: {
            QObject::disconnect(self.callStateChanged);
            [self.delegate removePreviewForContactUri: currentCall.peerUri forCall: self.initiatorCallId];
            break;
        }
    }
}

- (void)awakeFromNib
{
    contactNameLabel.textColor = [NSColor textColor];
    callStateLabel.textColor = [NSColor textColor];
}

- (IBAction)hangUp:(id)sender {
    if (accountInfo == nil)
        return;

    auto* callModel = accountInfo->callModel.get();
    callModel->hangUp(callUId);
}

@end
