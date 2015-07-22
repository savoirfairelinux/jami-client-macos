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
 *
 *  Additional permission under GNU GPL version 3 section 7:
 *
 *  If you modify this program, or any covered work, by linking or
 *  combining it with the OpenSSL project's OpenSSL library (or a
 *  modified version of that library), containing parts covered by the
 *  terms of the OpenSSL or SSLeay licenses, Savoir-Faire Linux Inc.
 *  grants you additional permission to convey the resulting work.
 *  Corresponding Source for a non-source form of such a combination
 *  shall include the source code for the parts of OpenSSL used as well
 *  as that of the covered work.
 */

#import "PersonEditorVC.h"

//Qt
#import <QtMacExtras/qmacfunctions.h>
#import <QPixmap>

//LRC
#import <person.h>
#import <personmodel.h>
#import <contactmethod.h>
#import <numbercategorymodel.h>

#import "QNSTreeController.h"
#import "delegates/ImageManipulationDelegate.h"
#import "views/PersonCell.h"

#define FIRSTNAME_TAG   1
#define LASTNAME_TAG    2

#define COLUMNID_NAME @"NameColumn"

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
        return match && !sourceModel()->index(source_row,0,source_parent).parent().isValid();
    }
};

@interface PersonEditorVC () <NSTextFieldDelegate, NSComboBoxDelegate, NSComboBoxDataSource>

@property QSortFilterProxyModel* contactProxyModel;
@property QNSTreeController* treeController;


@property (unsafe_unretained) IBOutlet NSTextField *contactMethodLabel;
@property (unsafe_unretained) IBOutlet NSOutlineView *personsView;
@property (unsafe_unretained) IBOutlet NSTextField *firstNameField;
@property (unsafe_unretained) IBOutlet NSTextField *lastNameField;
@property (unsafe_unretained) IBOutlet NSButton *createNewContactButton;
@property (unsafe_unretained) IBOutlet NSComboBox *categoryComboBox;


@end

@implementation PersonEditorVC
@synthesize treeController;
@synthesize personsView;
@synthesize contactProxyModel;
@synthesize contactMethodLabel;
@synthesize categoryComboBox, firstNameField, lastNameField, createNewContactButton;

-(void) awakeFromNib
{
    NSLog(@"INIT PersonEditorVC");

    [firstNameField setTag:FIRSTNAME_TAG];
    [lastNameField setTag:LASTNAME_TAG];

    [categoryComboBox selectItemAtIndex:0];

    contactProxyModel = new OnlyPersonProxyModel(PersonModel::instance());
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
    const auto& idx = NumberCategoryModel::instance()->index([categoryComboBox indexOfSelectedItem]);
    if (idx.isValid()) {
        auto category = NumberCategoryModel::instance()->getCategory(idx.data().toString());
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

- (IBAction)createContact:(id)sender
{
    /* get the selected number category */
    const auto& idx = NumberCategoryModel::instance()->index([categoryComboBox indexOfSelectedItem]);
    if (idx.isValid()) {
        auto category = NumberCategoryModel::instance()->getCategory(idx.data().toString());
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
    PersonModel::instance()->addNewPerson(p);
    [self.contactLinkedDelegate contactLinked];
}

#pragma mark - NSOutlineViewDelegate methods

// -------------------------------------------------------------------------------
//	shouldSelectItem:item
// -------------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item;
{
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    if(!qIdx.isValid())
        return NO;

    if(qIdx.parent().isValid()) {
        return NO;
    } else {
        return YES;
    }
}

// -------------------------------------------------------------------------------
//	dataCellForTableColumn:tableColumn:item
// -------------------------------------------------------------------------------
- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    PersonCell *returnCell = [tableColumn dataCell];
    return returnCell;
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
//	outlineView:willDisplayCell:forTableColumn:item
// -------------------------------------------------------------------------------
- (void)outlineView:(NSOutlineView *)olv willDisplayCell:(NSCell*)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    if(!qIdx.isValid()) {
        [((PersonCell *)cell) setPersonImage:nil];
        return;
    }

    if ([[tableColumn identifier] isEqualToString:COLUMNID_NAME])
    {
        PersonCell *pCell = (PersonCell *)cell;
        [pCell setPersonImage:nil];
        if(!qIdx.parent().isValid()) {
            pCell.title = qIdx.data(Qt::DisplayRole).toString().toNSString();
                Person* p = qvariant_cast<Person*>(qIdx.data((int)Person::Role::Object));
                QVariant photo = ImageManipulationDelegate::instance()->contactPhoto(p, QSize(35,35));
                [pCell setPersonImage:QtMac::toNSImage(qvariant_cast<QPixmap>(photo))];
        } else {
            pCell.title = qIdx.data(Qt::DisplayRole).toString().toNSString();

        }
    }
}

// -------------------------------------------------------------------------------
//	outlineViewSelectionDidChange:notification
// -------------------------------------------------------------------------------

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
    return 45.0;
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
    return NumberCategoryModel::instance()->rowCount();
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index
{
    return NumberCategoryModel::instance()->index(index).data().toString().toNSString();
}

@end
