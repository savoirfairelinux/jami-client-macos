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
#import <QItemSelectionModel>
//LRC
#import <account.h>
#import <pendingContactRequestModel.h>
#import <availableAccountModel.h>

#import "ContactRequestVC.h"
#import "ContactRequestsListVC.h"

@interface ContactRequestVC ()<NSPopoverDelegate> {

    NSPopover* pendingContactRequestPopover;
}

@end

@implementation ContactRequestVC

QMetaObject::Connection requestAdded;
QMetaObject::Connection requestRemoved;

- (void)awakeFromNib
{
    [self.view setHidden:AvailableAccountModel::instance().rowCount() == 0];
    QObject::connect(&AvailableAccountModel::instance(),
                     &QAbstractItemModel::rowsRemoved,
                     [self]{
                         [self hideIfNeeded];
                     });

    QObject::connect(&AvailableAccountModel::instance(),
                     &QAbstractItemModel::dataChanged,
                     [self]{
                         [self hideIfNeeded];

                     });
    QObject::connect(AvailableAccountModel::instance().selectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [self](const QModelIndex& idx){
                         [self setupWithSelectedAccount];
                     });
    self.hideRequestNumberLabel = YES;
    [self setupWithSelectedAccount];
}

- (IBAction)displayTrustRequests:(NSView*)sender
{
    ContactRequestsListVC* contactRequestVC = [[ContactRequestsListVC alloc] initWithNibName:@"ContactRequestList" bundle:nil];
    pendingContactRequestPopover = [[NSPopover alloc] init];
    pendingContactRequestPopover.delegate = self;
    [pendingContactRequestPopover setContentSize:contactRequestVC.view.frame.size];
    [pendingContactRequestPopover setContentViewController:contactRequestVC];
    [pendingContactRequestPopover setAnimates:YES];
    [pendingContactRequestPopover setBehavior:NSPopoverBehaviorTransient];
    [pendingContactRequestPopover setDelegate:self];
    [pendingContactRequestPopover showRelativeToRect: sender.frame ofView:sender preferredEdge:NSMaxYEdge];
}

- (void)popoverDidClose:(NSNotification *)notification {
    // when popover is closed remove ContactRequestsListVC to let it be deallocated
    [pendingContactRequestPopover setContentViewController:nil];
}

-(void)setNumberOfRequests:(NSInteger)numberOfRequests
{
    _numberOfRequests = numberOfRequests;
    self.hideRequestNumberLabel = (_numberOfRequests == 0);
}

-(Account* ) chosenAccount
{
    QModelIndex index = AvailableAccountModel::instance().selectionModel()->currentIndex();
    if(!index.isValid()) {
        return nullptr;
    }
    Account* account = index.data(static_cast<int>(Account::Role::Object)).value<Account*>();
    return account;
}

-(void) setupWithSelectedAccount
{
    Account* chosenAccount = [self chosenAccount];
    if(!chosenAccount) {
        return;
    }
    [self.view setHidden:chosenAccount->protocol() != Account::Protocol::RING];
    if(chosenAccount->protocol() != Account::Protocol::RING) {
        return;
    }

    self.numberOfRequests = chosenAccount->pendingContactRequestModel()->rowCount();

    QObject::disconnect(requestAdded);
    requestAdded = QObject::connect(chosenAccount->pendingContactRequestModel(),
                                    &QAbstractItemModel::rowsInserted,
                                    [=]() {
                                        self.numberOfRequests = chosenAccount->pendingContactRequestModel()->rowCount();
                                    }
                                    );
    QObject::disconnect(requestRemoved);
    requestRemoved = QObject::connect(chosenAccount->pendingContactRequestModel(),
                                      &QAbstractItemModel::rowsRemoved,
                                      [=]() {
                                          self.numberOfRequests = chosenAccount->pendingContactRequestModel()->rowCount();
                                      }

                                      );
}

-(void)hideIfNeeded
{
    if(AvailableAccountModel::instance().rowCount() == 0) {
        [self.view setHidden:YES];
        return;
    }
    Account* chosenAccount = [self chosenAccount];
    if(!chosenAccount) {
        return;
    }
    [self.view setHidden:chosenAccount->protocol() != Account::Protocol::RING];
}

@end
