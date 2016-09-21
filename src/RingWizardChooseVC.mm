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

@property (readonly) BOOL hasARadioSelected;
@property (readonly) WizardAction selectedRadio;

- (IBAction)onComplete:(id)sender;
@end

@implementation RingWizardChooseVC{
    __unsafe_unretained IBOutlet NSButton *rbNew;
    __unsafe_unretained IBOutlet NSButton *rbLink;
}

@synthesize delegate;

- (BOOL)hasARadioSelected
{
    return rbNew.state == 1 || rbLink.state ==1;
}

- (WizardAction)selectedRadio
{
    WizardAction result = WIZARD_ACTION_NEW;
    if (rbLink.state == 1){
        result = WIZARD_ACTION_LINK;
    }
    return result;
}

- (void)showCancelButton:(BOOL)showCancel{
    self.isCancelable = showCancel;
}

- (IBAction)onComplete:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(didCompleteWithAction:)]){
        [delegate didCompleteWithAction:self.selectedRadio];
    }
}
- (IBAction)onCancel:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(didCompleteWithAction:)]){
        [delegate didCompleteWithAction:WIZARD_ACTION_INVALID];
    }
}

- (IBAction)updateSelectedRadio:(NSButton *)sender
{
}

+ (NSSet *)keyPathsForValuesAffectingHasARadioSelected
{
    return [NSSet setWithObjects:@"rbNewValue", @"rbLinkValue", nil];
}
@end
