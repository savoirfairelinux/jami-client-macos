//
//  IMTableCellView.m
//  Ring
//
//  Created by Alexandre Lision on 13/01/16.
//
//

#import "IMTableCellView.h"

#import "NSColor+RingTheme.h"

@implementation IMTableCellView
@synthesize msgView;
@synthesize photoView;


- (void) setup
{
    if ([self.identifier isEqualToString:@"RightMessageView"]) {
        [self.msgView setBackgroundColor:[NSColor ringBlue]];
    }
    [self.msgView setString:@""];
    [self.msgView setAutoresizingMask:NSViewWidthSizable];
    [self.msgView setEnabledTextCheckingTypes:NSTextCheckingTypeLink];
    [self.msgView setAutomaticLinkDetectionEnabled:YES];
}

- (void) updateWidthConstraint:(CGFloat) newWidth
{
    [self.msgView removeConstraints:[self.msgView constraints]];
    NSLayoutConstraint* constraint = [NSLayoutConstraint
                                      constraintWithItem:self.msgView
                                      attribute:NSLayoutAttributeWidth
                                      relatedBy:NSLayoutRelationEqual
                                      toItem: nil
                                      attribute:NSLayoutAttributeWidth
                                      multiplier:1.0f
                                      constant:newWidth];
    
    [self.msgView addConstraint:constraint];
}

@end
