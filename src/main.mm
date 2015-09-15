/*
 *  Copyright (C) 2015 Savoir-faire Linux Inc.
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

#import <AppKit/NSApplication.h>

//Qt
#import <qapplication.h>
#import <globalinstances.h>
#import <QDebug>
#import <QDir>
#import <QTranslator>
#import <QLocale>

#import "backends/AddressBookBackend.h"
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
    QTranslator translator;
    if (translator.load(QLocale::system(), "lrc", "_", dir.absolutePath()+"/Resources/QtTranslations")) {
        app->installTranslator(&translator);
    }

    GlobalInstances::setPixmapManipulator(std::unique_ptr<Interfaces::ImageManipulationDelegate>(new Interfaces::ImageManipulationDelegate()));



    return NSApplicationMain(argc, argv);
}
