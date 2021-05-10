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
#import "PluginItemDelegateVC.h"
#import "AppDelegate.h"

#import <QuartzCore/QuartzCore.h>

#import <api/pluginmodel.h>

#import "views/PluginPreferenceTab.h"


@interface PluginItemDelegateVC ()
@property (unsafe_unretained) IBOutlet NSSwitch *loadButton;
@property (unsafe_unretained) IBOutlet NSTextField *pluginNameLabel;
@property (unsafe_unretained) IBOutlet NSImageView *pluginIcon;
@property (unsafe_unretained) IBOutlet NSButton *disclosureButton;
@property (unsafe_unretained) IBOutlet NSStackView *hidableView;
@property (unsafe_unretained) IBOutlet NSTabView *tabView;
@property (unsafe_unretained) IBOutlet NSTableView *preferencesListView;
@property (unsafe_unretained) IBOutlet NSButton *reset;
@property (unsafe_unretained) IBOutlet NSButton *uninstall;
@property VectorMapStringString fullPreferences;
@property NSInteger outerrow;
@property QString currentPluginName;
@property PluginItemDelegateCallBacks callbacks;
@end

@implementation PluginItemDelegateVC
@synthesize pluginModel;
@synthesize hidableView, tabView, disclosureButton, loadButton, pluginNameLabel, pluginIcon, callbacks, fullPreferences;

NSInteger PREFERENCE_NAME_TAG = 100;
NSInteger PREFERENCE_VALUE_TAG = 200;

-(void) setup:(QString)pluginName row:(NSInteger)row callbacks:(PluginItemDelegateCallBacks) callbacks{
    self.currentPluginName = pluginName;
    self.outerrow = row;
    self.callbacks = callbacks;
    
    auto details = self.pluginModel->getPluginDetails(self.currentPluginName);
    if (details.iconPath.endsWith(".svg")) {
        details.iconPath.replace(".svg", ".png");
    }
    NSString* pathIcon = details.iconPath.toNSString();
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:pathIcon];
    [pluginIcon setImage: image];
    [pluginNameLabel setStringValue: details.name.toNSString()];
    [loadButton setState: details.loaded];
    [self.disclosureButton setState:NSControlStateValueOff];
    [self.hidableView setHidden:YES];

    auto fullPrefs = pluginModel->getPluginPreferences(self.currentPluginName);
    QSet<QString> categories;
    for (const auto& item : fullPrefs) {
        auto currentCategory = item["category"];
        if (!currentCategory.isEmpty())
            categories.insert(currentCategory);
    }

    if (categories.size() <= 1) {
        self.fullPreferences = fullPrefs;
        [self.tabView setHidden:YES];
    } else {
        [self.tabView setHidden:NO];
        if ([self.tabView numberOfTabViewItems] == 0) {
            for (const auto item : categories) {
                PluginPreferenceTab* newTab = [[PluginPreferenceTab alloc] init];
                [newTab setLabel: item.toNSString()];
                [newTab awakeFromNib];
                [newTab.viewController setup: self.currentPluginName category:item];
                [self.tabView addTabViewItem:newTab];
            }
        }
        for (auto it = fullPrefs.begin(); it != fullPrefs.end();) {
            if ((*it)["category"].isEmpty())
                it++;
            else
                fullPrefs.erase(it);
        }
        self.fullPreferences = fullPrefs;
    }
    [self.preferencesListView reloadData];
}

#pragma mark - actions

- (IBAction)loadPlugin:(id)sender
{
    if (loadButton.state == NSControlStateValueOff) {
        self.pluginModel->unloadPlugin(self.currentPluginName);
    } else
        self.pluginModel->loadPlugin(self.currentPluginName);
    self.pluginModel->chatHandlerStatusUpdated(false);
    auto details = self.pluginModel->getPluginDetails(self.currentPluginName);
    [loadButton setState:details.loaded];
}

