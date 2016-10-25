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
#import "BackupAccountWC.h"

//LRC
#import <accountmodel.h>

//Ring
#import "views/ITProgressIndicator.h"

@interface BackupAccountWC() <NSTextFieldDelegate> {
    __unsafe_unretained IBOutlet NSPathControl* path;
    __unsafe_unretained IBOutlet NSSecureTextField* passwordField;
    __unsafe_unretained IBOutlet NSSecureTextField* passwordConfirmationField;
    __unsafe_unretained IBOutlet ITProgressIndicator* progressIndicator;

}

@end

@implementation BackupAccountWC {
    struct {
        unsigned int didCompleteExport:1;
    } delegateRespondsTo;
}
@synthesize accounts;

- (id)initWithDelegate:(id <LoadingWCDelegate>) del
{
    return [self initWithDelegate:del actionCode:0];
}

- (id)initWithDelegate:(id <BackupAccountDelegate>) del actionCode:(NSInteger) code
{
    return [super initWithWindowNibName:@"BackupAccountWindow" delegate:del actionCode:code];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [path setURL: [NSURL fileURLWithPath:NSHomeDirectory()]];
}

- (void)setDelegate:(id <BackupAccountDelegate>)aDelegate
{
    if (self.delegate != aDelegate) {
        [super setDelegate: aDelegate];
        delegateRespondsTo.didCompleteExport = [self.delegate respondsToSelector:@selector(didCompleteExportWithPath:)];
    }
}

- (BOOL)validatePasswords
{
    BOOL result = (self.password.length != 0 && [self.password isEqualToString:self.passwordConfirmation]);
    NSLog(@"ValidatesPasswords : %s", result ? "true" : "false");
    return result;
}

+ (NSSet *)keyPathsForValuesAffectingValidatePasswords
{
    return [NSSet setWithObjects:@"password", @"passwordConfirmation", nil];
}

- (void) setAllowFileSelection:(BOOL) b
{
    _allowFileSelection = b;
    [path setAllowedTypes:_allowFileSelection ? nil : [NSArray arrayWithObject:@"public.folder"]];
}

- (IBAction)completeAction:(id)sender
{
    auto finalURL = [path.URL URLByAppendingPathComponent:@"accounts.ring"];
    [self showLoading];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int result = AccountModel::instance().exportAccounts(accounts, finalURL.path.UTF8String, passwordField.stringValue.UTF8String);
        switch (result) {
            case 0:
                if (delegateRespondsTo.didCompleteExport){
                    [((id<BackupAccountDelegate>)self.delegate) didCompleteExportWithPath:finalURL];
                }
                [self close];
                break;
            default:{
                [self showError] ;
            }break;
        }
    });
}

- (void)showLoading
{
    [progressIndicator setNumberOfLines:30];
    [progressIndicator setWidthOfLine:2];
    [progressIndicator setLengthOfLine:5];
    [progressIndicator setInnerMargin:20];
    [super showLoading];
}

- (void) insertTab:(id)sender
{
    if ([[self window] firstResponder] == self ) {
        [[self window] selectNextKeyView:self];
    }
}

- (void) insertBacktab:(id)sender
{
    if ([[self window] firstResponder] == self ) {
        [[self window] selectPreviousKeyView:self];
    }
}

@end
