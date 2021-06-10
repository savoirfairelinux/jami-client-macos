/*
 *  Copyright (C) 2016-2019 Savoir-faire Linux Inc.
 *  Author: Alexandre Lision <alexandre.lision@savoirfairelinux.com>
 *  Author: Anthony Léonard <anthony.leonard@savoirfairelinux.com>
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

#import "IMTableCellView.h"
#import "NSColor+RingTheme.h"
#import <QuartzCore/QuartzCore.h>
#import <qstring.h>

@implementation IMTableCellView {
    QString interaction;
}

NSString* const MESSAGE_MARGIN = @"10";
NSString* const TIME_BOX_HEIGHT = @"34";

@synthesize msgView, msgBackground, timeBox, transferedImage;
@synthesize photoView;
@synthesize acceptButton;
@synthesize declineButton;
@synthesize progressIndicator;
@synthesize statusLabel;
@synthesize openImagebutton;
@synthesize openFileButton;
@synthesize compozingIndicator2, compozingIndicator3, compozingIndicator1;

- (void) setupDirection
{
    if ([self.identifier containsString:@"Right"]) {
        self.msgBackground.pointerDirection = RIGHT;
        self.msgBackground.bgColor = [NSColor ringLightBlue];
        self.messageFailed.image = [NSColor image: [NSImage imageNamed:@"ic_action_cancel.png"] tintedWithColor:[[NSColor errorColor] lightenColorByValue:0.05]];
    }
    else {
        self.msgBackground.pointerDirection = LEFT;
        self.msgBackground.bgColor = @available(macOS 10.14, *) ? [NSColor controlColor] : [NSColor whiteColor];
    }
}

- (void) setupForInteraction:(const QString&)inter
{
    interaction = inter;
    [self setupDirection];
    [self.msgView setBackgroundColor:[NSColor clearColor]];
    [self.msgView setString:@""];
    [self.msgView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.msgBackground setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.msgView setEditable:NO];
    acceptButton.image = [NSColor image: [NSImage imageNamed:@"ic_file_upload.png"] tintedWithColor:[NSColor greenSuccessColor]];
    declineButton.image = [NSColor image: [NSImage imageNamed:@"ic_action_cancel.png"] tintedWithColor:[NSColor redColor]];
    msgView.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
}

- (void) setupForInteraction:(const QString&)inter isFailed:(bool) failed {
    [self setupForInteraction:inter];
}

- (void) updateMessageConstraint:(CGFloat) width andHeight: (CGFloat) height timeIsVisible: (bool) visible isTopPadding: (bool) padding
{
    self.messageWidthConstraint.constant = width;
    self.messageHeightConstraint.constant = height;
    [self.timeBox setHidden:!visible];
    //update message frame immediatly
    [self.msgView setNeedsDisplay:YES];
}

- (void)updateHeightConstraints:(CGFloat)height {
    self.messageHeightConstraint.constant = height;
}
- (void)updateWidthConstraints:(CGFloat)width {
    self.messageWidthConstraint.constant = width;
}

- (void) updateImageConstraintWithMax: (CGFloat) maxDimension {
    if(!self.transferedImage) {return;}
    CGFloat widthScaleFactor = maxDimension / transferedImage.image.size.width;
    CGFloat heightScaleFactor = maxDimension / transferedImage.image.size.height;
    NSSize size = NSZeroSize;
    if((widthScaleFactor >= 1) && (heightScaleFactor >= 1)) {
        size.width = transferedImage.image.size.width;
        size.height = transferedImage.image.size.height;
    } else {
        CGFloat scale = MIN(widthScaleFactor, heightScaleFactor);
        size.width = transferedImage.image.size.width * scale;
        size.height = transferedImage.image.size.height * scale;
    }
    [self.msgBackground setHidden:YES];
    [self updateHeightConstraints: size.height];
    [self updateWidthConstraints: size.width];
}

- (QString&)interaction
{
    return interaction;
}

- (void) animateCompozingIndicator: (BOOL) animate
{
    if (!animate) {
        [[compozingIndicator1 layer] removeAllAnimations];
        [[compozingIndicator2 layer] removeAllAnimations];
        [[compozingIndicator3 layer] removeAllAnimations];
        return;
    }
    [self startBlinkAnimation:compozingIndicator1 withDelay:0];
    [self startBlinkAnimation:compozingIndicator2 withDelay:0.5];
    [self startBlinkAnimation:compozingIndicator3 withDelay:1];
}

- (void) startBlinkAnimation:(NSView*) view withDelay:(CGFloat) delay {
    [view setWantsLayer: YES];
    view.layer.backgroundColor = [self checkIsDarkMode] ? [NSColor.whiteColor CGColor] : [NSColor.ringDarkBlue CGColor];
    view.layer.cornerRadius = 5;
    view.layer.masksToBounds = true;
    if (delay == 0) {
        [self blinkAnimation:view];
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self blinkAnimation:view];
    });
}

- (void) blinkAnimation:(NSView*) view {
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    [animation setFromValue:[NSNumber numberWithFloat:1.0]];
    [animation setToValue:[NSNumber numberWithFloat:0.2]];
    [animation setDuration:0.7];
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
    [animation setAutoreverses:YES];
    [animation setRepeatCount:HUGE_VALF];
    [[view layer] addAnimation:animation forKey:@"opacity"];
}

-(BOOL)checkIsDarkMode {
    NSAppearance *appearance = NSAppearance.currentAppearance;
    if (@available(*, macOS 10.14)) {
        NSString *interfaceStyle = [NSUserDefaults.standardUserDefaults valueForKey:@"AppleInterfaceStyle"];
        return [interfaceStyle isEqualToString:@"Dark"];
    }
    return NO;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.messageWidthConstraint.constant = 1;
    self.messageHeightConstraint.constant = 1;
}

-(void) rightMouseDown:(NSEvent *)event
{
    if ( self.onRightClick != nil ) {
        self.onRightClick(event);
    }
}

@end
