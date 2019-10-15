//
//  ChooseContactVC.m
//  Jami
//
//  Created by kate on 2019-10-10.
//

#import "ChooseContactVC.h"
#import "views/RingTableView.h"
#import "views/HoverTableRowView.h"
#import "utils.h"
#import "delegates/ImageManipulationDelegate.h"

//LRC
#import <globalinstances.h>
#import <api/conversationmodel.h>

//Qt
#import <QtMacExtras/qmacfunctions.h>
#import <QPixmap>

@interface ChooseContactVC () {
    __unsafe_unretained IBOutlet RingTableView* smartView;
}

@end

@implementation ChooseContactVC

 lrc::api::ConversationModel* convModel;
std::string currentConversation;

// Tags for views
NSInteger const IMAGE_TAG           = 100;
NSInteger const DISPLAYNAME_TAG     = 200;
NSInteger const RING_ID_LABEL       = 300;
NSInteger const PRESENCE_TAG        = 400;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (void)setConversationModel:(lrc::api::ConversationModel *)conversationModel
{
    if (convModel == conversationModel) {
        return;
    }
    convModel = conversationModel;
    convModel->setFilter(lrc::api::profile::Type::RING);
    [smartView reloadData];
}

- (void)setCurrentConversation:(std::string)conversation
{
    if (currentConversation == conversation) {
        return;
    }
    currentConversation = conversation;
}

#pragma mark - NSTableViewDelegate methods

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
    return YES;
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    return NO;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    NSInteger row = [notification.object selectedRow];
    NSInteger rows = [smartView numberOfRows];
    
    for (int i = 0; i< rows; i++) {
        HoverTableRowView* cellRowView = [smartView rowViewAtRow:i makeIfNecessary: NO];
        [cellRowView drawSelection: (i == row)];
    }
    
    if (row == -1)
        return;
    if (convModel == nil)
        return;
    
    auto uid = convModel->filteredConversation(row).participants[0];
    [self.delegate addCallToParticipant: uid];
//    if (selectedUid_ != uid) {
//        selectedUid_ = uid;
//        convModel_->selectConversation(uid);
//        convModel_->clearUnreadInteractions(uid);
//        [self reloadSelectorNotifications];
//    }
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    HoverTableRowView *howerRow = [tableView makeViewWithIdentifier:@"HoverRowView" owner:nil];
    [howerRow setBlurType:7];
    return howerRow;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if (convModel == nil)
        return nil;
    
    auto conversations = convModel->getFilteredConversations(lrc::api::profile::Type::RING);
    auto conversation = conversations.at(row);
   // filteredConversation(row);
    NSTableCellView* result;
    
    result = [tableView makeViewWithIdentifier:@"MainCell" owner:tableView];
    
    NSTextField* displayName = [result viewWithTag:DISPLAYNAME_TAG];
    NSTextField* displayRingID = [result viewWithTag:RING_ID_LABEL];
    [displayName setStringValue:@""];
    [displayRingID setStringValue:@""];
    NSImageView* photoView = [result viewWithTag:IMAGE_TAG];
    NSString* displayNameString = bestNameForConversation(conversation, *convModel);
    NSString* displayIDString = bestIDForConversation(conversation, *convModel);
    if(displayNameString.length == 0 || [displayNameString isEqualToString:displayIDString]) {
        [displayName setStringValue:displayIDString];
        [displayRingID setHidden:YES];
    }
    else {
        [displayName setStringValue:displayNameString];
        [displayRingID setStringValue:displayIDString];
        [displayRingID setHidden:NO];
    }
    auto& imageManip = reinterpret_cast<Interfaces::ImageManipulationDelegate&>(GlobalInstances::pixmapManipulator());
    NSImage* image = QtMac::toNSImage(qvariant_cast<QPixmap>(imageManip.conversationPhoto(conversation, convModel->owner)));
    if(image) {
        [NSLayoutConstraint deactivateConstraints:[photoView constraints]];
        NSArray* constraints = [NSLayoutConstraint
                                constraintsWithVisualFormat:@"H:[photoView(54)]"
                                options:0
                                metrics:nil                                                                          views:NSDictionaryOfVariableBindings(photoView)];
        [NSLayoutConstraint activateConstraints:constraints];
    } else {
        [NSLayoutConstraint deactivateConstraints:[photoView constraints]];
        NSArray* constraints = [NSLayoutConstraint
                                constraintsWithVisualFormat:@"H:[photoView(0)]"
                                options:0
                                metrics:nil                                                                          views:NSDictionaryOfVariableBindings(photoView)];
        [NSLayoutConstraint activateConstraints:constraints];
    }
    [photoView setImage: image];
    
    NSView* presenceView = [result viewWithTag:PRESENCE_TAG];
    [presenceView setHidden:YES];
    if (!conversation.participants.empty()){
        try {
            auto contact = convModel->owner.contactModel->getContact(conversation.participants[0]);
            if (contact.isPresent) {
                [presenceView setHidden:NO];
            }
        } catch (std::out_of_range& e) {
            NSLog(@"viewForTableColumn: getContact - out of range");
        }
    }
    return result;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    return 60.0;
}

#pragma mark - NSTableDataSource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if (tableView == smartView && convModel != nullptr) {
//        auto it = getConversationFromUid(currentConversation, *convModel);
        return convModel->getFilteredConversations(lrc::api::profile::Type::RING).size();
//getFilteredConversations(lrc::api::profile::Type::RING))//.size();//convModel_->allFilteredConversations().size();
    }
    
    return 0;
}


@end
