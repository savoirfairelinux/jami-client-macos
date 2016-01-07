/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
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

#import "OffCallVC.h"

#import <QItemSelectionModel>
#import <qstring.h>
#import <QPixmap>
#import <QtMacExtras/qmacfunctions.h>

#import <media/media.h>
#import <recentmodel.h>
#import <person.h>
#import <contactmethod.h>
#import <media/text.h>
#import <media/textrecording.h>
#import <callmodel.h>
#import <globalinstances.h>

#import "views/IconButton.h"
#import "views/NSColor+RingTheme.h"
#import "QNSTreeController.h"
#import "delegates/ImageManipulationDelegate.h"

#import <QuartzCore/QuartzCore.h>

@interface MediaConnectionsHolder2 : NSObject

@property QMetaObject::Connection newMediaAdded;
@property QMetaObject::Connection newMessage;

@end

@implementation MediaConnectionsHolder2

@end

@interface OffCallVC () <NSOutlineViewDelegate> {

    __unsafe_unretained IBOutlet IconButton* backButton;
    __unsafe_unretained IBOutlet NSTextField* messageField;
    MediaConnectionsHolder2* mediaHolder;
    QVector<ContactMethod*> contactMethods;

    QNSTreeController *treeController;

    __unsafe_unretained IBOutlet NSView *sendPanel;
    __unsafe_unretained IBOutlet NSTextField *conversationTitle;
    __unsafe_unretained IBOutlet NSTextField *emptyConversationPlaceHolder;
    __unsafe_unretained IBOutlet IconButton* sendButton;
    __unsafe_unretained IBOutlet NSOutlineView* conversationView;
    __unsafe_unretained IBOutlet NSPopUpButton* contactMethodsPopupButton;
}
@end

@implementation OffCallVC

// Tags for views
NSInteger const IMAGE_TAG       =   100;
NSInteger const MESSAGE_TAG     =   200;
NSInteger const TIMESTAMP_TAG   =   300;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    [self.view setWantsLayer:YES];
    [self.view setLayer:[CALayer layer]];
    [self.view.layer setBackgroundColor:[NSColor ringGreyHighlight].CGColor];

    [sendPanel setWantsLayer:YES];
    [sendPanel setLayer:[CALayer layer]];
    [sendPanel.layer setBackgroundColor:[NSColor ringDarkGrey].CGColor];

    [self setupChat];

}

- (void) initFrame
{
    [self.view setFrame:self.view.superview.bounds];
    [self.view setHidden:YES];
    self.view.layer.position = self.view.frame.origin;
}

- (void) setupChat
{
    QObject::connect(RecentModel::instance().selectionModel(),
                     &QItemSelectionModel::currentChanged,
                     [=](const QModelIndex &current, const QModelIndex &previous) {

                         contactMethods = RecentModel::instance().getContactMethods(current);
                         if (contactMethods.isEmpty()) {
                             return ;
                         }

                         [contactMethodsPopupButton removeAllItems];
                         for (auto cm : contactMethods) {
                             [contactMethodsPopupButton addItemWithTitle:cm->uri().toNSString()];
                         }

                         [contactMethodsPopupButton setEnabled:(contactMethods.length() > 1)];

                         // Select first cm
                         [contactMethodsPopupButton selectItemAtIndex:0];
                         [self itemChanged:contactMethodsPopupButton];
                         [emptyConversationPlaceHolder setHidden:NO];

                         NSString* localizedTitle = NSLocalizedString(([NSString stringWithFormat:@"Conversation with %@",
                                                                        current.data((int)Ring::Role::Name).toString().toNSString()]),
                                                                      @"Conversation title");
                        [conversationTitle setStringValue:localizedTitle];

                     });

    QObject::disconnect(mediaHolder.newMediaAdded);
    QObject::disconnect(mediaHolder.newMessage);

}

- (IBAction)sendMessage:(id)sender {

    /* make sure there is text to send */
    NSString* text = self.message;
    if (text && text.length > 0) {
        QMap<QString, QString> messages;
        messages["text/plain"] = QString::fromNSString(text);
        contactMethods.at([contactMethodsPopupButton indexOfSelectedItem])->sendOfflineTextMessage(messages);
        // Empty the text after sending it
        [messageField setStringValue:@""];
        self.message = @"";
    }
}


# pragma private IN/OUT animations

-(void) animateIn
{
    NSLog(@"animateIn");
    CGRect frame = CGRectOffset(self.view.superview.bounds, -self.view.superview.bounds.size.width, 0);
    [self.view setHidden:NO];

    [CATransaction begin];
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
    [animation setFromValue:[NSValue valueWithPoint:frame.origin]];
    [animation setToValue:[NSValue valueWithPoint:self.view.superview.bounds.origin]];
    [animation setDuration:0.2f];
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn]];
    [CATransaction setCompletionBlock:^{

    }];
    [self.view.layer addAnimation:animation forKey:animation.keyPath];

    [CATransaction commit];
}

