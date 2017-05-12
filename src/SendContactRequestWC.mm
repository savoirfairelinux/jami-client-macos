/*
 *  Copyright (C) 2015-2017 Savoir-faire Linux Inc.
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

//Qt
#import <QSize>
#import <QtMacExtras/qmacfunctions.h>
#import <QPixmap>

//LRC
#import <account.h>
#import <person.h>
#import <contactmethod.h>
#import <availableAccountModel.h>
#import <contactRequest.h>
#import <globalinstances.h>
#import <recentmodel.h>

#import "Constants.h"
#import "views/NSImage+Extensions.h"
#import "delegates/ImageManipulationDelegate.h"
#import "SendContactRequestWC.h"

@interface SendContactRequestWC () {

    __unsafe_unretained IBOutlet NSTextField* userName;
    __unsafe_unretained IBOutlet NSTextField* ringID;
    __unsafe_unretained IBOutlet NSTextField* infoLabel;
    __unsafe_unretained IBOutlet NSImageView* photoView;

}
@end

@implementation SendContactRequestWC

NSString* const sendingErrorMsg = @"An error happened, contact request has not been sent";
NSString* const findContactErrorMsg = @"Could not find contact to send request";
NSString* const sendRequestSuccessMsg = @"Contact request has been sent successfully";

- (void)windowDidLoad {
    [super windowDidLoad];
    self.hideButtons = false;
    if(!self.contactMethod) {
        [self findContactError];
        return;
    }
    auto photo = GlobalInstances::pixmapManipulator().callPhoto(self.contactMethod, {100,100});
    [photoView setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(photo))];
    [userName setStringValue:self.contactMethod->bestName().toNSString()];
    [ringID setStringValue:self.contactMethod->bestId().toNSString()];
}

-(IBAction) sendContactRequest:(id)sender
{
    if(self.contactMethod->account() == nullptr) {
        self.contactMethod->setAccount([self chosenAccount]);
    }

    if(self.contactMethod->account() == nullptr) {
        return;
    }
    if (self.contactMethod->account()->sendContactRequest(self.contactMethod)) {
        [self sendRequestSuccess];
    } else {
        [self sendRequestError];
    }
}

- (IBAction) cancelPressed:(id)sender
{
    [self close];
}

-(Account* ) chosenAccount
{
    QModelIndex index = AvailableAccountModel::instance().selectionModel()->currentIndex();
    if(!index.isValid())
        return nil;
    return index.data(static_cast<int>(Account::Role::Object)).value<Account*>();
}

-(void)sendRequestError
{
    self.hideButtons = true;
    NSString* error = NSLocalizedString(sendingErrorMsg, @"Error shown to user");
    [infoLabel setStringValue:sendingErrorMsg];
}

-(void) findContactError
{
    self.hideButtons = true;
    NSString* error = NSLocalizedString(findContactErrorMsg, @"Error shown to user");
    [infoLabel setStringValue:error];
}

-(void) sendRequestSuccess
{
    self.hideButtons = true;
    NSString* successMsg = NSLocalizedString(sendRequestSuccessMsg, @"contact request was sent with success");
    [infoLabel setStringValue:successMsg];
}

@end
