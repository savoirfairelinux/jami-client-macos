//
//  NoResponderTableView.m
//  Jami
//
//  Created by jami on 2021-05-12.
//

#import "NoResponderTableView.h"

@implementation NoResponderTableView

- (BOOL)becomeFirstResponder{
    return NO;
}

- (void)scrollWheel:(NSEvent *)theEvent
{
    [[self nextResponder] scrollWheel:theEvent];
}
@end
