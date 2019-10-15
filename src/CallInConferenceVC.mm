//
//  CallInConferenceVC.m
//  Jami
//
//  Created by kate on 2019-10-11.
//

#import "CallInConferenceVC.h"
#import "views/IconButton.h"
#import "views/ITProgressIndicator.h"

///LRC
#import <api/newcallmodel.h>
#import <api/call.h>
#import <api/conversationmodel.h>
#import <api/account.h>
#import <api/contactmodel.h>
#import <api/contact.h>

@interface CallInConferenceVC () {
    std::string callUId;
    const lrc::api::account::Info *accountInfo;
}

@property (unsafe_unretained) IBOutlet NSImageView* contactPhoto;
@property (unsafe_unretained) IBOutlet NSView* imageContainer;
@property (unsafe_unretained) IBOutlet NSTextField* contactNameLabel;
@property (unsafe_unretained) IBOutlet NSTextField* callStateLabel;
@property (unsafe_unretained) IBOutlet NSTextField* contactIdLabel;
@property (unsafe_unretained) IBOutlet IconButton* cancelCallButton;
@property (unsafe_unretained) IBOutlet ITProgressIndicator *loadingIndicator;
@property QMetaObject::Connection callStateChanged;

@end

@implementation CallInConferenceVC
@synthesize loadingIndicator,cancelCallButton,contactIdLabel,callStateLabel,contactNameLabel,contactPhoto, imageContainer;

-(id) initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
               callId:(const std::string)callId
          accountInfo:(const lrc::api::account::Info *)accInfo {
    if (self =  [self initWithNibName: nibNameOrNil bundle:nibBundleOrNil])
    {
        callUId = callId;
        accountInfo = accInfo;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    auto* callModel = accountInfo->callModel.get();
    auto currentCall = callModel->getCall(callUId);
    auto uri = currentCall.peerUri;
    auto contact = accountInfo->contactModel->getContact(uri);
    NSData *imageData = [[NSData alloc] initWithBase64EncodedString:@(contact.profileInfo.avatar.c_str()) options:NSDataBase64DecodingIgnoreUnknownCharacters];
//    if(!contact.profileInfo.avatar.empty() && imageData) {
//        [self.contactPhoto setImage: [[NSImage alloc] initWithData:imageData]];
//         [loadingIndicator setAnimates:YES];
//    } else {
        [imageContainer setHidden:YES];
    //}
    NSString *name = @(contact.profileInfo.alias.c_str());
    if (name.length == 0) {
        name = @(contact.registeredName.c_str());
    }
    if (name.length == 0) {
        name = @(contact.profileInfo.uri.c_str());
    }
    self.contactNameLabel.stringValue = name;
    QObject::disconnect(self.callStateChanged);
    self.callStateChanged = QObject::connect(callModel,
                                                &lrc::api::NewCallModel::callStatusChanged,
                                                [self](const std::string callId) {
                                                    [self updateCall];
                                                });
}

-(void) updateCall
{
    if (accountInfo == nil)
        return;
    
    auto* callModel = accountInfo->callModel.get();
    if (not callModel->hasCall(callUId)) {
        return;
    }
    
    auto currentCall = callModel->getCall(callUId);
    using Status = lrc::api::call::Status;
    callStateLabel.stringValue = @(to_string(currentCall.status).c_str());
    switch (currentCall.status) {
        case Status::IN_PROGRESS:
        //case Status::CONNECTED:
        case Status::ENDED:
        case Status::TERMINATING:
        case Status::INVALID:
            QObject::disconnect(self.callStateChanged);
            [self.delegate removePreviewForContactUri: currentCall.peerUri];
            break;
    }
}

- (void)awakeFromNib
{
//    [widgetsContainer setWantsLayer:YES];
//    widgetsContainer.layer.backgroundColor = [[NSColor blackColor] CGColor];
//    widgetsContainer.layer.cornerRadius = 5;
//    widgetsContainer.layer.masksToBounds = YES;
    [loadingIndicator setColor:[NSColor whiteColor]];
    [loadingIndicator setNumberOfLines:200];
    [loadingIndicator setWidthOfLine:2];
    [loadingIndicator setLengthOfLine:2];
    [loadingIndicator setInnerMargin:20];
    [contactPhoto setWantsLayer:YES];
    contactPhoto.layer.cornerRadius = contactPhoto.frame.size.width * 0.5;
    contactPhoto.layer.masksToBounds = YES;
    contactNameLabel.textColor = [NSColor textColor];
    contactIdLabel.textColor = [NSColor textColor];
    callStateLabel.textColor = [NSColor textColor];
}

-(NSImage *) getContactImageOfSize: (double) size withDefaultAvatar:(BOOL) shouldDrawDefault {
    auto* callModel = accountInfo->callModel.get();
    auto currentCall = callModel->getCall(callUId);
    auto uri = currentCall.peerUri;
    auto contact = accountInfo->contactModel->getContact(uri);
    NSData *imageData = [[NSData alloc] initWithBase64EncodedString:@(contact.profileInfo.avatar.c_str()) options:NSDataBase64DecodingIgnoreUnknownCharacters];
    return [[NSImage alloc] initWithData:imageData];
}

- (IBAction)hangUp:(id)sender {
    if (accountInfo == nil)
        return;

    auto* callModel = accountInfo->callModel.get();
    callModel->hangUp(callUId);
}

@end