- (IBAction)uninstallPlugin:(id)sender
{
    CallBackInfos currentPluginInfos;
    currentPluginInfos.row = self.outerrow;
    currentPluginInfos.name = self.currentPluginName;
    
    self.callbacks.uninstall(currentPluginInfos);
}

- (IBAction)resetPlugin:(id)sender
{
    self.pluginModel->resetPluginPreferencesValues(self.currentPluginName);
    [self.preferencesListView reloadData];
    auto tabs = [self.tabView tabViewItems];
    for (auto tab : tabs) {
        auto test = reinterpret_cast<PluginPreferenceTab*>(tab);
        [test.viewController update];
    }
}

-(IBAction)setPreference:(id)sender {
    NSInteger row = [self.preferencesListView rowForView:sender];
    if(row < 0) {
        return;
    }

    auto valuesPrefs = pluginModel->getPluginPreferencesValues(self.currentPluginName);
    
    QString name = self.fullPreferences[row]["title"];
    QString key = self.fullPreferences[row]["key"];
    QString type = self.fullPreferences[row]["type"];
    
    if (type == "Switch") {
        auto* rowView = [self.preferencesListView rowViewAtRow:row makeIfNecessary:NO];
        NSButton* button = [rowView viewWithTag:PREFERENCE_VALUE_TAG];
        QString value = [button state] ? "1" : "0";
        pluginModel->setPluginPreference(self.currentPluginName, key, value);
    } else if (type == "EditText") {
        auto* rowView = [self.preferencesListView rowViewAtRow:row makeIfNecessary:NO];
        NSTextField* text = [rowView viewWithTag:PREFERENCE_VALUE_TAG];
        QString value =  QString::fromNSString([text stringValue]);
        pluginModel->setPluginPreference(self.currentPluginName, key, value);
    } else if (type == "List") {
        auto* rowView = [self.preferencesListView rowViewAtRow:row makeIfNecessary:NO];
        NSPopUpButton* button = [rowView viewWithTag:PREFERENCE_VALUE_TAG];
        auto entries = self.fullPreferences[row]["entries"].split(",");
        auto entryValues = self.fullPreferences[row]["entryValues"].split(",");
        QString value = QString::fromNSString([[button selectedItem] title]);
        auto newEntry = entries.indexOf(value);
        pluginModel->setPluginPreference(self.currentPluginName, key, entryValues[newEntry]);
    } else if (type == "Path") {
        auto* rowView = [self.preferencesListView rowViewAtRow:row makeIfNecessary:NO];
        NSButton* button = [rowView viewWithTag:PREFERENCE_VALUE_TAG];
        NSOpenPanel *panel = [NSOpenPanel openPanel];
        [panel setAllowsMultipleSelection:NO];
        [panel setCanChooseDirectories:NO];
        [panel setCanChooseFiles:YES];
        
        auto mimeTypes = self.fullPreferences[row]["mimeType"].split(",");
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
        
        pluginModel->setPluginPreference(self.currentPluginName, key, QString::fromNSString(path));
        [button setTitle: [path lastPathComponent]];
    }
}

- (IBAction)showPreferences:(id)sender {
    [self.hidableView setHidden: !self.hidableView.isHidden ];
}

#pragma mark - NSOpenSavePanelDelegate delegate methods

- (BOOL) panel:(id)sender shouldEnableURL:(NSURL*)url {
    return YES;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    auto valuesPrefs = pluginModel->getPluginPreferencesValues(self.currentPluginName);
    
    QString name = self.fullPreferences[row]["title"];
    QString key = self.fullPreferences[row]["key"];
    QString type = self.fullPreferences[row]["type"];
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
        auto entries = self.fullPreferences[row]["entries"].split(",");
        auto entryValues = self.fullPreferences[row]["entryValues"].split(",");
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

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    if(![tableView isEnabled]) {
        return nil;
    }
    return [tableView makeViewWithIdentifier:@"HoverRowView" owner:nil];
}

#pragma mark - NSTableViewDataSource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (self.currentPluginName.isEmpty())
        return 0;
    return self.fullPreferences.size();
}
@end
