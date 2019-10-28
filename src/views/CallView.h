/*
 *  Copyright (C) 2015-2016 Savoir-faire Linux Inc.
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
#import <Cocoa/Cocoa.h>
#import <string>

@protocol CallDelegate;
@protocol CallDelegate

@optional

-(void) callShouldToggleFullScreen;
-(void) mouseIsMoving:(BOOL) move;
-(void) screenShare;
-(void) switchToDevice:(int)deviceID;
-(void) switchToFile:(std::string)uri;
-(std::vector<std::string>) getDeviceList;
-(NSString *) getDefaultDeviceName;

@end

@interface CallView : NSView <NSDraggingDestination, NSOpenSavePanelDelegate>
{
    //highlight the drop zone
    BOOL highlight;
}

- (id)initWithCoder:(NSCoder *)coder;

/**
 * Sets weither this view allow first click interactions
 */
@property BOOL shouldAcceptInteractions;

/**
 *  Delegate to inform about desire to move
 */
@property (nonatomic) id <CallDelegate> callDelegate;

@end
