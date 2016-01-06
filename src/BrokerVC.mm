/*
 *  Copyright (C) 2015-2016 Savoir-faire Linux Inc.
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

#import "BrokerVC.h"

#import <QSortFilterProxyModel>
#import <QItemSelectionModel>
#import <QtMacExtras/qmacfunctions.h>
#import <QPixmap>
#import <QMimeData>

//LRC
#import <recentmodel.h>
#import <callmodel.h>
#import <call.h>
#import <person.h>
#import <globalinstances.h>
#import <contactmethod.h>
#import <phonedirectorymodel.h>

#import "QNSTreeController.h"
#import "delegates/ImageManipulationDelegate.h"

// Display all items from peopleproxy() except current call
class NotCurrentItemModel : public QSortFilterProxyModel
{
public:
    NotCurrentItemModel(QSortFilterProxyModel* parent) : QSortFilterProxyModel(parent)
    {
        setSourceModel(parent);
    }

    virtual bool filterAcceptsRow(int source_row, const QModelIndex& source_parent) const
    {
        auto originIdx = ((QSortFilterProxyModel*)sourceModel())->mapToSource(sourceModel()->index(source_row,0,source_parent));
        auto c = RecentModel::instance().getActiveCall(originIdx);

        return (!c || (c && (c->state() != Call::State::CURRENT))) &&
                QSortFilterProxyModel::filterAcceptsRow(source_row, source_parent);
    }
};
@interface BrokerVC ()

@property BrokerMode mode;
@property (unsafe_unretained) IBOutlet NSOutlineView *smartView;
@property (strong) QNSTreeController *treeController;
@property QSortFilterProxyModel* recentFilterModel;

@end

@implementation BrokerVC

// Tags for views
NSInteger const IMAGE_TAG       =   100;
NSInteger const DISPLAYNAME_TAG =   200;
NSInteger const DETAILS_TAG     =   300;
NSInteger const CALL_BUTTON_TAG =   400;
NSInteger const TXT_BUTTON_TAG  =   500;

- (instancetype)initWithMode:(BrokerMode)m {
    self = [super init];
    if (self) {
        [self setMode:m];
    }
    return self;
}

- (NSString *)nibName
{
    return @"Broker";
}

- (void)dealloc
{
    delete _recentFilterModel;
}

- (void)loadView
{
    [super loadView];
    _recentFilterModel = new NotCurrentItemModel(RecentModel::instance().peopleProxy());
    _treeController = [[QNSTreeController alloc] initWithQModel:_recentFilterModel];

    [_treeController setAvoidsEmptySelection:NO];
    [_treeController setChildrenKeyPath:@"children"];

    [_smartView bind:@"content" toObject:_treeController withKeyPath:@"arrangedObjects" options:nil];
    [_smartView bind:@"sortDescriptors" toObject:_treeController withKeyPath:@"sortDescriptors" options:nil];
    [_smartView bind:@"selectionIndexPaths" toObject:_treeController withKeyPath:@"selectionIndexPaths" options:nil];
    [_smartView setTarget:self];

    if ([self mode] == BrokerMode::TRANSFER) {
        [_smartView setDoubleAction:@selector(placeTransfer:)];
    } else {
        [_smartView setDoubleAction:@selector(addParticipant:)];
    }

}

// -------------------------------------------------------------------------------
// transfer on click on Person or ContactMethod
// -------------------------------------------------------------------------------
- (void)placeTransfer:(id)sender
{
    auto current = CallModel::instance().selectedCall();

    if (!current || [_treeController selectedNodes].count == 0)
        return;

    QModelIndex qIdx = [_treeController toQIdx:[_treeController selectedNodes][0]];
    auto originIdx = RecentModel::instance().peopleProxy()->mapToSource(_recentFilterModel->mapToSource(qIdx));

    auto transfer = RecentModel::instance().getActiveCall(originIdx);
    if (transfer) { //realise an attended transfer between the two calls
        CallModel::instance().attendedTransfer(current, transfer);
        return;
    }

    ContactMethod* m = nil;
    auto contactmethods = RecentModel::instance().getContactMethods(originIdx);
    if (contactmethods.size() > 0) { // Before calling check if we properly extracted at least one contact method
        m = contactmethods.first();
        CallModel::instance().transfer(current, m);
    }
}

// -------------------------------------------------------------------------------
// transfer to unknown URI
// -------------------------------------------------------------------------------
- (void) transferTo:(NSString*) uri
{
    auto current = CallModel::instance().selectedCall();
    if (!current)
        return;
    auto number = PhoneDirectoryModel::instance().getNumber(QString::fromNSString(uri));
    CallModel::instance().transfer(current, number);
}

// -------------------------------------------------------------------------------
// place a call to the future participant on click on Person or ContactMethod
// -------------------------------------------------------------------------------
- (void)addParticipant:(id)sender
{
    auto current = CallModel::instance().selectedCall();

    if (!current || [_treeController selectedNodes].count == 0)
        return;

    QModelIndex qIdx = [_treeController toQIdx:[_treeController selectedNodes][0]];
    auto originIdx = RecentModel::instance().peopleProxy()->mapToSource(_recentFilterModel->mapToSource(qIdx));

    auto participant = RecentModel::instance().getActiveCall(originIdx);
    if (participant) { //join this call with the current one
        QModelIndexList source_list;
        source_list << CallModel::instance().getIndex(current);
        auto idx_call_dest = CallModel::instance().getIndex(participant);
        auto mimeData = CallModel::instance().mimeData(source_list);
        auto action = Call::DropAction::Conference;
        mimeData->setProperty("dropAction", action);

        if (CallModel::instance().dropMimeData(mimeData, Qt::MoveAction, idx_call_dest.row(), idx_call_dest.column(), idx_call_dest.parent())) {
            NSLog(@"OK");
        } else {
            NSLog(@"could not drop mime data");
        }
        return;
    }

    auto contactmethods = RecentModel::instance().getContactMethods(originIdx);
    if (contactmethods.size() > 0) { // Before calling check if we properly extracted at least one contact method
        auto call = CallModel::instance().dialingCall(contactmethods.first());
        call->setParentCall(current);
        call << Call::Action::ACCEPT;
        CallModel::instance().selectCall(call);
    }
}

// -------------------------------------------------------------------------------
// place a call to the future participant with entered URI
// -------------------------------------------------------------------------------
- (void) addParticipantFromUri:(NSString*) uri
{
    auto current = CallModel::instance().selectedCall();
    if (!current)
        return;
    auto number = PhoneDirectoryModel::instance().getNumber(QString::fromNSString(uri));
    auto dialing = CallModel::instance().dialingCall(number);
    dialing->setParentCall(current);
    dialing << Call::Action::ACCEPT;
    CallModel::instance().selectCall(dialing);
}

#pragma mark - NSOutlineViewDelegate methods

// -------------------------------------------------------------------------------
// shouldSelectItem:item
// -------------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item;
{
    return YES;
}

// -------------------------------------------------------------------------------
// shouldEditTableColumn:tableColumn:item
//
// Decide to allow the edit of the given outline view "item".
// -------------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    return NO;
}

// -------------------------------------------------------------------------------
// View Based OutlineView: See the delegate method -tableView:viewForTableColumn:row: in NSTableView.
// -------------------------------------------------------------------------------
- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    auto qIdx = [_treeController toQIdx:((NSTreeNode*)item)];
    NSTableCellView *result;

    if (!qIdx.parent().isValid()) {
        result = [outlineView makeViewWithIdentifier:@"MainCell" owner:outlineView];
    } else {
        result = [outlineView makeViewWithIdentifier:@"CallCell" owner:outlineView];
    }

    auto finalIdx = RecentModel::instance().peopleProxy()->mapToSource(_recentFilterModel->mapToSource(qIdx));

    NSTextField* details = [result viewWithTag:DETAILS_TAG];
    if (auto call = RecentModel::instance().getActiveCall(finalIdx)) {
        [details setStringValue:call->roleData((int)Ring::Role::FormattedState).toString().toNSString()];
    } else {
        [details setStringValue:qIdx.data((int)Ring::Role::FormattedLastUsed).toString().toNSString()];
    }
    NSTextField* displayName = [result viewWithTag:DISPLAYNAME_TAG];
    [displayName setStringValue:qIdx.data(Qt::DisplayRole).toString().toNSString()];
    NSImageView* photoView = [result viewWithTag:IMAGE_TAG];
    Person* p = qvariant_cast<Person*>(qIdx.data((int)Person::Role::Object));
    QVariant photo = GlobalInstances::pixmapManipulator().contactPhoto(p, QSize(40,40));
    [photoView setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(photo))];
    return result;
}

// -------------------------------------------------------------------------------
// View Based OutlineView: See the delegate method -tableView:rowViewForRow: in NSTableView.
// -------------------------------------------------------------------------------
- (NSTableRowView *)outlineView:(NSOutlineView *)outlineView rowViewForItem:(id)item
{
    return [outlineView makeViewWithIdentifier:@"HoverRowView" owner:nil];
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
    QModelIndex qIdx = [_treeController toQIdx:((NSTreeNode*)item)];
    return (((NSTreeNode*)item).indexPath.length == 1) ? 60.0 : 45.0;
}

#pragma mark - NSTextFieldDelegate

- (BOOL)control:(NSControl *)control textView:(NSTextView *)fieldEditor doCommandBySelector:(SEL)commandSelector
{
    if (commandSelector == @selector(insertNewline:)) {
        if([fieldEditor.textStorage.string isNotEqualTo:@""]) {

            if ([self mode] == BrokerMode::TRANSFER) {
                [self transferTo:fieldEditor.textStorage.string];
            } else {
                [self addParticipantFromUri:fieldEditor.textStorage.string];
            }
            return YES;
        }
    }

    return NO;
}

- (void)controlTextDidChange:(NSNotification *) notification
{
    NSTextView *textView = notification.userInfo[@"NSFieldEditor"];
    _recentFilterModel->setFilterRegExp(QRegExp(QString::fromNSString(textView.textStorage.string), Qt::CaseInsensitive, QRegExp::FixedString));
    [_smartView scrollToBeginningOfDocument:nil];
}


@end
