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

//LRC
#import <accountmodel.h>

//Ring
#import "views/ITProgressIndicator.h"

@interface PathPasswordWC() <NSTextFieldDelegate>{
    __unsafe_unretained IBOutlet NSPathControl* path;
    __unsafe_unretained IBOutlet NSSecureTextField* passwordField;
    __unsafe_unretained IBOutlet NSTextField* errorField;
    __unsafe_unretained IBOutlet ITProgressIndicator* progressIndicator;
}

@end

@implementation PathPasswordWC {
    struct {
        unsigned int didCompleteExport:1;
        unsigned int didCompleteImport:1;
    } delegateRespondsTo;
}
@synthesize accounts;

- (id)initWithDelegate:(id <PathPasswordDelegate>) del actionCode:(NSInteger) code
{
    return [super initWithWindowNibName:@"PathPasswordWindow" delegate:del actionCode:code];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [path setURL: [NSURL fileURLWithPath:NSHomeDirectory()]];
}

- (void)setDelegate:(id <PathPasswordDelegate>)aDelegate
{
    if (self.delegate != aDelegate) {
        [super setDelegate: aDelegate];
        delegateRespondsTo.didCompleteExport = [self.delegate respondsToSelector:@selector(didCompleteExportWithPath:)];
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
    [self didCompleteWithPath:path.URL Password:passwordField.stringValue ActionCode:self.actionCode];
}


- (void)showLoading
{
    [progressIndicator setNumberOfLines:30];
    [progressIndicator setWidthOfLine:2];
    [progressIndicator setLengthOfLine:5];
    [progressIndicator setInnerMargin:20];
    [super showLoading];
}

-(void) didCompleteWithPath:(NSURL*) path Password:(NSString*) password ActionCode:(NSInteger)requestCode
{
    switch (requestCode) {
        case Action::ACTION_EXPORT:
        {
            auto finalURL = [path URLByAppendingPathComponent:@"accounts.ring"];
            [self showLoading];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                int result = AccountModel::instance().exportAccounts(accounts, finalURL.path.UTF8String, password.UTF8String);
                switch (result) {
                    case 0:
                        if (delegateRespondsTo.didCompleteExport){
                            [((id<PathPasswordDelegate>)self.delegate) didCompleteExportWithPath:finalURL];
                        }
                        [self close];
                        break;
                    default:{
                        [errorField setStringValue:NSLocalizedString(@"An error occured during the export", @"Error shown to the user" )];
                        [self showError] ;
                    }break;
                }
            });
        }
            break;
        case Action::ACTION_IMPORT: {
            [self showLoading];
            SEL sel = @selector(importAccountsWithPath:andPassword:);
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:sel]];
            [inv setSelector:sel];
            [inv setTarget:self];
            //arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
            [inv setArgument:&path atIndex:2];
            [inv setArgument:&password atIndex:3];

            // Schedule import for next iteration of event loop in order to let us start the loading anim
            [inv performSelector:@selector(invoke) withObject:nil afterDelay:0];

        }
            break;
        default:
            NSLog(@"Unrecognized action %d", requestCode);
            break;
    }
}

- (void) importAccountsWithPath:(NSURL*) path andPassword:(NSString*) password
{
    int result = AccountModel::instance().importAccounts(path.path.UTF8String, password.UTF8String);
    switch (result) {
        case 0:
            if (delegateRespondsTo.didCompleteImport)
                [((id<PathPasswordDelegate>)self.delegate) didCompleteImport];
            [self close];
            break;
        default:
        {
            [errorField setStringValue:NSLocalizedString(@"An error occured during the import", @"Error shown to the user" )];
            [self showError];
        }
            break;
    }
}

@end
