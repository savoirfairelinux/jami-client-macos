/************************************************************************************
 *   Copyright (C) 2014-2015 by Savoir-Faire Linux                                  *
 *   Author : Alexandre Lision <alexandre.lision@savoirfairelinux.com>              *
 *                                                                                  *
 *   This library is free software; you can redistribute it and/or                  *
 *   modify it under the terms of the GNU Lesser General Public                     *
 *   License as published by the Free Software Foundation; either                   *
 *   version 2.1 of the License, or (at your option) any later version.             *
 *                                                                                  *
 *   This library is distributed in the hope that it will be useful,                *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of                 *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU              *
 *   Lesser General Public License for more details.                                *
 *                                                                                  *
 *   You should have received a copy of the GNU Lesser General Public               *
 *   License along with this library; if not, write to the Free Software            *
 *   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA *
 ***********************************************************************************/
#ifndef ACCOUNTSVC_H
#define ACCOUNTSVC_H

#import <Cocoa/Cocoa.h>

#import "QNSTreeController.h"

@interface AccountsVC : NSViewController <NSOutlineViewDelegate, NSTabViewDelegate> {
    NSOutlineView *accountsListView;
    NSSegmentedControl *accountsControls;
}
@property (assign) IBOutlet NSSegmentedControl *accountsControls;

@property QNSTreeController *treeController;
@property (assign) IBOutlet NSOutlineView *accountsListView;

- (IBAction)segControlClicked:(NSSegmentedControl *)sender;

@end

#endif // ACCOUNTSVC_H
