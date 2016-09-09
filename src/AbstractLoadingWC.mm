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

#import "AbstractLoadingWC.h"

@interface AbstractLoadingWC() <NSTextFieldDelegate>
{

}
@end

@implementation AbstractLoadingWC
{
    struct {
        unsigned int didComplete:1;
        unsigned int didCompleteWithActionCode:1;
    } delegateRespondsTo;
}

- (id)initWithWindowNibName:(NSString *)nibName delegate:(id <LoadingWCDelegate>) del actionCode:(NSInteger) code
{
    if ((self = [super initWithWindowNibName:nibName]) != nil) {
        [self setDelegate:del];
        self.actionCode = code;
    }
    return self;
}

- (id)initWithDelegate:(id <LoadingWCDelegate>) del actionCode:(NSInteger) code
{
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass",NSStringFromSelector(_cmd)];
    return nil;
}


- (void)windowDidLoad
{
    [super windowDidLoad];
    [initialContainer setHidden:NO];
    [progressContainer setHidden:YES];
    [errorContainer setHidden:YES];
    [finalContainer setHidden:YES];
}

- (IBAction) cancelPressed:(id)sender
{
    [self close];
}

- (IBAction)completeAction:(id)sender
{
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass",NSStringFromSelector(_cmd)];
}

- (void)close
{
    [NSApp endSheet:self.window];
    [self.window orderOut:self];
}


- (void)showLoading
{
    [initialContainer setHidden:YES];
    [progressContainer setHidden:NO];
    [errorContainer setHidden:YES];
    [finalContainer setHidden:YES];
}

- (void)showError
{
    [initialContainer setHidden:YES];
    [progressContainer setHidden:YES];
    [errorContainer setHidden:NO];
    [finalContainer setHidden:YES];
}

- (void)showFinal
{
    [initialContainer setHidden:YES];
    [progressContainer setHidden:YES];
    [errorContainer setHidden:YES];
    [finalContainer setHidden:NO];
}
@end
