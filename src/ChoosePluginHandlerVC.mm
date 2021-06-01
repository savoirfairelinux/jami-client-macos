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

#import "ChoosePluginHandlerVC.h"
#import "views/RingTableView.h"
#import "views/HoverTableRowView.h"
#import "utils.h"

//LRC
#import <api/pluginmodel.h>

@interface ChoosePluginHandlerVC () {
    __unsafe_unretained IBOutlet RingTableView* pluginHandlersView;
    __unsafe_unretained IBOutlet NSLayoutConstraint* tableHeightConstraint;
    __unsafe_unretained IBOutlet NSLayoutConstraint* tableWidthConstraint;
}

@end

@implementation ChoosePluginHandlerVC

@synthesize pluginModel;
PluginPickerType handlerType;

QString currentCall;
QString currentPeerID;
QString currentAccount;
QVector<QString> availableHandlers;
QVector<QString> activeHandlers;

// Tags for views
NSInteger const ICON_TAG           = 100;
NSInteger const HANDLER_NAME_TAG   = 200;
NSInteger const HANDLER_STATUS_TAG = 300;
CGFloat PLUGIN_ROW_HEIGHT = 35;

- (void) reloadView
{
    [pluginHandlersView reloadData];
    [self updateConstrains];
}

-(void)viewDidLoad {
    [super viewDidLoad];
    if (@available(macOS 11.0, *)) {
        pluginHandlersView.style = NSTableViewStylePlain;
    }
    [self reloadView];
}

-(void)updateConstrains {
    CGFloat tableHeight = PLUGIN_ROW_HEIGHT * availableHandlers.size();
    CGFloat tableWidth = [self getTableWidth] + 180;
    tableHeightConstraint.constant = tableHeight;
    tableWidthConstraint.constant = tableWidth;
}

-(CGFloat)getTableWidth {
    NSTextField* textField = [[NSTextField alloc] init];
    CGFloat maxWidth = 0;
    NSFont *fontName = [NSFont systemFontOfSize: 13.0 weight: NSFontWeightMedium];
    NSDictionary *attrs= [NSDictionary dictionaryWithObjectsAndKeys:
                               fontName, NSFontAttributeName,
                               nil];
    for (auto handler : availableHandlers) {
        lrc::api::plugin::PluginHandlerDetails handlerDetails;
        if (handlerType == FROM_CALL)
            handlerDetails = pluginModel->getCallMediaHandlerDetails(handler);
        else
            handlerDetails = pluginModel->getChatHandlerDetails(handler);
        NSAttributedString* attributed = [[NSAttributedString alloc] initWithString:handlerDetails.name.toNSString() attributes: attrs];
        textField.attributedStringValue = attributed;
        [textField sizeToFit];
        if (textField.frame.size.width > maxWidth) {
            maxWidth = textField.frame.size.width;
        }
    }
    return maxWidth;
}

-(void)setupForCall:(const QString&)callID {
    handlerType = FROM_CALL;
    if (pluginModel == nil) {
        return;
    }

    currentCall = callID;

    availableHandlers = pluginModel->getCallMediaHandlers();
    activeHandlers = pluginModel->getCallMediaHandlerStatus(currentCall);
    [self reloadView];
}

-(void)setupForChat:(const QString&)convID accountID:(const QString&)accountID {
    handlerType = FROM_CHAT;
    if (pluginModel == nil) {
        return;
    }

    currentPeerID = convID;
    currentAccount = accountID;

    availableHandlers = pluginModel->getChatHandlers();
    activeHandlers = pluginModel->getChatHandlerStatus(currentAccount, currentPeerID);
    [self reloadView];
}

-(void)updateHandlerStatus:(NSInteger)row {
    if (handlerType == FROM_CALL)
        activeHandlers = pluginModel->getCallMediaHandlerStatus(currentCall);
    else
        activeHandlers = pluginModel->getChatHandlerStatus(currentAccount, currentPeerID);
    NSIndexSet* rowsToUpdate = [[NSIndexSet alloc] initWithIndex:row];
    NSIndexSet* colsToUpdate = [[NSIndexSet alloc] initWithIndex:0];
    [pluginHandlersView reloadDataForRowIndexes:rowsToUpdate columnIndexes:colsToUpdate];
}

#pragma mark - IBAction

-(IBAction)toggleHandler:(id)sender
{
    NSInteger row = [pluginHandlersView rowForView:sender];
    if(row < 0) {
        return;
    }

    bool toggle = [sender state];

    if (handlerType == FROM_CALL)
        pluginModel->toggleCallMediaHandler(availableHandlers[row], currentCall, toggle);
    else
        pluginModel->toggleChatHandler(availableHandlers[row], currentAccount, currentPeerID, toggle);
    [self updateHandlerStatus:row];
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
    if (tableView != pluginHandlersView || row < 0 ||  row >= availableHandlers.size()) {
        return nil;
    }
    NSTableCellView* handlerCell = [tableView makeViewWithIdentifier:@"MainCell" owner:tableView];

    NSTextField* pluginHandlerName = [handlerCell viewWithTag:HANDLER_NAME_TAG];
    NSImageView* iconView = [handlerCell viewWithTag:ICON_TAG];
    NSSwitch* handlerStatusView = [handlerCell viewWithTag:HANDLER_STATUS_TAG];
    auto handler = availableHandlers[row];

    auto handlerStatus = false;
    lrc::api::plugin::PluginHandlerDetails handlerDetails;
    if (handlerType == FROM_CALL)
        handlerDetails = pluginModel->getCallMediaHandlerDetails(handler);
    else
        handlerDetails = pluginModel->getChatHandlerDetails(handler);

    for (const auto& item : activeHandlers) {
        if (item == handler) {
            handlerStatus = true;
            break;
        }
    }

    [handlerStatusView setState:handlerStatus];
    [handlerStatusView setAction:@selector(toggleHandler:)];
    if (handlerDetails.iconPath.endsWith(".svg")) {
        handlerDetails.iconPath.replace(".svg", ".png");
    }
    NSString* pathIcon = handlerDetails.iconPath.toNSString();
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:pathIcon];
    if (image)
        [iconView setImage: image];
    [pluginHandlerName setStringValue: handlerDetails.name.toNSString()];
    return handlerCell;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    return PLUGIN_ROW_HEIGHT;
}

#pragma mark - NSTableDataSource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return availableHandlers.size();
}

@end
