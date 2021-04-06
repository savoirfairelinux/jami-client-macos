/*
 *  Copyright (C) 2015-2016 Savoir-faire Linux Inc.
 *  Author: Alexandre Lision <alexandre.lision@savoirfairelinux.com>
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
#import "PluginPrefsVC.h"
#import "AppDelegate.h"

#import <QuartzCore/QuartzCore.h>

#import <api/pluginmodel.h>

@interface PluginPrefsVC ()

@property (assign) IBOutlet NSButton *enablePluginsButton;

@end

@implementation PluginPrefsVC
@synthesize pluginModel;

-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil pluginModel:(lrc::api::PluginModel*) pluginModel
{
    if (self =  [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.pluginModel = pluginModel;
    }
    return self;
}

- (void)loadView {
    [super loadView];
    [self.enablePluginsButton setState: self.pluginModel->getPluginsEnabled()];
}

#pragma mark - actions

- (IBAction)toggleEnablePluginsButton:(NSButton *)sender {
    bool enabled = [sender state]==NSOnState;
    self.pluginModel->setPluginsEnabled(enabled);
}


- (IBAction)installPlugin:(id)sender {

    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:NO];
    [panel setCanChooseFiles:YES];
//    panel.delegate = self;
    if ([panel runModal] != NSFileHandlingPanelOKButton) return;
    if ([[panel URLs] lastObject] == nil) return;
    NSString * path = [[[panel URLs] lastObject] path];
    bool status = self.pluginModel->installPlugin(QString::fromNSString(path), true);
//    [[NSUserDefaults standardUserDefaults] setObject:path forKey:Preferences::DownloadFolder];
}
#pragma mark - signals

#pragma mark - dispaly

#pragma mark - NSOpenSavePanelDelegate delegate methods

- (BOOL) panel:(id)sender shouldEnableURL:(NSURL*)url {
    return YES;
}

@end
