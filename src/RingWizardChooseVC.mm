/*
 *  Copyright (C) 2015-2016 Savoir-faire Linux Inc.
 *  Author: Loïc Siret <loic.siret@savoirfairelinux.com>
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

#import "RingWizardChooseVC.h"

@interface RingWizardChooseVC()

@end

@implementation RingWizardChooseVC {

__unsafe_unretained IBOutlet NSButton* createSIPAccount;
__unsafe_unretained IBOutlet NSLayoutConstraint* buttonTopConstraint;

}

@synthesize delegate;

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setAutoresizingMask: NSViewHeightSizable];
}

- (void)showCancelButton:(BOOL)showCancel {
    [createSIPAccount setHidden: YES];
    buttonTopConstraint.constant = showCancel ? 25 : 0;
    self.isCancelable = showCancel;
}

- (void)showAdvancedButton:(BOOL)showAdvanced {
    self.withAdvancedOptions = showAdvanced;
}

- (IBAction)createRingAccount:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(didCompleteWithAction:)]){
        [delegate didCompleteWithAction:WizardAction::WIZARD_ACTION_NEW];
    }
}

- (IBAction)linkExistingRingAccount:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(didCompleteWithAction:)]){
        [delegate didCompleteWithAction:WizardAction::WIZARD_ACTION_LINK];
    }
}

- (IBAction)onCancel:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(didCompleteWithAction:)]){
        [delegate didCompleteWithAction:WIZARD_ACTION_INVALID];
    }
}

- (IBAction)showCreateSIP:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(didCompleteWithAction:)]){
        buttonTopConstraint.constant = 57;
        [delegate didCompleteWithAction:WIZARD_ACTION_ADVANCED];
        [createSIPAccount setHidden: NO];
    }
}

- (IBAction)addSIPAccount:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(didCompleteWithAction:)]){
        [delegate didCompleteWithAction:WIZARD_ACTION_SIP_ACCOUNT];
    }
}

@end
