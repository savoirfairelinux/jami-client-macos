/*
 *  Copyright (C) 2015-2016 Savoir-faire Linux Inc.
 *  Author: Loïc Siret <loic.siret@savoirfairelinux.com>
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
#import "LoadingWCDelegate.h"
#import "views/ITProgressIndicator.h"

@interface AbstractLoadingWC : NSWindowController
{
@protected
    __unsafe_unretained IBOutlet NSView* errorContainer;

    __unsafe_unretained IBOutlet NSView* progressContainer;

    __unsafe_unretained IBOutlet NSView* initialContainer;
    __unsafe_unretained IBOutlet NSView* finalContainer;
}

/*
 * Delegate to inform about completion of the linking process between
 * a ContactMethod and a Person.
 */
@property (retain, nonatomic) id <LoadingWCDelegate> delegate;

/*
 * caller specific code to identify ongoing action
 */
@property (nonatomic) NSInteger actionCode;


- (id)initWithWindowNibName:(NSString *)nibName
                   delegate:(id <LoadingWCDelegate>) del
                 actionCode:(NSInteger) code;

- (id)initWithDelegate:(id <LoadingWCDelegate>) del
                 actionCode:(NSInteger) code;

- (void)close;
- (void)showLoading;
- (void)showError;
- (void)showFinal;

@end
