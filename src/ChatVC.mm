//
//  ChatVC.m
//  Ring
//
//  Created by Alexandre Lision on 2015-06-04.
//
//

#import "ChatVC.h"

#import <media/>

@interface ChatVC ()

@property (unsafe_unretained) IBOutlet NSTextView *chatView;
@property (unsafe_unretained) IBOutlet NSTextField *messageField;
@property (unsafe_unretained) IBOutlet NSButton *sendButton;

@end

@implementation ChatVC
@synthesize messageField,chatView,sendButton;

- (void)awakeFromNib
{
    NSLog(@"Init ChatVC");
}

- (IBAction)sendMessage:(id)sender {
    NSAttributedString* attr = [[NSAttributedString alloc] initWithString:
                                [NSString stringWithFormat:@"%@\n",self.message]];
    [[chatView textStorage] appendAttributedString:attr];
    [chatView scrollRangeToVisible:NSMakeRange([[chatView string] length], 0)];
    // Empty the text after sending it
    [self.messageField setStringValue:@""];
    self.message = @"";
}

#pragma mark - NSTextFieldDelegate

- (BOOL)control:(NSControl *)control textView:(NSTextView *)fieldEditor doCommandBySelector:(SEL)commandSelector
{
    if (commandSelector == @selector(insertNewline:) && self.message.length > 0) {
        [self sendMessage:nil];
        return YES;
    }
    return NO;
}

@end
