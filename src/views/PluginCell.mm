//
//  PluginCell.m
//  Jami
//
//  Created by jami on 2021-05-07.
//

#import "PluginCell.h"


@implementation PluginCell

@synthesize containerView;

- (void)awakeFromNib{
    self.viewController = [[PluginItemDelegateVC alloc] initWithNibName:@"PluginItemDelegate" bundle:nil];
    [self.containerView addSubview: self.viewController.view];
    self.viewController.view.frame = self.containerView.frame;
}

@end
