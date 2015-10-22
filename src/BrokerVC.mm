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

#import "BrokerVC.h"

#import <QSortFilterProxyModel>
#import <QItemSelectionModel>
#import <QtMacExtras/qmacfunctions.h>
#import <QPixmap>

//LRC
#import <recentmodel.h>
#import <callmodel.h>
#import <call.h>
#import <person.h>
#import <globalinstances.h>
#import <contactmethod.h>

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
    [_smartView setDoubleAction:@selector(placeTransfer:)];
}

- (void)placeTransfer:(id)sender
{
    auto current = CallModel::instance().selectedCall();
    if (!current)
        return;

    QModelIndex qIdx = [_treeController toQIdx:[_treeController selectedNodes][0]];
    auto originIdx = RecentModel::instance().peopleProxy()->mapToSource(_recentFilterModel->mapToSource(qIdx));

    auto transfer = RecentModel::instance().getActiveCall(originIdx);
    if (transfer) { //realise an attended transfer between the two calls
        CallModel::instance().attendedTransfer(current, transfer);
        return;
    }

    ContactMethod* m = nil;
    // Extract data to make an unattended transfer
    if([[_treeController selectedNodes] count] > 0) {
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

    // Before calling check if we properly extracted a contact method
    if(m){
        CallModel::instance().transfer(current, m);
    }
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

/* View Based OutlineView: See the delegate method -tableView:viewForTableColumn:row: in NSTableView.
 */
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

/* View Based OutlineView: See the delegate method -tableView:rowViewForRow: in NSTableView.
 */
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

- (void)controlTextDidChange:(NSNotification *) notification
{
    NSTextView *textView = notification.userInfo[@"NSFieldEditor"];
    _recentFilterModel->setFilterRegExp(QRegExp(QString::fromNSString(textView.textStorage.string), Qt::CaseInsensitive, QRegExp::FixedString));
    [_smartView scrollToBeginningOfDocument:nil];
}


@end
