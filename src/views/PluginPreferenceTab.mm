//
//  PluginPreferenceTab.m
//  Jami
//
//  Created by jami on 2021-05-08.
//

#import "PluginPreferenceTab.h"

@implementation PluginPreferenceTab

@synthesize containerView;

- (void)awakeFromNib{
    self.viewController = [[PreferenceTabDelegateVC alloc] initWithNibName:@"PreferenceTabDelegateVC" bundle:nil];
    [self.containerView addSubview: self.viewController.view];
    self.viewController.view.frame = self.containerView.frame;
}

@end
