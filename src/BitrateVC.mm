/*
 *  Copyright (C) 2004-2015 Savoir-faire Linux Inc.
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
 *
 *  Additional permission under GNU GPL version 3 section 7:
 *
 *  If you modify this program, or any covered work, by linking or
 *  combining it with the OpenSSL project's OpenSSL library (or a
 *  modified version of that library), containing parts covered by the
 *  terms of the OpenSSL or SSLeay licenses, Savoir-Faire Linux Inc.
 *  grants you additional permission to convey the resulting work.
 *  Corresponding Source for a non-source form of such a combination
 *  shall include the source code for the parts of OpenSSL used as well
 *  as that of the covered work.
 */

#import "BitrateVC.h"

#import <QSortFilterProxyModel>

#import <audio/codecmodel.h>
#import <callmodel.h>
#import <accountmodel.h>


@interface BitrateVC ()
@property (unsafe_unretained) IBOutlet NSSlider *bitrateSlider;

@end

@implementation BitrateVC

- (void)viewWillAppear
{
    // Get the first video codec of the selected call and use this value as default
    auto selectedCall = CallModel::instance().selectedCall();
    if (selectedCall) {
        int bitrate = selectedCall->account()->codecModel()->videoCodecs()->index(0,0).data(static_cast<int>(CodecModel::Role::BITRATE)).toInt();
        [self.bitrateSlider setNumberOfTickMarks:4];
        [self.bitrateSlider setIntValue:bitrate];
        [self.bitrateSlider setToolTip:[NSString stringWithFormat:@"%i bit/s",bitrate]];
    }
}

- (IBAction)valueChanged:(id)sender
{
    if (const auto& codecModel = CallModel::instance().selectedCall()->account()->codecModel()) {
        const auto& videoCodecs = codecModel->videoCodecs();
        for (int i=0; i < videoCodecs->rowCount();i++) {
            const auto& idx = videoCodecs->index(i,0);
            videoCodecs->setData(idx, QString::number((unsigned int)[sender integerValue]), CodecModel::Role::BITRATE);
        }
        codecModel << CodecModel::EditAction::SAVE;
    }
    [self.bitrateSlider setToolTip:[NSString stringWithFormat:@"%i bit/s",[sender intValue]]];
}

@end
