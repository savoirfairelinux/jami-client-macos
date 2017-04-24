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

// LRC
#import <availableaccountmodel.h>

#import "ContactRequestVC.h"
#import "ContactRequestsListVC.h"

@interface ContactRequestVC ()<NSPopoverDelegate> {

    NSPopover* pendingContactRequestPopover;
}

@end

@implementation ContactRequestVC

- (void)awakeFromNib
{
    [self.view setHidden:AvailableAccountModel::instance().rowCount() == 0];
    QObject::connect(&AvailableAccountModel::instance(),
                     &QAbstractItemModel::rowsRemoved,
                     [self]{
                         [self.view setHidden:AvailableAccountModel::instance().rowCount() == 0];
                     });

    QObject::connect(&AvailableAccountModel::instance(),
                     &QAbstractItemModel::dataChanged,
                     [self]{
                         [self.view setHidden:AvailableAccountModel::instance().rowCount() == 0];
                     });
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
    // when popover is closed remove ContactRequestsListVC to let it be allocated
    [pendingContactRequestPopover setContentViewController:nil];
}

@end
