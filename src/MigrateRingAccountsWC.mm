/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
 *  Author: Alexandre Lision <alexandre.lision@savoirfairelinux.com>
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

#import "MigrateRingAccountsWC.h"

#import "views/ITProgressIndicator.h"

@interface MigrateRingAccountsWC() <NSTextFieldDelegate>

@property (unsafe_unretained) IBOutlet NSSecureTextField* passwordField;
@property (unsafe_unretained) IBOutlet NSSecureTextField* passwordConfirmField;


@end

@implementation MigrateRingAccountsWC

- (id)initWithDelegate:(id <MigrateRingAccountsDelegate>) del actionCode:(NSInteger) code
{
    return [super initWithWindowNibName:@"MigrateRingAccountsWindow" delegate:del actionCode:code];
}

- (void)setDelegate:(id <MigrateRingAccountsDelegate>)aDelegate
{
    if (super.delegate != aDelegate) {
        [super setDelegate: aDelegate];
    }
}

- (IBAction)startMigration:(NSButton *)sender {
    [self showLoading];
    //    if ([self.delegate respondsToSelector:@selector(migrationDidComplete)])
    //        [((id<MigrateRingAccountsDelegate>)self.delegate) migrationDidComplete];
}

@end
