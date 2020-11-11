/*
 *  Copyright (C) 22019 Savoir-faire Linux Inc.
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
#import <AVFoundation/AVFoundation.h>

//LRC
#import <api/lrc.h>
#import <api/newaccountmodel.h>

//ring
#import "AddSIPAccountVC.h"
#import "views/NSImage+Extensions.h"
#import "Constants.h"

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
QString accountToCreate;
NSTimer* timeoutTimer;
@synthesize accountModel;

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable];
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
    [self.delegate showView:self.view];
}

- (IBAction)cancel:(id)sender
{
    [self.delegate completedWithSuccess: NO];
}

- (IBAction)addAccount:(id)sender
{
    NSString* displayName = [displayNameField.stringValue isEqualToString:@""] ? @"SIP" : displayNameField.stringValue;

    QObject::disconnect(accountCreated);
    accountCreated = QObject::connect(self.accountModel,
                                      &lrc::api::NewAccountModel::accountAdded,
                                      [self] (const QString& accountID) {
                                          if([photoView image]) {
                                              NSImage *avatarImage = [photoView image];
                                              NSData* imageData = [avatarImage TIFFRepresentation];
                                              NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData: imageData];
                                              NSDictionary *imageProps = [[NSDictionary alloc] init];
                                              imageData = [imageRep representationUsingType:NSPNGFileType properties:imageProps];
                                              auto imageToBytes = QByteArray::fromNSData(imageData).toBase64();
                                              self.accountModel->setAvatar(accountID, QString(imageToBytes));
                                          }
                                          lrc::api::account::ConfProperties_t accountProperties = self.accountModel->getAccountConfig(accountID);
                                          if(![serverField.stringValue isEqualToString:@""]) {
                                              accountProperties.hostname = QString::fromNSString(serverField.stringValue);
                                          }
                                          if(![passwordField.stringValue isEqualToString:@""]) {
                                              accountProperties.password = QString::fromNSString(passwordField.stringValue);
                                          }
                                          self.accountModel->setAccountConfig(accountID, accountProperties);
                                          QObject::disconnect(accountCreated);
                                          [self.delegate completedWithSuccess: YES];
                                      });
    accountToCreate = self.accountModel->createNewAccount(lrc::api::profile::Type::SIP, QString::fromNSString(displayName), "", "", "", QString::fromNSString(userNameField.stringValue));

    timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:5
                                                    target:self
                                                  selector:@selector(addingAccountTimeout) userInfo:nil
                                                   repeats:NO];
}

-(void) addingAccountTimeout {
    QObject::disconnect(accountCreated);
    [self.delegate completedWithSuccess: YES];
}


- (IBAction)editPhoto:(id)sender
{
    auto pictureTaker = [IKPictureTaker pictureTaker];
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 101400
    if (@available(macOS 10.14, *)) {
        AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        if(authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied)
        {
            [pictureTaker setValue:0 forKey:IKPictureTakerAllowsVideoCaptureKey];
        }

        if(authStatus == AVAuthorizationStatusNotDetermined)
        {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if(!granted){
                    [pictureTaker setValue:0 forKey:IKPictureTakerAllowsVideoCaptureKey];
                }
            }];
        }
    }
#endif
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
        CGFloat newSize = MIN(MIN(image.size.height, image.size.width), MAX_IMAGE_SIZE);
        outputImage = [outputImage imageResizeInsideMax: newSize];
        [photoView setImage:outputImage];
        [addProfilePhotoImage setHidden:YES];
    } else if(!photoView.image) {
        [photoView setBordered:YES];
        [addProfilePhotoImage setHidden:NO];
    }
}

@end
