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
#import "AccGeneralVC.h"
#import "AccAudioVC.h"
#import "AccVideoVC.h"
#import "AccAdvancedVC.h"

@interface AccountsVC : NSViewController <NSOutlineViewDelegate, NSTabViewDelegate> {
    NSOutlineView *accountsListView;

    NSSegmentedControl *accountsControls;

    NSTabView *accountDetailsView;
    NSTabViewItem *generalItem;
    NSTabViewItem *audioTabItem;
    NSTabViewItem *videoTabItem;
    NSTabViewItem *advancedTabItem;
}
@property (assign) IBOutlet NSSegmentedControl *accountsControls;

@property QNSTreeController *treeController;
@property (assign) IBOutlet NSOutlineView *accountsListView;
@property (assign) IBOutlet NSTabView *accountDetailsView;

@property (assign) IBOutlet NSTabViewItem *generalTabItem;
@property (assign) IBOutlet NSTabViewItem *audioTabItem;
@property (assign) IBOutlet NSTabViewItem *videoTabItem;
@property (assign) IBOutlet NSTabViewItem *advancedTabItem;

@property AccGeneralVC* generalVC;
@property AccAudioVC* audioVC;
@property AccVideoVC* videoVC;
@property AccAdvancedVC* advancedVC;


- (IBAction)segControlClicked:(NSSegmentedControl *)sender;

@end

#endif // ACCOUNTSVC_H
