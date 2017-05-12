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

#import "ConversationVC.h"

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
#import "views/IMTableCellView.h"
#import "views/NSColor+RingTheme.h"
#import "QNSTreeController.h"
#import "INDSequentialTextSelectionManager.h"
#import "delegates/ImageManipulationDelegate.h"
#import "SendContactRequestWC.h"
#import "PhoneDirectoryModel.h"
#import "account.h"
#import "AvailableAccountModel.h"


#import <QuartzCore/QuartzCore.h>

@interface ConversationVC () <NSOutlineViewDelegate> {

    __unsafe_unretained IBOutlet NSTextField* messageField;
    QVector<ContactMethod*> contactMethods;
    NSMutableString* textSelection;

    QNSTreeController* treeController;
    QMetaObject::Connection contactMethodChanged;
    ContactMethod* selectedContactMethod;
    SendContactRequestWC* sendRequestWC;

    __unsafe_unretained IBOutlet NSView* sendPanel;
    __unsafe_unretained IBOutlet NSTextField* conversationTitle;
    __unsafe_unretained IBOutlet NSTextField* emptyConversationPlaceHolder;
    __unsafe_unretained IBOutlet IconButton* sendButton;
    __unsafe_unretained IBOutlet NSOutlineView* conversationView;
    __unsafe_unretained IBOutlet NSPopUpButton* contactMethodsPopupButton;
}

@property (nonatomic, strong, readonly) INDSequentialTextSelectionManager* selectionManager;

@end

@implementation ConversationVC

- (void)loadView {
    [super loadView];
    // Do view setup here.
    [self.view setWantsLayer:YES];
    [self.view setLayer:[CALayer layer]];
    [self.view.layer setBackgroundColor:[NSColor ringGreyHighlight].CGColor];
    [self.view.layer setCornerRadius:5.0f];

    [sendPanel setWantsLayer:YES];
    [sendPanel setLayer:[CALayer layer]];
    _selectionManager = [[INDSequentialTextSelectionManager alloc] init];

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

                         [self.selectionManager unregisterAllTextViews];

                         [contactMethodsPopupButton removeAllItems];
                         for (auto cm : contactMethods) {
                             [contactMethodsPopupButton addItemWithTitle:cm->uri().toNSString()];
                         }

                         [contactMethodsPopupButton setEnabled:(contactMethods.length() > 1)];

                         [emptyConversationPlaceHolder setHidden:NO];
                         // Select first cm
                         [contactMethodsPopupButton selectItemAtIndex:0];
                         [self itemChanged:contactMethodsPopupButton];
                     });
}

- (IBAction)sendMessage:(id)sender
{
    /* make sure there is text to send */
    NSString* text = self.message;
    if (text && text.length > 0) {
        QMap<QString, QString> messages;
        messages["text/plain"] = QString::fromNSString(text);
        contactMethods.at([contactMethodsPopupButton indexOfSelectedItem])->sendOfflineTextMessage(messages);
        self.message = @"";
    }
}

- (IBAction)placeCall:(id)sender
{
    if(auto cm = contactMethods.at([contactMethodsPopupButton indexOfSelectedItem])) {
        auto c = CallModel::instance().dialingCall();
        c->setPeerContactMethod(cm);
        c << Call::Action::ACCEPT;
        CallModel::instance().selectCall(c);
    }
}

- (IBAction)backPressed:(id)sender {
    [conversationView setDelegate:nil];
    RecentModel::instance().selectionModel()->clearCurrentIndex();
}

- (IBAction)openSendContactRequestWindow:(id)sender
{
    if(auto cm = contactMethods.at([contactMethodsPopupButton indexOfSelectedItem])) {
        sendRequestWC = [[SendContactRequestWC alloc] initWithWindowNibName:@"SendContactRequest"];
        sendRequestWC.contactMethod = cm;
        [sendRequestWC.window makeKeyAndOrderFront:sendRequestWC.window];
    }
}

# pragma mark private IN/OUT animations

