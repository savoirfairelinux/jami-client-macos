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
#import "PathPasswordWC.h"

#import "views/ITProgressIndicator.h"

@interface PathPasswordWC() <NSTextFieldDelegate>{

    __unsafe_unretained IBOutlet NSView* errorContainer;
    __unsafe_unretained IBOutlet NSTextField* errorLabel;

    __unsafe_unretained IBOutlet ITProgressIndicator* progressView;

    __unsafe_unretained IBOutlet NSView* pathPasswordContainer;
    __unsafe_unretained IBOutlet NSSecureTextField* passwordField;
    __unsafe_unretained IBOutlet NSPathControl* path;

}

@end

@implementation PathPasswordWC {
    struct {
        unsigned int didComplete:1;
        unsigned int didCompleteWithActionCode:1;
    } delegateRespondsTo;
}

- (id)initWithDelegate:(id <PathPasswordDelegate>) del actionCode:(NSInteger) code
{
    if ((self = [super initWithWindowNibName:@"PathPasswordWindow"]) != nil) {
        [self setDelegate:del];
        self.actionCode = code;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [path setURL: [NSURL fileURLWithPath:NSHomeDirectory()]];
    [progressView setNumberOfLines:30];
    [progressView setWidthOfLine:2];
    [progressView setLengthOfLine:5];
    [progressView setInnerMargin:20];
    [progressView setHidden:YES];
}

- (void)setDelegate:(id <PathPasswordDelegate>)aDelegate
{
    if (self.delegate != aDelegate) {
        _delegate = aDelegate;
        delegateRespondsTo.didComplete = [self.delegate respondsToSelector:@selector(didCompleteWithPath:Password:)];
        delegateRespondsTo.didCompleteWithActionCode = [self.delegate respondsToSelector:@selector(didCompleteWithPath:Password:ActionCode:)];
    }
}

- (void) setAllowFileSelection:(BOOL) b
{
    _allowFileSelection = b;
    [path setAllowedTypes:_allowFileSelection ? nil : [NSArray arrayWithObject:@"public.folder"]];
}

- (IBAction) cancelPressed:(id)sender
{
    [NSApp endSheet:self.window];
    [self.window orderOut:self];
}

- (IBAction)completeAction:(id)sender
{
    if (delegateRespondsTo.didComplete)
        [self.delegate didCompleteWithPath:path.URL Password:passwordField.stringValue];
    else if (delegateRespondsTo.didCompleteWithActionCode)
        [self.delegate didCompleteWithPath:path.URL Password:passwordField.stringValue ActionCode:self.actionCode];
}

- (id)showLoading
{
    [progressView setHidden:NO];
    [pathPasswordContainer setHidden:YES];
    [errorContainer setHidden:YES];
    [progressView setAnimates:YES];
}

- (id)showError:(NSString*) error
{
    [progressView setHidden:YES];
    [pathPasswordContainer setHidden:YES];
    [errorContainer setHidden:NO];
    [errorLabel setStringValue:error];
}

@end
