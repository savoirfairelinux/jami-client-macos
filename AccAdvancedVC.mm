/************************************************************************************
 *   Copyright (C) 2014-2015 by Savoir-Faire Linux                                  *
 *   Author : Alexandre Lision <alexandre.lision@savoirfairelinux.com>              *
 *                                                                                  *
 *   This library is free software; you can redistribute it and/or                  *
 *   modify it under the terms of the GNU Lesser General Public                     *
 *   License as published by the Free Software Foundation; either                   *
 *   version 2.1 of the License, or (at your option) any later version.             *
 *                                                                                  *
 *   This library is distributed in the hope that it will be useful,                *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of                 *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU              *
 *   Lesser General Public License for more details.                                *
 *                                                                                  *
 *   You should have received a copy of the GNU Lesser General Public               *
 *   License along with this library; if not, write to the Free Software            *
 *   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA *
 ***********************************************************************************/

#define REGISTRATION_TAG 0
#define LOCALPORT_TAG 1
#define STUNURL_TAG 2
#define PUBLICADDR_TAG 3
#define PUBLICPORT_TAG 4
#define MINAUDIO_TAG 5
#define MAXAUDIO_TAG 6
#define MINVIDEO_TAG 7
#define MAXVIDEO_TAG 8

#import "AccAdvancedVC.h"

@interface AccAdvancedVC ()

@property Account* privateAccount;
@property (assign) IBOutlet NSTextField *registrationField;
@property (assign) IBOutlet NSTextField *localPortField;
@property (assign) IBOutlet NSButton *isUsingSTUN;

@property (assign) IBOutlet NSTextField *STUNserverURLField;
@property (assign) IBOutlet NSTextField *minAudioRTPRange;
@property (assign) IBOutlet NSTextField *maxAudioRTPRange;
@property (assign) IBOutlet NSTextField *minVideoRTPRange;
@property (assign) IBOutlet NSTextField *maxVideoRTPRange;


@property (assign) IBOutlet NSStepper *registrationStepper;
@property (assign) IBOutlet NSStepper *localPortStepper;
@property (assign) IBOutlet NSStepper *minAudioPortStepper;
@property (assign) IBOutlet NSStepper *maxAudioPortStepper;
@property (assign) IBOutlet NSStepper *minVideoPortStepper;
@property (assign) IBOutlet NSStepper *maxVideoPortStepper;

@property (assign) IBOutlet NSMatrix *publishAddrAndPortRadioGroup;
@property (assign) IBOutlet NSTextField *publishedAddrField;
@property (assign) IBOutlet NSTextField *publishedPortField;

@end

@implementation AccAdvancedVC
@synthesize privateAccount;
@synthesize registrationField;
@synthesize localPortField;
@synthesize isUsingSTUN;
@synthesize STUNserverURLField;
@synthesize minAudioRTPRange;
@synthesize maxAudioRTPRange;
@synthesize minVideoRTPRange;
@synthesize maxVideoRTPRange;
@synthesize registrationStepper;
@synthesize localPortStepper;
@synthesize minAudioPortStepper;
@synthesize maxAudioPortStepper;
@synthesize minVideoPortStepper;
@synthesize maxVideoPortStepper;
@synthesize publishAddrAndPortRadioGroup;
@synthesize publishedAddrField;
@synthesize publishedPortField;

- (void)awakeFromNib
{
    NSLog(@"INIT Advanced VC");
    [registrationStepper setTag:REGISTRATION_TAG];
    [localPortStepper setTag:LOCALPORT_TAG];
    [minAudioPortStepper setTag:MINAUDIO_TAG];
    [maxAudioPortStepper setTag:MAXAUDIO_TAG];
    [minVideoPortStepper setTag:MINVIDEO_TAG];
    [maxVideoPortStepper setTag:MAXVIDEO_TAG];
    
    [registrationField setTag:REGISTRATION_TAG];
    [localPortField setTag:LOCALPORT_TAG];
    [minAudioRTPRange setTag:MINAUDIO_TAG];
    [maxAudioRTPRange setTag:MAXAUDIO_TAG];
    [minVideoRTPRange setTag:MINVIDEO_TAG];
    [maxVideoRTPRange setTag:MAXVIDEO_TAG];
    
    [STUNserverURLField setTag:STUNURL_TAG];
    [publishedPortField setTag:PUBLICPORT_TAG];
    [publishedAddrField setTag:PUBLICADDR_TAG];
    
}

