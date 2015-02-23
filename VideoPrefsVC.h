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
#ifndef RING_VIDEOPREFSVC_H
#define RING_VIDEOPREFSVC_H

#import <Cocoa/Cocoa.h>

@interface VideoPrefsVC : NSViewController <NSMenuDelegate> {


    NSPopUpButton *videoDevicesButton;
    NSPopUpButton *channelsButton;
    NSPopUpButton *sizesButton;
    NSPopUpButton *ratesButton;
}

@property (assign) IBOutlet NSPopUpButton *videoDevicesButton;
@property (assign) IBOutlet NSPopUpButton *channelsButton;
@property (assign) IBOutlet NSPopUpButton *sizesButton;
@property (assign) IBOutlet NSPopUpButton *ratesButton;

@end

#endif // RING_VIDEOPREFSVC_H
