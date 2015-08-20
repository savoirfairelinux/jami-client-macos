/*
 *  Copyright (C) 2015 Savoir-faire Linux Inc.
 *  Author: Alexandre Lision <alexandre.lision@savoirfairelinux.com>
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

#import "SmartViewVC.h"

//Qt
#import <QtMacExtras/qmacfunctions.h>
#import <QPixmap>
#import <QIdentityProxyModel>
#import <QItemSelectionModel>

//LRC
#import <recentmodel.h>
#import <callmodel.h>
#import <call.h>
#import <person.h>
#import <contactmethod.h>
#import <globalinstances.h>

#import "QNSTreeController.h"
#import "delegates/ImageManipulationDelegate.h"

#define COLUMNID_MAIN @"MainColumn"	// the single column name in our outline view

// Tags for views
#define IMAGE_TAG 100
#define DISPLAYNAME_TAG 200
#define DETAILS_TAG 300
#define CALL_BUTTON_TAG 400
#define TXT_BUTTON_TAG 500

@interface SmartViewVC () <NSOutlineViewDelegate> {
    BOOL isShowingContacts;
    QNSTreeController *treeController;

    //UI elements
    __unsafe_unretained IBOutlet NSOutlineView *smartView;
    __unsafe_unretained IBOutlet NSSearchField *searchField;
    __unsafe_unretained IBOutlet NSButton *showContactsButton;
    __unsafe_unretained IBOutlet NSButton *showHistoryButton;
    __unsafe_unretained IBOutlet NSTabView *tabbar;
}

@end

@implementation SmartViewVC

- (void)awakeFromNib
{
    NSLog(@"INIT SmartView VC");

    isShowingContacts = false;
    treeController = [[QNSTreeController alloc] initWithQModel:RecentModel::instance()];

    [treeController setAvoidsEmptySelection:NO];
    [treeController setChildrenKeyPath:@"children"];

    [smartView bind:@"content" toObject:treeController withKeyPath:@"arrangedObjects" options:nil];
    [smartView bind:@"sortDescriptors" toObject:treeController withKeyPath:@"sortDescriptors" options:nil];
    [smartView bind:@"selectionIndexPaths" toObject:treeController withKeyPath:@"selectionIndexPaths" options:nil];
    [smartView setTarget:self];
    [smartView setDoubleAction:@selector(placeCall:)];

    [self.view setWantsLayer:YES];
    [self.view setLayer:[CALayer layer]];
    [self.view.layer setBackgroundColor:[NSColor whiteColor].CGColor];

    [searchField setWantsLayer:YES];
    [searchField setLayer:[CALayer layer]];
    [searchField.layer setBackgroundColor:[NSColor colorWithCalibratedRed:0.949 green:0.949 blue:0.949 alpha:0.9].CGColor];
}

- (void)placeCall:(id)sender
{
    QModelIndex qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
    ContactMethod* m = nil;

    // Double click on an ongoing call
    if (qIdx.parent().isValid()) {
        return;
    }

    if([[treeController selectedNodes] count] > 0) {
        QVariant var = qIdx.data((int)Call::Role::ContactMethod);
        m = qvariant_cast<ContactMethod*>(var);
        if (!m) {
            // test if it is a person
            QVariant var = qIdx.data((int)Person::Role::Object);
            if (var.isValid()) {
                Person *c = var.value<Person*>();
                if (c->phoneNumbers().size() > 0) {
                    m = c->phoneNumbers().first();
                }
            }
        }
    }

    // Before calling check if we properly extracted a contact method and that
    // there is NOT already an ongoing call for this index (e.g: no children for this node)
    if(m && !RecentModel::instance()->index(0, 0, qIdx).isValid()){
        Call* c = CallModel::instance()->dialingCall();
        c->setPeerContactMethod(m);
        c->setDialNumber(m->uri());
        c->setAccount(m->account());
        c << Call::Action::ACCEPT;

        [smartView selectRowIndexes:[[NSIndexSet alloc] initWithIndex:1] byExtendingSelection:NO];
    }
}

- (IBAction)showHistory:(NSButton*)sender {
    if (isShowingContacts) {
        [showContactsButton setState:NO];
        isShowingContacts = NO;
        [tabbar selectTabViewItemAtIndex:1];
    } else if ([sender state] == NSOffState) {
        [tabbar selectTabViewItemAtIndex:0];
    } else {
        [tabbar selectTabViewItemAtIndex:1];
    }
}

- (IBAction)showContacts:(NSButton*)sender {
    if (isShowingContacts) {
        [showContactsButton setState:NO];
        [tabbar selectTabViewItemAtIndex:0];
    } else {
        [showHistoryButton setState:![sender state]];
        [tabbar selectTabViewItemAtIndex:2];
    }

    isShowingContacts = [sender state];
}

#pragma mark - NSOutlineViewDelegate methods

// -------------------------------------------------------------------------------
//	shouldSelectItem:item
// -------------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item;
{
    return YES;
}

// -------------------------------------------------------------------------------
//	shouldEditTableColumn:tableColumn:item
//
//	Decide to allow the edit of the given outline view "item".
// -------------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    return NO;
}


// -------------------------------------------------------------------------------
//	outlineViewSelectionDidChange:notification
// -------------------------------------------------------------------------------
- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    if ([treeController selectedNodes].count <= 0) {
        CallModel::instance()->selectionModel()->clearCurrentIndex();
        return;
    }

    QModelIndex qIdx = [treeController toQIdx:[treeController selectedNodes][0]];

    // ask the tree controller for the current selection
    if(qIdx.parent().isValid()) {
        auto selected = RecentModel::instance()->getActiveCall(qIdx.parent());
        if (selected) {
            CallModel::instance()->selectCall(selected);
        }
    } else {
        CallModel::instance()->selectionModel()->clearCurrentIndex();
    }
}

/* View Based OutlineView: See the delegate method -tableView:viewForTableColumn:row: in NSTableView.
 */
- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    NSTableCellView *result;
    if (!qIdx.parent().isValid()) {
        result = [outlineView makeViewWithIdentifier:@"MainCell" owner:outlineView];
        NSTextField* details = [result viewWithTag:DETAILS_TAG];

        [details setStringValue:qIdx.data((int)Person::Role::FormattedLastUsed).toString().toNSString()];
    } else {
        result = [outlineView makeViewWithIdentifier:@"CallCell" owner:outlineView];
        NSTextField* details = [result viewWithTag:DETAILS_TAG];

        [details setStringValue:qIdx.data((int)Call::Role::HumanStateName).toString().toNSString()];
    }
    BOOL ongoing = RecentModel::instance()->hasActiveCall(qIdx);

    [[result viewWithTag:CALL_BUTTON_TAG] setHidden:ongoing];


    NSTextField* displayName = [result viewWithTag:DISPLAYNAME_TAG];
    [displayName setStringValue:qIdx.data(Qt::DisplayRole).toString().toNSString()];
    NSImageView* photoView = [result viewWithTag:IMAGE_TAG];
    Person* p = qvariant_cast<Person*>(qIdx.data((int)Person::Role::Object));
    QVariant photo = GlobalInstances::pixmapManipulator().contactPhoto(p, QSize(35,35));
    [photoView setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(photo))];
    return result;
}

- (IBAction)callClickedAtRow:(id)sender {
    NSInteger row = [smartView rowForView:sender];
    [smartView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [self placeCall:nil];
}

- (IBAction)hangUpClickedAtRow:(id)sender {
    NSInteger row = [smartView rowForView:sender];
    [smartView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    CallModel::instance()->getCall(CallModel::instance()->selectionModel()->currentIndex()) << Call::Action::REFUSE;
}

/* View Based OutlineView: See the delegate method -tableView:rowViewForRow: in NSTableView.

- (NSTableRowView *)outlineView:(NSOutlineView *)outlineView rowViewForItem:(id)item
{

}
 */

/* View Based OutlineView: This delegate method can be used to know when a new 'rowView' has been added to the table. At this point, you can choose to add in extra views, or modify any properties on 'rowView'.
 */
- (void)outlineView:(NSOutlineView *)outlineView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{

}

/* View Based OutlineView: This delegate method can be used to know when 'rowView' has been removed from the table. The removed 'rowView' may be reused by the table so any additionally inserted views should be removed at this point. A 'row' parameter is included. 'row' will be '-1' for rows that are being deleted from the table and no longer have a valid row, otherwise it will be the valid row that is being removed due to it being moved off screen.
 */
- (void)outlineView:(NSOutlineView *)outlineView didRemoveRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{

}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    return (((NSTreeNode*)item).indexPath.length == 1) ? 60.0 : 45.0;
}

- (void) placeCallFromSearchField
{
    Call* c = CallModel::instance()->dialingCall();
    // check for a valid ring hash
    NSCharacterSet *hexSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
    BOOL valid = [[[searchField stringValue] stringByTrimmingCharactersInSet:hexSet] isEqualToString:@""];

    if(valid && searchField.stringValue.length == 40) {
        c->setDialNumber(QString::fromNSString([NSString stringWithFormat:@"ring:%@",[searchField stringValue]]));
    } else {
        c->setDialNumber(QString::fromNSString([searchField stringValue]));
    }

    c << Call::Action::ACCEPT;
}


#pragma NSTextField Delegate

- (BOOL)control:(NSControl *)control textView:(NSTextView *)fieldEditor doCommandBySelector:(SEL)commandSelector
{
    if (commandSelector == @selector(insertNewline:)) {
        if([[searchField stringValue] isNotEqualTo:@""]) {
            [self placeCallFromSearchField];
            return YES;
        }
    }

    return NO;
}

@end
