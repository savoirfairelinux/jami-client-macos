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

#import "PersonLinkerVC.h"

//Qt
#import <QtMacExtras/qmacfunctions.h>
#import <QPixmap>

//LRC
#import <person.h>
#import <personmodel.h>
#import <contactmethod.h>
#import <numbercategorymodel.h>
#import <globalinstances.h>

#import "QNSTreeController.h"
#import "delegates/ImageManipulationDelegate.h"
#import "backends/AddressBookBackend.h"

class OnlyPersonProxyModel : public QSortFilterProxyModel
{
public:
    OnlyPersonProxyModel(QAbstractItemModel* parent) : QSortFilterProxyModel(parent)
    {
        setSourceModel(parent);
    }
    virtual bool filterAcceptsRow(int source_row, const QModelIndex& source_parent) const
    {
        bool match = filterRegExp().indexIn(sourceModel()->index(source_row,0,source_parent).data(Qt::DisplayRole).toString()) != -1;
        //qDebug() << "FILTERING" << sourceModel()->index(source_row,0,source_parent) << "match:" << match;
        return match && !sourceModel()->index(source_row,0,source_parent).parent().isValid();
    }
};

@interface PersonLinkerVC () <NSTextFieldDelegate, NSComboBoxDelegate, NSComboBoxDataSource> {

    __unsafe_unretained IBOutlet NSTextField *contactMethodLabel;
    __unsafe_unretained IBOutlet NSOutlineView *personsView;
    __unsafe_unretained IBOutlet NSTextField *firstNameField;
    __unsafe_unretained IBOutlet NSTextField *lastNameField;
    __unsafe_unretained IBOutlet NSButton *createNewContactButton;
    __unsafe_unretained IBOutlet NSComboBox *categoryComboBox;
    __unsafe_unretained IBOutlet NSView *linkToExistingSubview;

    QSortFilterProxyModel* contactProxyModel;
    QNSTreeController* treeController;
    IBOutlet NSView *createContactSubview;
}

@end

@implementation PersonLinkerVC

// Tags for views
NSInteger const FIRSTNAME_TAG = 1;
NSInteger const LASTNAME_TAG = 2;
NSInteger const IMAGE_TAG = 100;
NSInteger const DISPLAYNAME_TAG = 200;
NSInteger const DETAILS_TAG = 300;

-(void) awakeFromNib
{
    NSLog(@"INIT PersonLinkerVC");

    [firstNameField setTag:FIRSTNAME_TAG];
    [lastNameField setTag:LASTNAME_TAG];

    [categoryComboBox selectItemAtIndex:0];

    contactProxyModel = new OnlyPersonProxyModel(&PersonModel::instance());
    contactProxyModel->setSortRole(static_cast<int>(Qt::DisplayRole));
    contactProxyModel->sort(0,Qt::AscendingOrder);
    contactProxyModel->setFilterRole(Qt::DisplayRole);
    treeController = [[QNSTreeController alloc] initWithQModel:contactProxyModel];

    [treeController setAvoidsEmptySelection:NO];
    [treeController setChildrenKeyPath:@"children"];

    [personsView bind:@"content" toObject:treeController withKeyPath:@"arrangedObjects" options:nil];
    [personsView bind:@"sortDescriptors" toObject:treeController withKeyPath:@"sortDescriptors" options:nil];
    [personsView bind:@"selectionIndexPaths" toObject:treeController withKeyPath:@"selectionIndexPaths" options:nil];
    [personsView setTarget:self];
    [personsView setDoubleAction:@selector(addToContact:)];

    [contactMethodLabel setStringValue:self.methodToLink->uri().toNSString()];
}

- (IBAction)addToContact:(id)sender
{
    /* get the selected number category */
    const auto& idx = NumberCategoryModel::instance().index([categoryComboBox indexOfSelectedItem]);
    if (idx.isValid()) {
        auto category = NumberCategoryModel::instance().getCategory(idx.data().toString());
        self.methodToLink->setCategory(category);
    }

    if([[treeController selectedNodes] count] > 0) {
        QModelIndex qIdx = [treeController toQIdx:[treeController selectedNodes][0]];
        ContactMethod* m = nil;
        if(((NSTreeNode*)[treeController selectedNodes][0]).indexPath.length == 1) {
            // Person
            QVariant var = qIdx.data((int)Person::Role::Object);
            if (var.isValid()) {
                Person *p = var.value<Person*>();
                Person::ContactMethods cms = p->phoneNumbers();
                cms.append(self.methodToLink);
                p->setContactMethods(cms);
                self.methodToLink->setPerson(p);
                p->save();
                [self.contactLinkedDelegate contactLinked];
            }
        }
    }
}

