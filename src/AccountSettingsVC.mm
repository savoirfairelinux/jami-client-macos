/*
 *  Copyright (C) 2018 Savoir-faire Linux Inc.
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

//LRC
#import <api/lrc.h>
#import <api/account.h>
#import <api/newaccountmodel.h>

#import "views/NSColor+RingTheme.h"
#import "AccountSettingsVC.h"
#import "AccRingGeneralVC.h"
#import "AccSipGeneralVC.h"
#import "AccAdvancedRingVC.h"
#import "AccAdvancedSipVC.h"

@interface AccountSettingsVC ()

@property (unsafe_unretained) IBOutlet NSScrollView *containerView;
@property (unsafe_unretained) IBOutlet NSView *settingsView;

@end

@implementation AccountSettingsVC

std::string selectedAccountID;
NSViewController <AccountGeneralProtocol>* accountGeneralVC;
NSViewController <AccountAdvancedProtocol>* accountAdvancedVC;
AccRingGeneralVC* ringGeneralVC;
AccSipGeneralVC* sipGeneralVC;
AccAdvancedRingVC* ringAdvancedVC;
AccAdvancedSipVC* sipAdvancedVC;

CGFloat const VIEW_INSET = 20;

@synthesize accountModel;

-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil accountmodel:(lrc::api::NewAccountModel*) accountModel
{
    if (self =  [self initWithNibName: nibNameOrNil bundle:nibBundleOrNil])
    {
        self.accountModel= accountModel;
    }
   ringGeneralVC =  [[AccRingGeneralVC alloc] initWithNibName:@"AccRingGeneral" bundle:nil accountmodel: accountModel];
   sipGeneralVC =  [[AccSipGeneralVC alloc] initWithNibName:@"AccSipGeneral" bundle:nil accountmodel: accountModel];
   ringAdvancedVC = [[AccAdvancedRingVC alloc] initWithNibName:@"AccAdvancedRing" bundle:nil accountmodel: accountModel];
   sipAdvancedVC = [[AccAdvancedSipVC alloc] initWithNibName:@"AccAdvancedSip" bundle:nil accountmodel: accountModel];
   return self;
}

- (void) initFrame
{
    [self.view setFrame:self.view.superview.bounds];
    [self.view setHidden:YES];
}

- (void) setSelectedAccount:(std::string) account {
    selectedAccountID = account;
    const auto& accountInfo = accountModel->getAccountInfo(selectedAccountID);
    if (accountInfo.profileInfo.type == lrc::api::profile::Type::RING) {
        accountGeneralVC = ringGeneralVC;
        accountGeneralVC.delegate = self;
        accountAdvancedVC = ringAdvancedVC;
    } else if (accountInfo.profileInfo.type == lrc::api::profile::Type::SIP){
        accountGeneralVC = sipGeneralVC;
        accountGeneralVC.delegate = self;
        accountAdvancedVC = sipAdvancedVC;
    } else {
        [self hide];
        return;
    }
    [self.view.window makeFirstResponder:self.view];
    [accountGeneralVC setSelectedAccount: selectedAccountID];
    [accountAdvancedVC setSelectedAccount: selectedAccountID];
    [self displayGeneralSettings];
}

- (void) show {
    [self.view setHidden:NO];
    [self displayGeneralSettings];
}

-(void)displayGeneralSettings {
    self.containerView.documentView = accountGeneralVC.view;
    int bottomInset = self.containerView.frame.size.height - accountGeneralVC.view.frame.size.height - VIEW_INSET;
    self.containerView.contentInsets = NSEdgeInsetsMake(VIEW_INSET, 0, bottomInset, 0);
}

-(void)displayAllSettings {
    CGRect settingsFrame = accountGeneralVC.view.frame;
    settingsFrame.size.height = settingsFrame.size.height + accountAdvancedVC.view.frame.size.height;
    NSView* container = [[NSView alloc] initWithFrame:settingsFrame];
    [container addSubview:accountAdvancedVC.view];
    CGRect generalSettingsFrame = accountGeneralVC.view.frame;
    generalSettingsFrame.origin.y = accountAdvancedVC.view.frame.size.height;
    accountGeneralVC.view.frame = generalSettingsFrame;
    [container addSubview:accountGeneralVC.view];
    self.containerView.documentView = container;
    int bottomInset = self.containerView.frame.size.height - accountGeneralVC.view.frame.size.height - accountAdvancedVC.view.frame.size.height - VIEW_INSET;
    self.containerView.contentInsets = NSEdgeInsetsMake(VIEW_INSET, 0, (bottomInset > 0) ? bottomInset : 0, 0);
   [self scrollToTopScrollView: self.containerView];
}

-(void) scrollToTopScrollView: (NSScrollView *) scrollView {
    NSPoint newScrollOrigin;
    if ([[scrollView documentView] isFlipped]) {
        newScrollOrigin=NSMakePoint(0.0,0.0);
    } else {
        newScrollOrigin=NSMakePoint(0.0,NSMaxY([[scrollView documentView] frame])
                                    -NSHeight([[scrollView contentView] bounds]));
    }

    [[scrollView documentView] scrollPoint:newScrollOrigin];
}


#pragma mark - AccountGeneralDelegate methods

-(void) updateFrame {
    if (accountAdvancedVC.view.superview == self.containerView.documentView) {
        [self displayAllSettings];
        return;
    }
    [self displayGeneralSettings];
}

-(void) triggerAdvancedOptions {
    if(self.containerView.documentView.frame.size.height == (accountGeneralVC.view.frame.size.height + accountAdvancedVC.view.frame.size.height)) {
        [self displayGeneralSettings];
        return;
    }
    [self displayAllSettings];
}

- (void) hide {
    [self.view setHidden:YES];
}

@end
