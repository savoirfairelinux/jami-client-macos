/*
 *  Copyright (C) 2015-2016 Savoir-faire Linux Inc.
 *  Author: Alexandre Lision <alexandre.lision@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

#import <QuartzCore/QuartzCore.h>

#import <api/pluginmodel.h>

@interface PluginPrefsVC ()

@property (assign) IBOutlet NSButton *enablePluginsButton;
@property (unsafe_unretained) IBOutlet NSTableView *installedPluginsView;
@property (unsafe_unretained) IBOutlet NSTableView *preferencesListView;
@property (unsafe_unretained) IBOutlet NSImageView *pluginPreferenceIcon;
@property (unsafe_unretained) IBOutlet NSTextField *pluginPreferenceTitle;
@property (unsafe_unretained) IBOutlet NSStackView *preferencesView;
@property (unsafe_unretained) IBOutlet NSStackView *hidableView;
@property (unsafe_unretained) IBOutlet NSButton *reset;
@property (unsafe_unretained) IBOutlet NSButton *uninstall;

@end

@implementation PluginPrefsVC
@synthesize pluginModel;
@synthesize installedPluginsView, preferencesView, preferencesListView, pluginPreferenceIcon, pluginPreferenceTitle, reset, uninstall, hidableView;

NSInteger lastPreferenceRow = -1;
QString lastPluginName = "";
QString lastIconPath = "";

NS_ENUM(NSInteger, pluginsTableView) {
    PLUGIN_NAME_TAG = 1,
    PLUGIN_LOADED_TAG,
    PLUGIN_ICON_TAG,
    PLUGIN_PREFERENCES_TAG
};

NS_ENUM(NSInteger, preferencesTableView) {
    PREFERENCE_NAME_TAG = 100,
    PREFERENCE_VALUE_TAG = 200
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
    self.preferencesListView.delegate = self;
    self.preferencesListView.dataSource = self;
    bool enabled = self.pluginModel->getPluginsEnabled();
    if (!enabled) {
        [preferencesView setHidden:YES];
        [hidableView setHidden:YES];
    } else {
        [hidableView setHidden:NO];
        if (lastPreferenceRow >= 0) {
            [preferencesView setHidden:NO];
            NSString* pathIcon = lastIconPath.toNSString();
            NSImage *image = [[NSImage alloc] initWithContentsOfFile:pathIcon];
            [pluginPreferenceIcon setImage:image];
            [pluginPreferenceTitle setStringValue:[lastPluginName.toNSString() lastPathComponent]];
        }
    }
}

- (void)update {
    [self.enablePluginsButton setState: self.pluginModel->getPluginsEnabled()];
    [self.installedPluginsView reloadData];
    [self.preferencesListView reloadData];
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
    if (!enabled) {
        [preferencesView setHidden:YES];
        [hidableView setHidden:YES];
    } else {
        [hidableView setHidden:NO];
        if (lastPreferenceRow >= 0) {
            [preferencesView setHidden:NO];
        }
    }
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
    NSIndexSet* rowIndex = [NSIndexSet indexSetWithIndex:row];
    NSIndexSet* columnIndex = [NSIndexSet indexSetWithIndex:0];
    [self.installedPluginsView reloadDataForRowIndexes:rowIndex columnIndexes:columnIndex];
}

- (IBAction)uninstallPlugin:(id)sender
{
    self.pluginModel->uninstallPlugin(lastPluginName);
    
    NSIndexSet* rowIndex = [NSIndexSet indexSetWithIndex:lastPreferenceRow];
    
    auto* rowView = [installedPluginsView rowViewAtRow:lastPreferenceRow makeIfNecessary:NO];
    NSButton* disclosure = [rowView viewWithTag:PLUGIN_PREFERENCES_TAG];
    auto discId = [disclosure identifier];
    [disclosure performClick:discId];
    
    [self.installedPluginsView removeRowsAtIndexes:rowIndex withAnimation:NSTableViewAnimationSlideUp];
}

- (IBAction)resetPlugin:(id)sender
{
    self.pluginModel->resetPluginPreferencesValues(lastPluginName);
    
    [self.preferencesListView reloadData];
}

- (IBAction)showPreferences:(id)sender {
    NSInteger row = [installedPluginsView rowForView:sender];
    if(row < 0) {
        return;
    }

    if (preferencesView.hidden || lastPreferenceRow != row) {
        [preferencesView setHidden:NO];

        auto installedPlugins = self.pluginModel->getInstalledPlugins();
        if ((installedPlugins.size() - 1) < row) {
            return;
        }
        auto plugin = installedPlugins[row];
        lastPluginName = plugin;
        auto details = self.pluginModel->getPluginDetails(plugin);
        if (details.iconPath.endsWith(".svg")) {
            details.iconPath.replace(".svg", ".png");
        }
        lastIconPath = details.iconPath;
        NSString* pathIcon = details.iconPath.toNSString();
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:pathIcon];
        [pluginPreferenceIcon setImage:image];
        [self.preferencesListView reloadData];
        
        [pluginPreferenceTitle setStringValue:[plugin.toNSString() lastPathComponent]];
        
        auto numberOfRows = [self numberOfRowsInTableView:installedPluginsView];
        if (lastPreferenceRow >= 0 && lastPreferenceRow < numberOfRows && lastPreferenceRow != row) {
            NSIndexSet* rowIndex = [NSIndexSet indexSetWithIndex:lastPreferenceRow];
            NSIndexSet* columnIndex = [NSIndexSet indexSetWithIndex:0];
            [self.installedPluginsView reloadDataForRowIndexes:rowIndex columnIndexes:columnIndex];
        }
        lastPreferenceRow = row;
    } else {
        [preferencesView setHidden:YES];
        lastPreferenceRow = -1;
        lastPluginName = "";
        lastIconPath = "";
    }
}

- (IBAction)setPreference:(id)sender {
    NSInteger row = [preferencesListView rowForView:sender];
    if(row < 0) {
        return;
    }
    
    auto fullPrefs = pluginModel->getPluginPreferences(lastPluginName);
    auto valuesPrefs = pluginModel->getPluginPreferencesValues(lastPluginName);
    
    QString name = fullPrefs[row]["title"];
    QString key = fullPrefs[row]["key"];
    QString type = fullPrefs[row]["type"];
    
    if (type == "Switch") {
        auto* rowView = [preferencesListView rowViewAtRow:row makeIfNecessary:NO];
        NSButton* button = [rowView viewWithTag:PREFERENCE_VALUE_TAG];
        QString value = [button state] ? "1" : "0";
        pluginModel->setPluginPreference(lastPluginName, key, value);
    } else if (type == "EditText") {
        auto* rowView = [preferencesListView rowViewAtRow:row makeIfNecessary:NO];
        NSTextField* text = [rowView viewWithTag:PREFERENCE_VALUE_TAG];
        QString value =  QString::fromNSString([text stringValue]);
        pluginModel->setPluginPreference(lastPluginName, key, value);
    } else if (type == "List") {
        auto* rowView = [preferencesListView rowViewAtRow:row makeIfNecessary:NO];
        NSPopUpButton* button = [rowView viewWithTag:PREFERENCE_VALUE_TAG];
        auto entries = fullPrefs[row]["entries"].split(",");
        auto entryValues = fullPrefs[row]["entryValues"].split(",");
        QString value = QString::fromNSString([[button selectedItem] title]);
        auto newEntry = entries.indexOf(value);
        pluginModel->setPluginPreference(lastPluginName, key, entryValues[newEntry]);
    } else if (type == "Path") {
        auto* rowView = [preferencesListView rowViewAtRow:row makeIfNecessary:NO];
        NSButton* button = [rowView viewWithTag:PREFERENCE_VALUE_TAG];
        NSOpenPanel *panel = [NSOpenPanel openPanel];
        [panel setAllowsMultipleSelection:NO];
        [panel setCanChooseDirectories:NO];
        [panel setCanChooseFiles:YES];
        
        auto mimeTypes = fullPrefs[row]["mimeType"].split(",");
        NSMutableArray* allowedTypes = [[NSMutableArray alloc] init];
        for (const auto& mime : mimeTypes) {
            QString ext = mime.split("/").last();
            if (ext == "*") {
                allowedTypes = nil;
                break;
            }
            [allowedTypes addObject:ext.toNSString()];
        }
        [panel setAllowedFileTypes: allowedTypes];
        if ([panel runModal] != NSFileHandlingPanelOKButton) return;
        if ([[panel URLs] lastObject] == nil) return;
        NSString * path = [[[panel URLs] lastObject] path];
        
        pluginModel->setPluginPreference(lastPluginName, key, QString::fromNSString(path));
        [button setTitle: [path lastPathComponent]];
    }
}

#pragma mark - NSOpenSavePanelDelegate delegate methods

- (BOOL) panel:(id)sender shouldEnableURL:(NSURL*)url {
    return YES;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if (tableView == installedPluginsView) {
        NSTableCellView* installedPluginCell = [tableView makeViewWithIdentifier:@"TableCellInstalledPluginItem" owner:self];
        NSTextField* pluginNameLabel = [installedPluginCell viewWithTag: PLUGIN_NAME_TAG];
        NSSwitch* pluginLoadButton = [installedPluginCell viewWithTag: PLUGIN_LOADED_TAG];
        NSImageView* pluginIcon = [installedPluginCell viewWithTag: PLUGIN_ICON_TAG];
        NSButton* showPreferencesButton = [installedPluginCell viewWithTag:PLUGIN_PREFERENCES_TAG];
        auto installedPlugins = self.pluginModel->getInstalledPlugins();
        if ((installedPlugins.size() - 1) < row) {
            return nil;
        }
        [showPreferencesButton setState:NSControlStateValueOn];
        
        auto plugin = installedPlugins[row];
        auto details = self.pluginModel->getPluginDetails(plugin);
        if (details.iconPath.endsWith(".svg")) {
            details.iconPath.replace(".svg", ".png");
        }
        if (lastPluginName == plugin) {
            lastPreferenceRow = row;
            [showPreferencesButton setState:NSControlStateValueOff];
        }
        NSString* pathIcon = details.iconPath.toNSString();
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:pathIcon];
        [pluginIcon setImage: image];
        [pluginNameLabel setStringValue: details.name.toNSString()];
        [pluginLoadButton setState: details.loaded];
        [pluginLoadButton setAction:@selector(loadPlugin:)];
        [pluginLoadButton setTarget:self];
        [showPreferencesButton setAction:@selector(showPreferences:)];
        return installedPluginCell;
        
    } else if (tableView == preferencesListView) {
        
        auto fullPrefs = pluginModel->getPluginPreferences(lastPluginName);
        auto valuesPrefs = pluginModel->getPluginPreferencesValues(lastPluginName);
        
        QString name = fullPrefs[row]["title"];
        QString key = fullPrefs[row]["key"];
        QString type = fullPrefs[row]["type"];
        QString value = valuesPrefs[key];

        NSTableCellView* preferenceCell = [tableView makeViewWithIdentifier:@"TableCellPreferenceSwitchItem" owner:self];
        NSTextField* preferenceLabel = [preferenceCell viewWithTag: PREFERENCE_NAME_TAG];
        NSSwitch* preferenceToggledButton = [preferenceCell viewWithTag: PREFERENCE_VALUE_TAG];
        [preferenceLabel setStringValue: name.toNSString()];
        [preferenceToggledButton setHidden:YES];
        
        if (type == "Switch") {
            NSSwitch* preferenceToggledButton = [preferenceCell viewWithTag: PREFERENCE_VALUE_TAG];
            
            [preferenceToggledButton setHidden:NO];
            [preferenceToggledButton setState:value == "1"];
            [preferenceToggledButton setAction:@selector(setPreference:)];
        } else if (type == "EditText") {
            preferenceCell = [tableView makeViewWithIdentifier:@"TableCellPreferenceEditTextItem" owner:self];
            NSTextField* preferenceLabel = [preferenceCell viewWithTag: PREFERENCE_NAME_TAG];
            NSTextField* preferenceText = [preferenceCell viewWithTag: PREFERENCE_VALUE_TAG];
            
            [preferenceLabel setStringValue: name.toNSString()];
            [preferenceText setHidden:NO];
            [preferenceText setEditable:YES];
            [preferenceText setStringValue:value.toNSString()];
            [preferenceText setAction:@selector(setPreference:)];
        } else if (type == "List") {
            preferenceCell = [tableView makeViewWithIdentifier:@"TableCellPreferenceListItem" owner:self];
            NSTextField* preferenceLabel = [preferenceCell viewWithTag: PREFERENCE_NAME_TAG];
            NSPopUpButton* listButton = [preferenceCell viewWithTag: PREFERENCE_VALUE_TAG];
            auto entries = fullPrefs[row]["entries"].split(",");
            auto entryValues = fullPrefs[row]["entryValues"].split(",");
            auto currentEntry = entryValues.indexOf(value);
            
            [preferenceLabel setStringValue: name.toNSString()];
            [listButton setHidden:NO];
            [listButton removeAllItems];
            for (const auto& value : entries) {
                [listButton addItemWithTitle:value.toNSString()];
            }
            [listButton selectItemWithTitle:entries[currentEntry].toNSString()];
            [listButton setAction:@selector(setPreference:)];
        } else if (type == "Path") {
            preferenceCell = [tableView makeViewWithIdentifier:@"TableCellPreferencePathItem" owner:self];
            NSTextField* preferenceLabel = [preferenceCell viewWithTag: PREFERENCE_NAME_TAG];
            NSButton* pathButton = [preferenceCell viewWithTag: PREFERENCE_VALUE_TAG];
            
            
            [preferenceLabel setStringValue: name.toNSString()];
            [pathButton setHidden:NO];
            [pathButton setTitle: [value.toNSString() lastPathComponent]];
        }
        
        return preferenceCell;
    }
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
    if (tableView == installedPluginsView)
        return self.pluginModel->getInstalledPlugins().size();
    else if (tableView == preferencesListView) {
        if (lastPluginName.isEmpty())
            return 0;
        return pluginModel->getPluginPreferencesValues(lastPluginName).size();
    }
}
@end