- (void)loadAccount:(Account *)account
{
    privateAccount = account;
    [self updateControlsWithTag:REGISTRATION_TAG];
    [self updateControlsWithTag:LOCALPORT_TAG];
    [self updateControlsWithTag:MINAUDIO_TAG];
    [self updateControlsWithTag:MAXAUDIO_TAG];
    [self updateControlsWithTag:MINVIDEO_TAG];
    [self updateControlsWithTag:MAXVIDEO_TAG];
    
    [STUNserverURLField setStringValue:privateAccount->sipStunServer().toNSString()];
    [isUsingSTUN setState:privateAccount->isSipStunEnabled()?NSOnState:NSOffState];
    [STUNserverURLField setEnabled:privateAccount->isSipStunEnabled()];
    
    if(privateAccount->isPublishedSameAsLocal())
        [publishAddrAndPortRadioGroup selectCellAtRow:0 column:0];
    else {
        [publishAddrAndPortRadioGroup selectCellAtRow:1 column:0];
    }
    
    [publishedAddrField setStringValue:privateAccount->publishedAddress().toNSString()];
    [publishedPortField setIntValue:privateAccount->publishedPort()];
    [publishedAddrField setEnabled:!privateAccount->isPublishedSameAsLocal()];
    [publishedPortField setEnabled:!privateAccount->isPublishedSameAsLocal()];
}

#pragma mark - NSTextFieldDelegate methods

- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor
{
    NSLog(@"textShouldBeginEditing");
    return YES;
}

- (void)control:(NSControl *)control didFailToValidatePartialString:(NSString *)string errorDescription:(NSString *)error
{
    NSLog(@"didFailToValidatePartialString");
}

-(void)controlTextDidBeginEditing:(NSNotification *)obj
{

}

-(void)controlTextDidChange:(NSNotification *)notif
{
    NSTextField *textField = [notif object];
    NSRange test = [[textField currentEditor] selectedRange];

    [self valueDidChange:textField];
    //FIXME: saving account lose focus because in NSTreeController we remove and reinsert row so View selction change
    //privateAccount << Account::EditAction::SAVE;
    [textField.window makeFirstResponder:textField];
    [[textField currentEditor] setSelectedRange:test];
}

- (IBAction) valueDidChange: (id) sender
{
    switch ([sender tag]) {
        case REGISTRATION_TAG:
            privateAccount->setRegistrationExpire([sender integerValue]);
            break;
        case LOCALPORT_TAG:
            privateAccount->setLocalPort([sender integerValue]);
            break;
        case STUNURL_TAG:
            privateAccount->setSipStunServer([[sender stringValue] UTF8String]);
            break;
        case PUBLICADDR_TAG:
            privateAccount->setPublishedAddress([[sender stringValue] UTF8String]);
            break;
        case PUBLICPORT_TAG:
            privateAccount->setPublishedPort([sender integerValue]);
            break;
        case MINAUDIO_TAG:
            privateAccount->setAudioPortMin([sender integerValue]);
            break;
        case MAXAUDIO_TAG:
            privateAccount->setAudioPortMax([sender integerValue]);
            break;
        case MINVIDEO_TAG:
            privateAccount->setVideoPortMin([sender integerValue]);
            break;
        case MAXVIDEO_TAG:
            privateAccount->setVideoPortMax([sender integerValue]);
            break;
        default:
            break;
    }
    [self updateControlsWithTag:[sender tag]];
}

- (IBAction)toggleSTUN:(NSButton *)sender
{
    privateAccount->setSipStunEnabled([sender state]==NSOnState);
    [STUNserverURLField setEnabled:privateAccount->isSipStunEnabled()];
}

- (IBAction)didSwitchPublishedAddress:(NSMatrix *)matrix
{
    NSInteger row = [matrix selectedRow];
    if(row == 0) {
        privateAccount->setPublishedSameAsLocal(YES);
    } else {
        privateAccount->setPublishedSameAsLocal(NO);
    }
    [publishedAddrField setEnabled:!privateAccount->isPublishedSameAsLocal()];
    [publishedPortField setEnabled:!privateAccount->isPublishedSameAsLocal()];
    
}

- (void) updateControlsWithTag:(NSInteger) tag
{
    switch (tag) {
        case REGISTRATION_TAG:
            [registrationStepper setIntegerValue:privateAccount->registrationExpire()];
            [registrationField setIntegerValue:privateAccount->registrationExpire()];
            break;
        case LOCALPORT_TAG:
            [localPortStepper setIntegerValue:privateAccount->localPort()];
            [localPortField setIntegerValue:privateAccount->localPort()];
            break;
        case MINAUDIO_TAG:
            [minAudioPortStepper setIntegerValue:privateAccount->audioPortMin()];
            [minAudioRTPRange setIntegerValue:privateAccount->audioPortMin()];
            break;
        case MAXAUDIO_TAG:
            [maxAudioPortStepper setIntegerValue:privateAccount->audioPortMax()];
            [maxAudioRTPRange setIntegerValue:privateAccount->audioPortMax()];
            break;
        case MINVIDEO_TAG:
            [minVideoPortStepper setIntegerValue:privateAccount->videoPortMin()];
            [minVideoRTPRange setIntegerValue:privateAccount->videoPortMin()];
            break;
        case MAXVIDEO_TAG:
            [maxVideoPortStepper setIntegerValue:privateAccount->videoPortMax()];
            [maxVideoRTPRange setIntegerValue:privateAccount->videoPortMax()];
            break;
        default:
            break;
    }
}

@end
