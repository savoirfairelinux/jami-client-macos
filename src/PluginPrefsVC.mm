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

@interface PluginPrefsVC ()

@property (assign) IBOutlet NSButton *enablePluginsButton;
@property (unsafe_unretained) IBOutlet NSTableView *installedPluginsView;

@end

@implementation PluginPrefsVC
@synthesize pluginModel;
@synthesize installedPluginsView;

NS_ENUM(NSInteger, tablesViews1) {
    PLUGIN_NAME_TAG = 1,
    PLUGIN_LOADED_TAG,
    PLUGIN_UNINSTALL_TAG,
    PLUGIN_ICON_TAG
};

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
    self.installedPluginsView.delegate = self;
    self.installedPluginsView.dataSource = self;
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
    bool enabled = [sender state]==NSOnState;
    self.pluginModel->setPluginsEnabled(enabled);
    self.pluginModel->chatHandlerStatusUpdated(false);
    [self update];
}


- (IBAction)installPlugin:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:NO];
    [panel setCanChooseFiles:YES];
    if ([panel runModal] != NSFileHandlingPanelOKButton) return;
    if ([[panel URLs] lastObject] == nil) return;
    NSString * path = [[[panel URLs] lastObject] path];
    bool status = self.pluginModel->installPlugin(QString::fromNSString(path), true);
    self.pluginModel->chatHandlerStatusUpdated(false);
    [self update];
}

- (IBAction)loadPlugin:(id)sender
{
    NSInteger row = [installedPluginsView rowForView:sender];
    if(row < 0) {
        return;
    }
    auto installedPlugins = self.pluginModel->getInstalledPlugins();
    if ((installedPlugins.size()-1) < row) {
        return;
    }
    auto plugin = installedPlugins[row];
    auto details = self.pluginModel->getPluginDetails(plugin);
    if (details.loaded) {
        self.pluginModel->unloadPlugin(plugin);
    } else
        self.pluginModel->loadPlugin(plugin);
    self.pluginModel->chatHandlerStatusUpdated(false);
    [self update];
}

- (IBAction)uninstallPlugin:(id)sender
{
    NSInteger row = [installedPluginsView rowForView:sender];
    if(row < 0) {
        return;
    }
    auto installedPlugins = self.pluginModel->getInstalledPlugins();
    if ((installedPlugins.size()-1) < row) {
        return;
    }
    auto plugin = installedPlugins[row];
    self.pluginModel->uninstallPlugin(plugin);
    [self update];
}

#pragma mark - signals

#pragma mark - dispaly

#pragma mark - NSOpenSavePanelDelegate delegate methods

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSTableCellView* installedPluginCell = [tableView makeViewWithIdentifier:@"TableCellInstalledPluginItem" owner:self];
    NSTextField* pluginNameLabel = [installedPluginCell viewWithTag: PLUGIN_NAME_TAG];
    NSButton* pluginLoadButton = [installedPluginCell viewWithTag: PLUGIN_LOADED_TAG];
    NSButton* pluginUninstallButton = [installedPluginCell viewWithTag: PLUGIN_UNINSTALL_TAG];
    NSImageView* pluginIcon = [installedPluginCell viewWithTag: PLUGIN_ICON_TAG];
    auto installedPlugins = self.pluginModel->getInstalledPlugins();
    if ((installedPlugins.size() - 1) < row) {
        return nil;
    }
    auto plugin = installedPlugins[row];
    auto details = self.pluginModel->getPluginDetails(plugin);
    if (details.iconPath.endsWith(".svg")) {
        details.iconPath.replace(".svg", ".png");
    }
    NSString* pathIcon = details.iconPath.toNSString();
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:pathIcon];
    [pluginIcon setImage: image];
    [pluginNameLabel setStringValue: details.name.toNSString()];
    [pluginLoadButton setState: details.loaded];
    [pluginLoadButton setAction:@selector(loadPlugin:)];
    [pluginLoadButton setTarget:self];
    [pluginUninstallButton setAction:@selector(uninstallPlugin:)];
    [pluginUninstallButton setTarget:self];
    return installedPluginCell;
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    if(![tableView isEnabled]) {
        return nil;
    }
    return [tableView makeViewWithIdentifier:@"HoverRowView" owner:nil];
}

#pragma mark - NSTableViewDataSource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.pluginModel->getInstalledPlugins().size();
}
@end
