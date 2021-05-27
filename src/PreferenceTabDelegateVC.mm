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

#import "PreferenceTabDelegateVC.h"

#import <api/pluginmodel.h>

@interface PreferenceTabDelegateVC ()
@property (unsafe_unretained) IBOutlet NSTableView *preferencesListView;
@property (assign) IBOutlet NSLayoutConstraint* tableHeightConstraint;
@property QString category;
@property QString currentPluginName;
@property VectorMapStringString fullPreferences;
@end

@implementation PreferenceTabDelegateVC
@synthesize pluginModel;
@synthesize category, currentPluginName, preferencesListView, fullPreferences;

NSInteger NAME_TAG = 100;
NSInteger VALUE_TAG = 200;
CGFloat ROW_HEIGHT = 33;

- (void) setup:(QString)pluginName category:(QString)category {
    if (@available(macOS 11.0, *)) {
        preferencesListView.style = NSTableViewStylePlain;
    }
    self.currentPluginName = pluginName;
    self.category = category;

    auto fullPrefs = pluginModel->getPluginPreferences(self.currentPluginName);
    for (auto it = fullPrefs.begin(); it != fullPrefs.end();) {
        if ((*it)["category"] == self.category)
            it++;
        else
            fullPrefs.erase(it);
    }
    self.fullPreferences = fullPrefs;
    self.tableHeightConstraint.constant = self.fullPreferences.size() * ROW_HEIGHT + 15;
    [self.preferencesListView reloadData];
}

-(void)update{
    self.tableHeightConstraint.constant = self.fullPreferences.size() * ROW_HEIGHT + 15;
    [self.preferencesListView reloadData];
}

#pragma mark - actions

- (IBAction)setPreference:(id)sender {
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
        NSButton* button = [rowView viewWithTag:VALUE_TAG];
        QString value = [button state] ? "1" : "0";
        pluginModel->setPluginPreference(self.currentPluginName, key, value);
    } else if (type == "EditText") {
        auto* rowView = [self.preferencesListView rowViewAtRow:row makeIfNecessary:NO];
        NSTextField* text = [rowView viewWithTag:VALUE_TAG];
        QString value =  QString::fromNSString([text stringValue]);
        pluginModel->setPluginPreference(self.currentPluginName, key, value);
    } else if (type == "List") {
        auto* rowView = [self.preferencesListView rowViewAtRow:row makeIfNecessary:NO];
        NSPopUpButton* button = [rowView viewWithTag:VALUE_TAG];
        auto entries = self.fullPreferences[row]["entries"].split(",");
        auto entryValues = self.fullPreferences[row]["entryValues"].split(",");
        QString value = QString::fromNSString([[button selectedItem] title]);
        auto newEntry = entries.indexOf(value);
        pluginModel->setPluginPreference(self.currentPluginName, key, entryValues[newEntry]);
    } else if (type == "Path") {
        auto* rowView = [self.preferencesListView rowViewAtRow:row makeIfNecessary:NO];
        NSButton* button = [rowView viewWithTag:VALUE_TAG];
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

#pragma mark - NSTableViewDelegate methods

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    auto valuesPrefs = pluginModel->getPluginPreferencesValues(self.currentPluginName);

    QString name = self.fullPreferences[row]["title"];
    QString key = self.fullPreferences[row]["key"];
    QString type = self.fullPreferences[row]["type"];
    QString value = valuesPrefs[key];

    NSTableCellView* preferenceCell = [tableView makeViewWithIdentifier:@"TableCellPreferenceSwitchItem" owner:self];
    NSTextField* preferenceLabel = [preferenceCell viewWithTag: NAME_TAG];
    NSSwitch* preferenceToggledButton = [preferenceCell viewWithTag: VALUE_TAG];
    [preferenceLabel setStringValue: name.toNSString()];
    [preferenceToggledButton setHidden:YES];

    if (type == "Switch") {
        NSSwitch* preferenceToggledButton = [preferenceCell viewWithTag: VALUE_TAG];

        [preferenceToggledButton setHidden:NO];
        [preferenceToggledButton setState:value == "1"];
        [preferenceToggledButton setAction:@selector(setPreference:)];
    } else if (type == "EditText") {
        preferenceCell = [tableView makeViewWithIdentifier:@"TableCellPreferenceEditTextItem" owner:self];
        NSTextField* preferenceLabel = [preferenceCell viewWithTag: NAME_TAG];
        NSTextField* preferenceText = [preferenceCell viewWithTag: VALUE_TAG];

        [preferenceLabel setStringValue: name.toNSString()];
        [preferenceText setHidden:NO];
        [preferenceText setEditable:YES];
        [preferenceText setStringValue:value.toNSString()];
        [preferenceText setAction:@selector(setPreference:)];
    } else if (type == "List") {
        preferenceCell = [tableView makeViewWithIdentifier:@"TableCellPreferenceListItem" owner:self];
        NSTextField* preferenceLabel = [preferenceCell viewWithTag: NAME_TAG];
        NSPopUpButton* listButton = [preferenceCell viewWithTag: VALUE_TAG];
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
        NSTextField* preferenceLabel = [preferenceCell viewWithTag: NAME_TAG];
        NSButton* pathButton = [preferenceCell viewWithTag: VALUE_TAG];

        [preferenceLabel setStringValue: name.toNSString()];
        [pathButton setHidden:NO];
        [pathButton setTitle: [value.toNSString() lastPathComponent]];
    }

    return preferenceCell;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    return ROW_HEIGHT;
}

#pragma mark - NSTableViewDataSource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (self.currentPluginName.isEmpty())
        return 0;
    return self.fullPreferences.size();
}

@end
