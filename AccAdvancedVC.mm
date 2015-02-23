//
//  AccAdvancedVC.m
//  Ring
//
//  Created by Alexandre Lision on 2015-02-26.
//
//

#import "AccAdvancedVC.h"

@interface AccAdvancedVC ()

@property Account* privateAccount;

@end

@implementation AccAdvancedVC
@synthesize privateAccount;

- (void)awakeFromNib
{
    NSLog(@"INIT Advanced VC");
}

- (void)loadAccount:(Account *)account
{
    privateAccount = account;
}

#pragma mark - NSTextFieldDelegate methods

- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor
{
    NSLog(@"textShouldBeginEditing");
    return YES;
}

- (BOOL)control:(NSControl *)control didFailToFormatString:(NSString *)string errorDescription:(NSString *)error
{
    NSLog(@"didFailToFormatString");
}

- (void)control:(NSControl *)control didFailToValidatePartialString:(NSString *)string errorDescription:(NSString *)error
{
    NSLog(@"didFailToValidatePartialString");
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    NSLog(@"doCommandBySelector");
}

-(void)controlTextDidBeginEditing:(NSNotification *)obj
{

}

-(void)controlTextDidChange:(NSNotification *)notif
{
    NSTextField *textField = [notif object];
    NSRange test = [[textField currentEditor] selectedRange];


    //FIXME: saving account lose focus because in NSTreeController we remove and reinsert row so View selction change
    //privateAccount << Account::EditAction::SAVE;
    [textField.window makeFirstResponder:textField];
    [[textField currentEditor] setSelectedRange:test];
}
@end
