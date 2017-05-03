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

#import <AppKit/NSApplication.h>

//Qt
#import <qapplication.h>
#import <globalinstances.h>
#import <QDebug>
#import <QDir>
#import <QTranslator>
#import <QLocale>

//LRC
#import <personmodel.h>
#import <recentmodel.h>
#import <categorizedhistorymodel.h>
#import <localhistorycollection.h>
#import <localprofilecollection.h>
#import <peerprofilecollection.h>
#import <numbercategorymodel.h>
#import <callmodel.h>
#import <profilemodel.h>

#import "backends/AddressBookBackend.h"
#import "delegates/ImageManipulationDelegate.h"
#import "AccountSelectionManager.h"

int main(int argc, const char *argv[]) {

    QDir dir(QString::fromUtf8(argv[0]));
    dir.cdUp();
    dir.cdUp();
    dir.cd("Plugins");
    QCoreApplication::addLibraryPath(dir.absolutePath());
    qDebug() << "" << QCoreApplication::libraryPaths();
    //Qt event loop will override native event loop
    QApplication* app = new QApplication(argc, const_cast<char**>(argv));
    app->setAttribute(Qt::AA_MacPluginApplication);

    dir.cdUp();

    //We need to check if primary language is an English variant (en, en-CA etc...) before installing a translator
    NSString* lang = [[NSLocale preferredLanguages] objectAtIndex:0];
    if (![lang rangeOfString:@"en"].location != NSNotFound) {
        QTranslator translator;
        if (translator.load(QLocale::system(), "lrc", "_", dir.absolutePath()+"/Resources/QtTranslations")) {
            app->installTranslator(&translator);
        } else {
            NSLog(@"Couldn't load qt translator");
        }
    }

    AccountSelectionManager* manager = [[AccountSelectionManager alloc] init];
    manager.selectChosenAccount;
    CallModel::instance();
    CategorizedHistoryModel::instance().addCollection<LocalHistoryCollection>(LoadOptions::FORCE_ENABLED);

    /* make sure basic number categories exist, in case user has no contacts
     * from which these would be automatically created
     */
    NumberCategoryModel::instance().addCategory("work", QVariant());
    NumberCategoryModel::instance().addCategory("home", QVariant());

    GlobalInstances::setPixmapManipulator(std::unique_ptr<Interfaces::ImageManipulationDelegate>(new Interfaces::ImageManipulationDelegate()));

    PersonModel::instance().addCollection<AddressBookBackend>(LoadOptions::FORCE_ENABLED);
    RecentModel::instance(); // Make sure RecentModel is initialized before showing UI

    ProfileModel::instance().addCollection<LocalProfileCollection>(LoadOptions::FORCE_ENABLED);
    PersonModel::instance().addCollection<PeerProfileCollection>(LoadOptions::FORCE_ENABLED);

    return NSApplicationMain(argc, argv);
}
