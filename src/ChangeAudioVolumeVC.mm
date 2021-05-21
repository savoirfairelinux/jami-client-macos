//
//  ChangeAudioVolumeVC.m
//  Jami
//
//  Created by kateryna on 2021-05-20.
//

#import "ChangeAudioVolumeVC.h"
#import "views/NSColor+RingTheme.h"

@interface ChangeAudioVolumeVC () {
    __unsafe_unretained IBOutlet NSSlider* volumeSlider;
    __unsafe_unretained IBOutlet NSButton* muteButton;
}

@end

@implementation ChangeAudioVolumeVC

- (void)viewDidLoad {
    [super viewDidLoad];
    NSImage* image =  [NSColor image: muteButton.image tintedWithColor: [NSColor whiteColor]];
    muteButton.image = image;
    volumeSlider.trackFillColor = [NSColor whiteColor];
    //self.view.wantsLayer = YES;
//    [NSAnimationContext beginGrouping];
//    [[NSAnimationContext currentContext] setDuration:1.0];
   // volumeIndicator.frameCenterRotation = 90;
    //volumeIndicator.frameCenterRotation = 90;
//    [volumeIndicator rotateByAngle:90];
//    volumeIndicator.fillColor = [NSColor blueColor];
//    [volumeIndicator setNeedsDisplay:YES];
//    [self.view setNeedsDisplay:YES];
//    [volumeIndicator displayIfNeeded];
//    [self.view displayIfNeeded];

//    [[volumeIndicator animator] setFrameCenterRotation:90.0];
//
//    [NSAnimationContext endGrouping];
}

@end