-(IBAction) animateOut:(id)sender
{
    NSLog(@"animateOut");
    if(self.view.frame.origin.x < 0) {
        NSLog(@"Already hidden");
        return;
    }

    CGRect frame = CGRectOffset(self.view.frame, -self.view.frame.size.width, 0);
    [CATransaction begin];
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
    [animation setFromValue:[NSValue valueWithPoint:self.view.frame.origin]];
    [animation setToValue:[NSValue valueWithPoint:frame.origin]];
    [animation setDuration:0.2f];
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];

    [CATransaction setCompletionBlock:^{
        [self.view setHidden:YES];
    }];
    [self.view.layer addAnimation:animation forKey:animation.keyPath];

    [self.view.layer setPosition:frame.origin];
    [CATransaction commit];
}

#pragma mark - NSOutlineViewDelegate methods

// -------------------------------------------------------------------------------
//	shouldSelectItem:item
// -------------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item;
{
    return NO;
}

// -------------------------------------------------------------------------------
//	shouldEditTableColumn:tableColumn:item
//
//	Decide to allow the edit of the given outline view "item".
// -------------------------------------------------------------------------------
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    return YES;
}

// -------------------------------------------------------------------------------
//	outlineViewSelectionDidChange:notification
// -------------------------------------------------------------------------------
- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{

}

/* View Based OutlineView: See the delegate method -tableView:viewForTableColumn:row: in NSTableView.
 */
- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];
    auto dir = qvariant_cast<Media::Media::Direction>(qIdx.data((int)Media::TextRecording::Role::Direction));
    NSTableCellView* result;

    if (dir == Media::Media::Direction::IN) {
        result = [outlineView makeViewWithIdentifier:@"LeftMessageView" owner:self];
    } else {
        result = [outlineView makeViewWithIdentifier:@"RightMessageView" owner:self];
    }

    NSTextField* messageText = [result viewWithTag:MESSAGE_TAG];

    NSMutableAttributedString* msgAttString = [[NSMutableAttributedString alloc] initWithString:
                                       [NSString stringWithFormat:@"%@\n",qIdx.data((int)Qt::DisplayRole).toString().toNSString()]];

    NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
    if (dir == Media::Media::Direction::IN)
        attrs[NSForegroundColorAttributeName] = [NSColor grayColor];

    NSAttributedString *timestampAttrString = [[NSAttributedString alloc] initWithString:qIdx.data((int)Media::TextRecording::Role::FormattedDate).toString().toNSString() attributes:attrs];

    [msgAttString appendAttributedString:timestampAttrString];
    [messageText setAttributedStringValue:msgAttString];
    
    NSImageView* photoView = [result viewWithTag:IMAGE_TAG];
    Person* p = qvariant_cast<Person*>(qIdx.data((int)Person::Role::Object));
    QVariant photo = GlobalInstances::pixmapManipulator().contactPhoto(p, QSize(50,50));
    [photoView setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(photo))];
    
    return result;
}

- (void)outlineView:(NSOutlineView *)outlineView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
    [emptyConversationPlaceHolder setHidden:YES];

    //[outlineView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndex:row]];
    [outlineView scrollRowToVisible:row];
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];

    double someWidth = outlineView.frame.size.width;

    NSMutableAttributedString* attrString = [[NSMutableAttributedString alloc] initWithString:
                                       [NSString stringWithFormat:@"%@\n%@",qIdx.data((int)Qt::DisplayRole).toString().toNSString(), qIdx.data((int)Media::TextRecording::Role::FormattedDate).toString().toNSString()]];

    NSRect frame = NSMakeRect(0, 0, 600, MAXFLOAT);
    NSTextView *tv = [[NSTextView alloc] initWithFrame:frame];
    [[tv textStorage] setAttributedString:attrString];
    [tv setHorizontallyResizable:YES];
    [tv sizeToFit];

    double height = tv.frame.size.height + 20;

    return MAX(height, 60.0f);
}

#pragma mark - NSTextFieldDelegate

- (BOOL)control:(NSControl *)control textView:(NSTextView *)fieldEditor doCommandBySelector:(SEL)commandSelector
{
    if (commandSelector == @selector(insertNewline:) && self.message.length > 0) {
        [self sendMessage:nil];
        return YES;
    }
    return NO;
}

#pragma mark - NSPopUpButton item selection

- (IBAction)itemChanged:(id)sender {
    NSInteger index = [(NSPopUpButton *)sender indexOfSelectedItem];

    if (auto txtRecording = contactMethods.at(index)->textRecording()) {
        treeController = [[QNSTreeController alloc] initWithQModel:txtRecording->instantMessagingModel()];
        [treeController setAvoidsEmptySelection:NO];
        [treeController setChildrenKeyPath:@"children"];
        [conversationView bind:@"content" toObject:treeController withKeyPath:@"arrangedObjects" options:nil];
        [conversationView bind:@"sortDescriptors" toObject:treeController withKeyPath:@"sortDescriptors" options:nil];
        [conversationView bind:@"selectionIndexPaths" toObject:treeController withKeyPath:@"selectionIndexPaths" options:nil];
    }
}


@end
