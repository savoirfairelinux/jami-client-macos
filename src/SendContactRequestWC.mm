//
//  SendContactRequestWC.m
//  Ring
//
//  Created by Kateryna Kostiuk on 2017-05-10.
//
//

//Qt
#import <QItemSelectionModel>

//LRC
#import <account.h>
#import <person.h>
#import <availableAccountModel.h>
#import <contactRequest.h>
#import <pendingContactRequestModel.h>

#import "SendContactRequestWC.h"

#import "GeneralPrefsVC.h"

#import <Quartz/Quartz.h>

//Qt
#import <QSize>
#import <QtMacExtras/qmacfunctions.h>
#import <QPixmap>

//LRC
#import <categorizedhistorymodel.h>
#import <profilemodel.h>
#import <profile.h>
#import <person.h>
#import <globalinstances.h>

#if ENABLE_SPARKLE
#import <Sparkle/Sparkle.h>
#endif

#import "Constants.h"
#import "views/NSImage+Extensions.h"
#import "delegates/ImageManipulationDelegate.h"

@interface SendContactRequestWC () {
__unsafe_unretained IBOutlet NSTextField* userName;
__unsafe_unretained IBOutlet NSTextField* ringID;
__unsafe_unretained IBOutlet NSImageView* photoView;
    
}

@end

@implementation SendContactRequestWC

- (void)windowDidLoad {
    [super windowDidLoad];
    Person* person = self.contactMethod->contact();
    [photoView setWantsLayer: YES];

    if (person) {
        auto photo = GlobalInstances::pixmapManipulator().contactPhoto(person, {140,140});
        [photoView setImage:QtMac::toNSImage(qvariant_cast<QPixmap>(photo))];
       // [profileNameField setStringValue:pro->person()->formattedName().toNSString()];
    }

    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}
-(IBAction) sendContactRequest:(id)sender
{
    if(self.contactMethod->account() == nullptr) {
        return;
    }
    if (self.contactMethod->account()->sendContactRequest(self.contactMethod)) {
        [self close];
        return;
    } else if ([self chosenAccount]){
        self.contactMethod->setAccount([self chosenAccount]);
        [self chosenAccount]->sendContactRequest(self.contactMethod);
            [self close];
    }

}

- (IBAction) cancelPressed:(id)sender
{
    [self close];
}

-(Account* ) chosenAccount
{
    QModelIndex index = AvailableAccountModel::instance().selectionModel()->currentIndex();
    if(!index.isValid())
        return nil;
    return index.data(static_cast<int>(Account::Role::Object)).value<Account*>();
}

@end
