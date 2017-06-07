/*
 *  Copyright (C) 2015-2017 Savoir-faire Linux Inc.
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

#import <QItemSelectionModel>
#import <qstring.h>
#import <QPixmap>
#import <QtMacExtras/qmacfunctions.h>

#import <media/media.h>
#import <person.h>
#import <media/text.h>
#import <media/textrecording.h>
#import <globalinstances.h>

#import "MessagesVC.h"
#import "QNSTreeController.h"
#import "views/IMTableCellView.h"
#import "views/MessageBubbleView.h"
#import "INDSequentialTextSelectionManager.h"

@interface MessagesVC () {

    QNSTreeController* treeController;
    __unsafe_unretained IBOutlet NSOutlineView* conversationView;

}

@property (nonatomic, strong, readonly) INDSequentialTextSelectionManager* selectionManager;

@end

@implementation MessagesVC
QAbstractItemModel* currentModel;

-(void)setUpViewWithModel: (QAbstractItemModel*) model {

     _selectionManager = [[INDSequentialTextSelectionManager alloc] init];

    [self.selectionManager unregisterAllTextViews];

    treeController = [[QNSTreeController alloc] initWithQModel:model];
    [treeController setAvoidsEmptySelection:NO];
    [treeController setChildrenKeyPath:@"children"];
    [conversationView bind:@"content" toObject:treeController withKeyPath:@"arrangedObjects" options:nil];
    [conversationView bind:@"sortDescriptors" toObject:treeController withKeyPath:@"sortDescriptors" options:nil];
    [conversationView bind:@"selectionIndexPaths" toObject:treeController withKeyPath:@"selectionIndexPaths" options:nil];
    [conversationView scrollToEndOfDocument:nil];
    currentModel = model;
}

#pragma mark - NSOutlineViewDelegate methods

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item;
{
    return YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    return YES;
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    if(!qIdx.isValid()) {
        return [outlineView makeViewWithIdentifier:@"LeftMessageView" owner:self];
    }
    auto dir = qvariant_cast<Media::Media::Direction>(qIdx.data((int)Media::TextRecording::Role::Direction));
    IMTableCellView* result;

    if (dir == Media::Media::Direction::IN) {
        result = [outlineView makeViewWithIdentifier:@"LeftMessageView" owner:self];
    } else {
        result = [outlineView makeViewWithIdentifier:@"RightMessageView" owner:self];
    }

    // check if the message first in incoming or outgoing messages sequence
    Boolean isFirstInSequence = true;
    int row = qIdx.row() - 1;
    if(row >= 0) {
        QModelIndex index = currentModel->index(row, 0);
        if(index.isValid()) {
            auto dirOld = qvariant_cast<Media::Media::Direction>(index.data((int)Media::TextRecording::Role::Direction));
            isFirstInSequence = !(dirOld == dir);
        }
    }
    [result.photoView setHidden:!isFirstInSequence];
    result.msgBackground.needPointer = isFirstInSequence;
    [result setup];

    NSMutableAttributedString* msgAttString =
    [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n",qIdx.data((int)Qt::DisplayRole).toString().toNSString()]
                                           attributes:[self messageAttributesFor:qIdx]];

    NSAttributedString* timestampAttrString =
    [[NSAttributedString alloc] initWithString:qIdx.data((int)Media::TextRecording::Role::FormattedDate).toString().toNSString()
                                    attributes:[self timestampAttributesFor:qIdx]];


    CGFloat finalWidth = MAX(msgAttString.size.width, timestampAttrString.size.width);

    finalWidth = MIN(finalWidth + 30, outlineView.frame.size.width - 80);

    NSString* msgString = qIdx.data((int)Qt::DisplayRole).toString().toNSString();
    NSString* dateString = qIdx.data((int)Qt::DisplayRole).toString().toNSString();

    [msgAttString appendAttributedString:timestampAttrString];
    [[result.msgView textStorage] appendAttributedString:msgAttString];
    [result.msgView checkTextInDocument:nil];
    [result updateWidthConstraint:finalWidth];
    [result.photoView setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(qIdx.data(Qt::DecorationRole)))];
    return result;
}

- (void)outlineView:(NSOutlineView *)outlineView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
    if (IMTableCellView* cellView = [outlineView viewAtColumn:0 row:row makeIfNecessary:NO]) {
        [self.selectionManager registerTextView:cellView.msgView withUniqueIdentifier:@(row).stringValue];
    }
    [self.delegate newMessageAdded];
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    double someWidth = outlineView.frame.size.width - 60;

    NSMutableAttributedString* msgAttString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n",qIdx.data((int)Qt::DisplayRole).toString().toNSString()]
                                                                                     attributes:[self messageAttributesFor:qIdx]];
    NSAttributedString *timestampAttrString = [[NSAttributedString alloc] initWithString:
                                               qIdx.data((int)Media::TextRecording::Role::FormattedDate).toString().toNSString()
                                                                             attributes:[self timestampAttributesFor:qIdx]];

    [msgAttString appendAttributedString:timestampAttrString];

    NSRect frame = NSMakeRect(0, 0, someWidth, MAXFLOAT);
    NSTextView *tv = [[NSTextView alloc] initWithFrame:frame];
    [tv setEnabledTextCheckingTypes:NSTextCheckingTypeLink];
    [tv setAutomaticLinkDetectionEnabled:YES];
    [[tv textStorage] setAttributedString:msgAttString];
    [tv sizeToFit];

    double height = tv.frame.size.height + 26;
    return MAX(height, 60.0f);
}

#pragma mark - Text formatting

- (NSMutableDictionary*) timestampAttributesFor:(QModelIndex) qIdx
{
    auto dir = qvariant_cast<Media::Media::Direction>(qIdx.data((int)Media::TextRecording::Role::Direction));
    NSMutableDictionary* attrs = [NSMutableDictionary dictionary];

    if (dir == Media::Media::Direction::IN) {
        attrs[NSForegroundColorAttributeName] = [NSColor grayColor];
    } else {
        attrs[NSForegroundColorAttributeName] = [NSColor whiteColor];
    }

    NSFont* systemFont = [NSFont systemFontOfSize:12.0f];
    attrs[NSFontAttributeName] = systemFont;
    attrs[NSParagraphStyleAttributeName] = [self paragraphStyle];

    return attrs;
}

- (NSMutableDictionary*) messageAttributesFor:(QModelIndex) qIdx
{
    auto dir = qvariant_cast<Media::Media::Direction>(qIdx.data((int)Media::TextRecording::Role::Direction));
    NSMutableDictionary* attrs = [NSMutableDictionary dictionary];

    if (dir == Media::Media::Direction::IN) {
        attrs[NSForegroundColorAttributeName] = [NSColor blackColor];
    } else {
        attrs[NSForegroundColorAttributeName] = [NSColor whiteColor];
    }

    NSFont* systemFont = [NSFont systemFontOfSize:14.0f];
    attrs[NSFontAttributeName] = systemFont;
    attrs[NSParagraphStyleAttributeName] = [self paragraphStyle];

    return attrs;
}

- (NSParagraphStyle*) paragraphStyle
{
    /*
     The only way to instantiate an NSMutableParagraphStyle is to mutably copy an
     NSParagraphStyle. And since we don't have an existing NSParagraphStyle available
     to copy, we use the default one.

     The default values supplied by the default NSParagraphStyle are:
     Alignment   NSNaturalTextAlignment
     Tab stops   12 left-aligned tabs, spaced by 28.0 points
     Line break mode   NSLineBreakByWordWrapping
     All others   0.0
     */
       NSMutableParagraphStyle* aMutableParagraphStyle =
     [[NSParagraphStyle defaultParagraphStyle] mutableCopy];

     // Now adjust our NSMutableParagraphStyle formatting to be whatever we want.
     // The numeric values below are in points (72 points per inch)
     [aMutableParagraphStyle setAlignment:NSLeftTextAlignment];
     [aMutableParagraphStyle setLineSpacing:1.5];
     [aMutableParagraphStyle setParagraphSpacing:5.0];
     [aMutableParagraphStyle setHeadIndent:5.0];
     [aMutableParagraphStyle setTailIndent:-5.0];
     [aMutableParagraphStyle setFirstLineHeadIndent:5.0];
     [aMutableParagraphStyle setLineBreakMode:NSLineBreakByWordWrapping];
     return aMutableParagraphStyle;
}

@end
