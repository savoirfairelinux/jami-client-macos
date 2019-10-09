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
__unsafe_unretained IBOutlet NSButton* connectToManager;
__unsafe_unretained IBOutlet NSLayoutConstraint* viewBottomConstraint;

}

@synthesize delegate;

- (void)showInitialwithCancell:(BOOL)showCancel {
    self.isCancelable = showCancel;
    [self.view setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    [createSIPAccount setHidden: YES];
    [connectToManager setHidden: YES];
    viewBottomConstraint.constant = showCancel ? 25 : 0;
}

- (IBAction)createRingAccount:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(didCompleteWithAction:)]){
        [delegate didCompleteWithAction:WizardAction::WIZARD_ACTION_NEW];
    }
}

- (IBAction)importFromArchive:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(didCompleteWithAction:)]){
        [delegate didCompleteWithAction:WizardAction::WIZARD_ACTION_IMPORT_FROM_ADCHIVE];
    }
}

- (IBAction)importFromDevice:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(didCompleteWithAction:)]){
        [delegate didCompleteWithAction:WizardAction::WIZARD_ACTION_IMPORT_FROM_DEVICE];
    }
}

- (IBAction)connectToAccountManager:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(didCompleteWithAction:)]){
        [delegate didCompleteWithAction:WizardAction::WIZARD_ACTION_ACCOUNT_MANAGER];
    }
}

- (IBAction)onCancel:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(didCompleteWithAction:)]){
        [delegate didCompleteWithAction:WIZARD_ACTION_INVALID];
    }
}

- (IBAction)expandAdwanced:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(didCompleteWithAction:)]){
        [createSIPAccount setHidden: !createSIPAccount.isHidden];
        [connectToManager setHidden: !connectToManager.isHidden];
        [delegate didCompleteWithAction:WIZARD_ACTION_ADVANCED];
    }
}

- (IBAction)addSIPAccount:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(didCompleteWithAction:)]){
        [delegate didCompleteWithAction:WIZARD_ACTION_SIP_ACCOUNT];
    }
}

@end
