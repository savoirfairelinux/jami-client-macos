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
    [progressView setNumberOfLines:30];
    [progressView setWidthOfLine:2];
    [progressView setLengthOfLine:5];
    [progressView setInnerMargin:20];
    [progressView setHidden:YES];
}

- (IBAction) cancelPressed:(id)sender
{
    [NSApp endSheet:self.window];
    [self.window orderOut:self];
}

- (IBAction)completeAction:(id)sender
{
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass",NSStringFromSelector(_cmd)];
}

- (void)showLoading
{
    [progressView setHidden:NO];
    [pathPasswordContainer setHidden:YES];
    [errorContainer setHidden:YES];
    [progressView setAnimates:YES];
}

- (void)showError:(NSString*) error
{
    [progressView setHidden:YES];
    [pathPasswordContainer setHidden:YES];
    [errorContainer setHidden:NO];
    [errorLabel setStringValue:error];
}


@end
