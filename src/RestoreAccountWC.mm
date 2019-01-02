/*
 *  Copyright (C) 2016-2019 Savoir-faire Linux Inc.
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
#import "RestoreAccountWC.h"

//LRC
#import <accountmodel.h>

//Ring
#import "views/ITProgressIndicator.h"

@interface RestoreAccountWC() <NSTextFieldDelegate> {
    __unsafe_unretained IBOutlet NSPathControl* path;
    __unsafe_unretained IBOutlet NSSecureTextField* passwordField;
    __unsafe_unretained IBOutlet ITProgressIndicator* progressIndicator;
}

@end

@implementation RestoreAccountWC {
    struct {
        unsigned int didCompleteImport:1;
    } delegateRespondsTo;
}
@synthesize accounts;

- (id)initWithDelegate:(id <LoadingWCDelegate>) del
{
    return [self initWithDelegate:del actionCode:0];
}

- (id)initWithDelegate:(id <RestoreAccountDelegate>) del actionCode:(NSInteger) code
{
    return [super initWithWindowNibName:@"RestoreAccountWindow" delegate:del actionCode:code];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [path setURL: [NSURL fileURLWithPath:NSHomeDirectory()]];
}

- (void)setDelegate:(id <RestoreAccountDelegate>)aDelegate
{
    if (self.delegate != aDelegate) {
        [super setDelegate: aDelegate];
        delegateRespondsTo.didCompleteImport = [self.delegate respondsToSelector:@selector(didCompleteWithImport)];
    }
}

- (void) setAllowFileSelection:(BOOL) b
{
    _allowFileSelection = b;
    [path setAllowedTypes:_allowFileSelection ? nil : [NSArray arrayWithObject:@"public.folder"]];
}

- (IBAction)completeAction:(id)sender
{
    auto passwordString = passwordField.stringValue;
    auto pathURL = path.URL;
    [self showLoading];
    SEL sel = @selector(importAccountsWithPath:andPassword:);
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:sel]];
    [inv setSelector:sel];
    [inv setTarget:self];
    //arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
    [inv setArgument:&pathURL atIndex:2];
    [inv setArgument:&passwordString atIndex:3];

    // Schedule import for next iteration of event loop in order to let us start the loading anim
    [inv performSelector:@selector(invoke) withObject:nil afterDelay:0];
}

- (void)showLoading
{
    [progressIndicator setNumberOfLines:30];
    [progressIndicator setWidthOfLine:2];
    [progressIndicator setLengthOfLine:5];
    [progressIndicator setInnerMargin:20];
    [super showLoading];
}

- (void) importAccountsWithPath:(NSURL*) urlPath andPassword:(NSString*) password
{
    int result = AccountModel::instance().importAccounts(urlPath.path.UTF8String, password.UTF8String);
    switch (result) {
        case 0:
            if (delegateRespondsTo.didCompleteImport)
                [((id<RestoreAccountDelegate>)self.delegate) didCompleteImport];
            [self close];
            break;
        default:
        {
            [self showError];
        }
            break;
    }
}

@end
