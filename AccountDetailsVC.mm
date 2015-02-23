//
//  AccountDetailsVC.m
//  Ring
//
//  Created by Alexandre Lision on 2015-02-25.
//
//

#import "AccountDetailsVC.h"

@interface AccountDetailsVC ()

@end

@implementation AccountDetailsVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

#pragma mark - NSTabViewDelegate methods

- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)tabView
{
    NSLog(@"tabViewDidChangeNumberOfTabViewItems!!");
}

- (BOOL)tabView:(NSTabView *)tabView
shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    NSLog(@"shouldSelectTabViewItem!!");

    return YES;
}

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    NSLog(@"willSelectTabViewItem!!");
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    NSLog(@"didSelectTabViewItem!!");
}

@end
