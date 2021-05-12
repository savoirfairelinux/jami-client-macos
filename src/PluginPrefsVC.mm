/*
 *  Copyright (C) 2021 Savoir-faire Linux Inc.
 *  Author: Aline Gondim Santos <aline.gondimsantos@savoirfairelinux.com>
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

#import "PluginPrefsVC.h"
#import "AppDelegate.h"

#import <api/pluginmodel.h>

#import "views/PluginCell.h"
#import "PluginItemDelegateVC.h"

@interface PluginPrefsVC ()

@property (assign) IBOutlet NSButton *enablePluginsButton;
@property (unsafe_unretained) IBOutlet NSTableView *installedPluginsView;
@property (unsafe_unretained) IBOutlet NSStackView *hidableView;

@end

@implementation PluginPrefsVC
PluginItemDelegateVC *viewController;
@synthesize pluginModel;
@synthesize installedPluginsView, hidableView;

-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil pluginModel:(lrc::api::PluginModel*) pluginModel
{
    if (self =  [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.pluginModel = pluginModel;
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    NSNib *cellNib = [[NSNib alloc] initWithNibNamed:@"PluginCell" bundle:nil];
    [self.installedPluginsView registerNib:cellNib forIdentifier:@"PluginCellItem"];
    self.installedPluginsView.delegate = self;
    self.installedPluginsView.dataSource = self;
    if (!self.pluginModel->getPluginsEnabled())
        [hidableView setHidden:YES];
    else
        [hidableView setHidden:NO];
}

- (void)update {
    [self.enablePluginsButton setState: self.pluginModel->getPluginsEnabled()];
    [self.installedPluginsView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self update];
}

#pragma mark - actions

- (IBAction)toggleEnablePluginsButton:(NSButton *)sender {
    bool enabled = [sender state] == NSOnState;
    self.pluginModel->setPluginsEnabled(enabled);
    self.pluginModel->chatHandlerStatusUpdated(false);
    if (!enabled)
        [hidableView setHidden:YES];
    else
        [hidableView setHidden:NO];
    [self update];
}


- (IBAction)installPlugin:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:NO];
    [panel setCanChooseFiles:YES];
    NSMutableArray* allowedTypes = [[NSMutableArray alloc] init];
    [allowedTypes addObject:@"jpl"];
    [panel setAllowedFileTypes: allowedTypes];
    if ([panel runModal] != NSFileHandlingPanelOKButton) return;
    if ([[panel URLs] lastObject] == nil) return;
    NSString * path = [[[panel URLs] lastObject] path];
    bool status = self.pluginModel->installPlugin(QString::fromNSString(path), true);
    self.pluginModel->chatHandlerStatusUpdated(false);
    [self update];
}

#pragma mark - NSOpenSavePanelDelegate delegate methods

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    PluginCell* installedPluginCell = [tableView makeViewWithIdentifier:@"PluginCellItem" owner:self];

    auto installedPlugins = self.pluginModel->getInstalledPlugins();
    if ((installedPlugins.size() - 1) < row) {
        return nil;
    }

    auto plugin = installedPlugins[row];
    [installedPluginCell.viewController setPluginModel:self.pluginModel];
    PluginItemDelegateCallBacks callbacks;
    callbacks.uninstall = ([self](CallBackInfos infos) {
        auto installedPlugins = self.pluginModel->getInstalledPlugins();
        self.pluginModel->uninstallPlugin(infos.name);

        int rowToDelete = 0;
        bool match{false};
        for (const auto& item : installedPlugins) {
            if (item == infos.name) {
                match = true;
                break;
            }
            rowToDelete++;
        }
        if (!match)
            return;

        NSIndexSet* rowIndex = [NSIndexSet indexSetWithIndex:rowToDelete];
        [self.installedPluginsView removeRowsAtIndexes:rowIndex withAnimation:NSTableViewAnimationSlideUp];
    });
    [installedPluginCell.viewController setup:plugin row:row callbacks:callbacks];

    return installedPluginCell;
}

#pragma mark - NSTableViewDataSource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.pluginModel->getInstalledPlugins().size();
}
@end
