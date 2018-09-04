/*
 *  Copyright (C) 22018 Savoir-faire Linux Inc.
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


//cocoa
#import <Quartz/Quartz.h>

//LRC
#import <api/lrc.h>
#import <api/newaccountmodel.h>
#import <account.h>

//ring
#import "AddSIPAccountVC.h"
#import "views/NSImage+Extensions.h"

@interface AddSIPAccountVC () {
    __unsafe_unretained IBOutlet NSButton* photoView;
    __unsafe_unretained IBOutlet NSImageView* addProfilePhotoImage;
    __unsafe_unretained IBOutlet NSTextField* displayNameField;
    __unsafe_unretained IBOutlet NSTextField* userNameField;
    __unsafe_unretained IBOutlet NSSecureTextField* passwordField;
    __unsafe_unretained IBOutlet NSTextField* serverField;
}
@end

@implementation AddSIPAccountVC

QMetaObject::Connection accountCreated;
std::string accountToCreate;
NSTimer* timeoutTimer;
@synthesize accountModel;

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setAutoresizingMask: NSViewHeightSizable];
}

-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil accountmodel:(lrc::api::NewAccountModel*) accountModel {
    if (self =  [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.accountModel = accountModel;
    }
    return self;
}

-(void) show {
    [photoView setWantsLayer: YES];
    photoView.layer.cornerRadius = photoView.frame.size.width / 2;
    photoView.layer.masksToBounds = YES;
    [photoView setBordered:YES];
    [addProfilePhotoImage setWantsLayer: YES];
}

- (IBAction)cancel:(id)sender
{
    [self.delegate close];
}

- (IBAction)addAccount:(id)sender
{
    NSString* displayName = [displayNameField.stringValue isEqualToString:@""] ? @"SIP" : displayNameField.stringValue;

    QObject::disconnect(accountCreated);
    accountCreated = QObject::connect(self.accountModel,
                                      &lrc::api::NewAccountModel::accountAdded,
                                      [self] (const std::string& accountID) {
                                          if(accountID.compare(accountToCreate) != 0) {
                                              return;
                                          }
                                          if([photoView image]) {
                                              NSImage *avatarImage = [photoView image];
                                              auto imageToBytes = QByteArray::fromNSData([avatarImage TIFFRepresentation]).toBase64();
                                              std::string imageToString = std::string(imageToBytes.constData(), imageToBytes.length());
                                              self.accountModel->setAvatar(accountID, imageToString);
                                          }
                                          lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(accountID);
                                          if(![serverField.stringValue isEqualToString:@""]) {
                                              accountProperties.hostname = [serverField.stringValue UTF8String];
                                          }
                                          if(![passwordField.stringValue isEqualToString:@""]) {
                                              accountProperties.password = [passwordField.stringValue UTF8String];
                                          }
                                          if(![userNameField.stringValue isEqualToString:@""]) {
                                              accountProperties.username = [userNameField.stringValue UTF8String];
                                          }
                                          self.accountModel->setAccountConfig(accountID, accountProperties);
                                          QObject::disconnect(accountCreated);
                                          [self.delegate close];
                                      });
    accountToCreate = self.accountModel->createNewAccount(lrc::api::profile::Type::SIP, [@"SIP" UTF8String]);

    timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:5
                                                    target:self
                                                  selector:@selector(addingAccountTimeout) userInfo:nil
                                                   repeats:NO];
}

-(void) addingAccountTimeout {
    QObject::disconnect(accountCreated);
    [self.delegate close];
}


- (IBAction)editPhoto:(id)sender
{
    auto pictureTaker = [IKPictureTaker pictureTaker];

    [pictureTaker beginPictureTakerSheetForWindow:[self.delegate window]
                                     withDelegate:self
                                   didEndSelector:@selector(pictureTakerDidEnd:returnCode:contextInfo:)
                                      contextInfo:nil];

}

- (void)pictureTakerDidEnd:(IKPictureTaker *) picker
                returnCode:(NSInteger) code
               contextInfo:(void*) contextInfo
{
    //do nothing when editing canceled 
    if (code == 0) {
        return;
    }
    if (auto outputImage = [picker outputImage]) {
        [photoView setBordered:NO];
        auto image = [picker inputImage];
        CGFloat newSize = MIN(image.size.height, image.size.width);
        outputImage = [outputImage cropImageToSize:CGSizeMake(newSize, newSize)];
        [photoView setImage:outputImage];
        [addProfilePhotoImage setHidden:YES];
    } else if(!photoView.image) {
        [photoView setBordered:YES];
        [addProfilePhotoImage setHidden:NO];
    }
}

@end
