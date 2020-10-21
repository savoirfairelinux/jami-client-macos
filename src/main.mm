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

#import "delegates/ImageManipulationDelegate.h"

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

    const auto localeName = QLocale::system().name();
    const auto localeLang = localeName.split('_')[0];
    auto langPath = dir.absolutePath() + "/Contents/Resources/QtTranslations/lrc_" + localeLang + ".qm";
    auto localePath = dir.absolutePath() + "/Contents/Resources/QtTranslations/lrc_" + localeName +".qm";
    QTranslator lrcTranslatorLang;
    QTranslator lrcTranslatorLocale;
    if (localeName != localeLang) {
        if (lrcTranslatorLang.load(langPath))
            app->installTranslator(&lrcTranslatorLang);
    }
    if (lrcTranslatorLocale.load(localePath))
        app->installTranslator(&lrcTranslatorLocale);

    GlobalInstances::setPixmapManipulator(std::unique_ptr<Interfaces::ImageManipulationDelegate>(new Interfaces::ImageManipulationDelegate()));

    return NSApplicationMain(argc, argv);
}