- (void) dealloc
{
    // No ARC for c++ pointers
    delete contactProxyModel;
}

- (IBAction)presentNewContactForm:(id)sender {
    [createContactSubview setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    //[createContactSubview setBounds:linkToExistingSubview.bounds];
    [createContactSubview setFrame:linkToExistingSubview.frame];
    [linkToExistingSubview setHidden:YES];
    [self.view addSubview:createContactSubview];

    [[[NSApplication sharedApplication] mainWindow] makeFirstResponder:firstNameField];
    [firstNameField setNextKeyView:lastNameField];
    [lastNameField setNextKeyView:createNewContactButton];
    [createNewContactButton setNextKeyView:firstNameField];
}

- (IBAction)createContact:(id)sender
{
    /* get the selected number category */
    const auto& idx = NumberCategoryModel::instance().index([categoryComboBox indexOfSelectedItem]);
    if (idx.isValid()) {
        auto category = NumberCategoryModel::instance().getCategory(idx.data().toString());
        self.methodToLink->setCategory(category);
    }

    /* create a new person */
    Person *p = new Person();
    p->setFirstName(QString::fromNSString(firstNameField.stringValue));
    p->setFamilyName(QString::fromNSString(lastNameField.stringValue));
    p->setFormattedName(QString::fromNSString([[NSString alloc] initWithFormat:@"%@ %@", firstNameField.stringValue, lastNameField.stringValue]));
    /* associate the new person with the contact method */
    Person::ContactMethods numbers;
    numbers << self.methodToLink;
    p->setContactMethods(numbers);
    self.methodToLink->setPerson(p);
    PersonModel::instance().addNewPerson(p);
    [self.contactLinkedDelegate contactLinked];
}

#pragma mark - NSOutlineViewDelegate methods

// -------------------------------------------------------------------------------
//	shouldSelectItem:item
// -------------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item;
{
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    return qIdx.isValid();
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
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];

    NSTableCellView *result = [outlineView makeViewWithIdentifier:@"MainCell" owner:outlineView];
    NSImageView* photoView = [result viewWithTag:IMAGE_TAG];
    NSTextField* displayName = [result viewWithTag:DISPLAYNAME_TAG];
    [photoView setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(qIdx.data(Qt::DecorationRole)))];
    [displayName setStringValue:qIdx.data(Qt::DisplayRole).toString().toNSString()];
    return result;
}

// -------------------------------------------------------------------------------
//	outlineViewSelectionDidChange:notification
// -------------------------------------------------------------------------------

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
    return 60.0;
}

#pragma mark - NSTextFieldDelegate

- (void)controlTextDidChange:(NSNotification *) notification
{
    if ([notification.object tag] == FIRSTNAME_TAG || [notification.object tag] == LASTNAME_TAG) {
        NSTextView *textView = notification.userInfo[@"NSFieldEditor"];
        BOOL enableCreate = textView.textStorage.string.length > 0;
        [createNewContactButton setEnabled:enableCreate];
    } else {
        NSTextView *textView = notification.userInfo[@"NSFieldEditor"];
        contactProxyModel->setFilterRegExp(QRegExp(QString::fromNSString(textView.textStorage.string), Qt::CaseInsensitive, QRegExp::FixedString));
        [personsView scrollToBeginningOfDocument:nil];
    }
}

#pragma mark - NSComboBoxDelegate

- (void)comboBoxSelectionDidChange:(NSNotification*) notification
{
    [(NSComboBox *)[notification object] indexOfSelectedItem];
}

#pragma mark - NSComboBoxDatasource

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox
{
    return NumberCategoryModel::instance().rowCount();
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index
{
    return NumberCategoryModel::instance().index(index).data().toString().toNSString();
}

@end