-(void) animateIn
{
    CGRect frame = CGRectOffset(self.view.superview.bounds, -self.view.superview.bounds.size.width, 0);
    [self.view setHidden:NO];

    [CATransaction begin];
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
    [animation setFromValue:[NSValue valueWithPoint:frame.origin]];
    [animation setToValue:[NSValue valueWithPoint:self.view.superview.bounds.origin]];
    [animation setDuration:0.2f];
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn]];
    [self.view.layer addAnimation:animation forKey:animation.keyPath];

    [CATransaction commit];
}

-(void) animateOut
{
    if(self.view.frame.origin.x < 0) {
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
    auto dir = qvariant_cast<Media::Media::Direction>(qIdx.data((int)Media::TextRecording::Role::Direction));
    IMTableCellView* result;

    if (dir == Media::Media::Direction::IN) {
        result = [outlineView makeViewWithIdentifier:@"LeftMessageView" owner:self];
    } else {
        result = [outlineView makeViewWithIdentifier:@"RightMessageView" owner:self];
    }

    [result setup];

    NSMutableAttributedString* msgAttString =
    [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n",qIdx.data((int)Qt::DisplayRole).toString().toNSString()]
                                           attributes:[self messageAttributesFor:qIdx]];

    NSAttributedString* timestampAttrString =
    [[NSAttributedString alloc] initWithString:qIdx.data((int)Media::TextRecording::Role::FormattedDate).toString().toNSString()
                                    attributes:[self timestampAttributesFor:qIdx]];


    CGFloat finalWidth = MAX(msgAttString.size.width, timestampAttrString.size.width);
    finalWidth = MIN(finalWidth + 30, result.frame.size.width - result.photoView.frame.size.width - 30);

    [msgAttString appendAttributedString:timestampAttrString];
    [[result.msgView textStorage] appendAttributedString:msgAttString];
    [result.msgView checkTextInDocument:nil];
    [result.msgView setWantsLayer:YES];
    result.msgView.layer.cornerRadius = 5.0f;

    [result updateWidthConstraint:finalWidth];
    [result.photoView setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(qIdx.data(Qt::DecorationRole)))];
    return result;
}

- (void)outlineView:(NSOutlineView *)outlineView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
    if (IMTableCellView* cellView = [outlineView viewAtColumn:0 row:row makeIfNecessary:NO]) {
        [self.selectionManager registerTextView:cellView.msgView withUniqueIdentifier:@(row).stringValue];
    }

    if (auto txtRecording = contactMethods.at([contactMethodsPopupButton indexOfSelectedItem])->textRecording()) {
        [emptyConversationPlaceHolder setHidden:txtRecording->instantMessagingModel()->rowCount() > 0];
        txtRecording->setAllRead();
    }
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
    QModelIndex qIdx = [treeController toQIdx:((NSTreeNode*)item)];

    double someWidth = outlineView.frame.size.width;

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

    double height = tv.frame.size.height + 20;

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

    selectedContactMethod = contactMethods.at(index);
    [conversationTitle setStringValue:selectedContactMethod->primaryName().toNSString()];
    QObject::disconnect(contactMethodChanged);
    contactMethodChanged = QObject::connect(selectedContactMethod,
                                            &ContactMethod::changed,
                                            [self] {
                                                [conversationTitle setStringValue:selectedContactMethod->primaryName().toNSString()];
                                            });

    if (auto txtRecording = selectedContactMethod->textRecording()) {
        treeController = [[QNSTreeController alloc] initWithQModel:txtRecording->instantMessagingModel()];
        [treeController setAvoidsEmptySelection:NO];
        [treeController setChildrenKeyPath:@"children"];
        [conversationView setDelegate:self];
        [conversationView bind:@"content" toObject:treeController withKeyPath:@"arrangedObjects" options:nil];
        [conversationView bind:@"sortDescriptors" toObject:treeController withKeyPath:@"sortDescriptors" options:nil];
        [conversationView bind:@"selectionIndexPaths" toObject:treeController withKeyPath:@"selectionIndexPaths" options:nil];
    }

    [conversationView scrollToEndOfDocument:nil];
}


@end
