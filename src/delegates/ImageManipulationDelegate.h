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

#import <QuartzCore/QuartzCore.h>

//Qt
#import <QSize>
#import <QPair>
#import <QtGui/qpixmap.h>

//Ring
#import <interfaces/pixmapmanipulatori.h>

class Person;
class QString;

namespace Interfaces {

    class ImageManipulationDelegate : public PixmapManipulatorI {

    public:
        static constexpr int IMG_SIZE = 80;

        ImageManipulationDelegate();
        virtual QByteArray toByteArray(const QVariant& pxm) override;
        virtual QVariant personPhoto(const QByteArray& data, const QString& type = nil) override;
        QVariant conversationPhoto(const lrc::api::conversation::Info& conversation,
                                   const lrc::api::account::Info& accountInfo,
                                   const QSize& size = QSize(IMG_SIZE, IMG_SIZE),
                                   bool displayPresence = true) override;

        /* TODO: the following methods return an empty QVariant/QByteArray */
        QVariant   numberCategoryIcon(const QVariant& p, const QSize& size, bool displayPresence = false, bool isPresent = false) override;
        QVariant   userActionIcon(const UserActionElement& state) const override;
        QVariant   decorationRole(const QModelIndex& index) override;

    private:
        //Helper
        QPixmap drawDefaultUserPixmap(const QSize& size, const char color, const char letter);
        QPixmap drawDefaultUserPixmapUriOnly(const QSize& size, const char color);
        CGImageRef resizeCGImage(CGImageRef image, const QSize& size);

        QHash<QString, QPixmap> m_hDefaultUserPixmap;
        QHash<QString, QPair<QMetaObject::Connection, QPixmap>> m_hContactsPixmap;
        QHash<QString, QPixmap> convPixmCache;
        static const QColor avatarColors_[];

        /**
         * Return a version of size destSize centered of the bigger photo
         */
        QPixmap crop(QPixmap& photo, const QSize& destSize);

        const QSize decorationSize = {80,80};
    };

} // namespace Interfaces
