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

@interface ContextualTableCellView : NSTableCellView

/**
 * List of subviews to show when mouse is entered
 */
@property (nonatomic) NSMutableArray* contextualsControls;

/**
 * List of subviews to show when mouse is leaved
 */
@property (nonatomic) NSMutableArray* contextualsControlsToHide;

/**
 * BOOL tracking if the mouse is hovering over the cell
 */
@property (nonatomic) BOOL isMouseOver;

/**
 * BOOL specifying if controls should be presented when mouse is hover
 */
@property (nonatomic) BOOL activeState;
/**
 * BOOL specifying if background behind controls should be blured
 */
@property (nonatomic) BOOL shouldBlurParentView;

@end
