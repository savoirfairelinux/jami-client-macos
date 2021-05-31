/*
 *  Copyright (C) 2021 Savoir-faire Linux Inc.
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

#import "ChooseMediaVC.h"
#import "views/RingTableView.h"
#import "views/HoverTableRowView.h"
#import "views/NSColor+RingTheme.h"

@interface ChooseMediaVC () {
    __unsafe_unretained IBOutlet RingTableView* devicesView;
    __unsafe_unretained IBOutlet NSLayoutConstraint* tableHeightConstraint;
    __unsafe_unretained IBOutlet NSLayoutConstraint* tableWidthConstraint;
}

@end

@implementation ChooseMediaVC

QVector<QString> mediaDevices;
QString defaultDevice;
NSInteger MEDIA_NAME_TAG = 100;
NSInteger CURRENT_SELECTION_TAG = 200;
CGFloat ROW_HEIGHT = 35;

-(void)setMediaDevices:(const QVector<QString>&)devices andDefaultDevice:(const QString&)device {
    mediaDevices = devices;
    defaultDevice = device;
    CGFloat tableHeight = ROW_HEIGHT * mediaDevices.size();
}

-(CGFloat)getTableWidth {
    NSTextField* textField = [[NSTextField alloc] init];
    CGFloat maxWidth = 0;
    NSFont *fontName = [NSFont systemFontOfSize: 13.0 weight: NSFontWeightMedium];
    NSDictionary *attrs= [NSDictionary dictionaryWithObjectsAndKeys:
                               fontName, NSFontAttributeName,
                               nil];
    for (auto device : mediaDevices) {
        NSAttributedString* attributed = [[NSAttributedString alloc] initWithString:device.toNSString() attributes: attrs];
        textField.attributedStringValue = attributed;
        [textField sizeToFit];
        if (textField.frame.size.width > maxWidth) {
            maxWidth = textField.frame.size.width;
        }
    }
    return maxWidth;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (@available(macOS 11.0, *)) {
        devicesView.style = NSTableViewStylePlain;
    }
    CGFloat tableHeight = ROW_HEIGHT * mediaDevices.size();
    // we do not need space for check mark  for default device
    auto margins = defaultDevice.isEmpty() ? 20 : 50;
    CGFloat tableWidth = [self getTableWidth] + margins;
    tableHeightConstraint.constant = tableHeight;
    tableWidthConstraint.constant = tableWidth;
}
#pragma mark - NSTableViewDelegate methods

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    HoverTableRowView *howerRow = [tableView makeViewWithIdentifier:@"HoverRowView" owner:nil];
    [howerRow setBlurType:7];
    return howerRow;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSTableCellView* result = [tableView makeViewWithIdentifier:@"MediaDeviceCell" owner:tableView];
    NSTextField* mediaName = [result viewWithTag: MEDIA_NAME_TAG];
    NSImageView* currentSelection = [result viewWithTag: CURRENT_SELECTION_TAG];
    NSStackView* container = [currentSelection superview];
    container.detachesHiddenViews = defaultDevice.isEmpty();
    mediaName.stringValue = mediaDevices[row].toNSString();
    currentSelection.hidden = mediaDevices[row] != defaultDevice;
    NSImage* image =  [NSColor image: currentSelection.image tintedWithColor: [NSColor textColor]];
    currentSelection.image = image;
    return result;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger row = [notification.object selectedRow];
    self.onDeviceSelected(mediaDevices[row].toNSString(), row);
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    return ROW_HEIGHT;
}

#pragma mark - NSTableDataSource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return mediaDevices.size();
}

@end
