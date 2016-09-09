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
#import "ExportPasswordWC.h"

#import "views/ITProgressIndicator.h"
@interface ExportPasswordWC() <NSTextFieldDelegate>{
    
}

@end

@implementation ExportPasswordWC {
    struct {
        unsigned int didStart:1;
        unsigned int didComplete:1;
    } delegateRespondsTo;
}

- (id)initWithDelegate:(id <ExportPasswordDelegate>) del actionCode:(NSInteger) code
{
    return [super initWithWindowNibName:@"ExportPasswordWindow" delegate:del actionCode:code];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
}

- (void)setDelegate:(id <ExportPasswordDelegate>)aDelegate
{
    if (super.delegate != aDelegate) {
        [super setDelegate: aDelegate];
        delegateRespondsTo.didStart = [aDelegate respondsToSelector:@selector(didStartWithPassword:)];
        delegateRespondsTo.didComplete = [aDelegate respondsToSelector:@selector(didCompleteWithPin:Password:)];
    }  
}



- (IBAction)completeAction:(id)sender
{
    if (delegateRespondsTo.didStart)
        [((id<ExportPasswordDelegate>)self.delegate) didStartWithPassword: passwordField.stringValue];
}



@end
