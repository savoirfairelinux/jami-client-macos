/****************************************************************************
 *   Copyright (C) 2013-2014 by Savoir-Faire Linux                          *
 *   Author : Emmanuel Lepage Vallee <emmanuel.lepage@savoirfairelinux.com> *
 *                                                                          *
 *   This library is free software; you can redistribute it and/or          *
 *   modify it under the terms of the GNU Lesser General Public             *
 *   License as published by the Free Software Foundation; either           *
 *   version 2.1 of the License, or (at your option) any later version.     *
 *                                                                          *
 *   This library is distributed in the hope that it will be useful,        *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of         *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU      *
 *   Lesser General Public License for more details.                        *
 *                                                                          *
 *   You should have received a copy of the GNU General Public License      *
 *   along with this program.  If not, see <http://www.gnu.org/licenses/>.  *
 ***************************************************************************/
#import "ImageManipulationDelegate.h"

//Qt
#import <QSize>
#import <QBuffer>
#import <QtGui/QColor>
#import <QtGui/QPainter>
#import <QtGui/QBitmap>
#import <QtWidgets/QApplication>
#import <QtGui/QImage>
#import <QtGui/QPalette>

//Ring
#import <person.h>
#import <contactmethod.h>
#import <presencestatusmodel.h>
#import <securityvalidationmodel.h>
#import <collectioninterface.h>
#import <useractionmodel.h>
#import <QStandardPaths>

ImageManipulationDelegate::ImageManipulationDelegate() : PixmapManipulationDelegate()
{

}

QVariant ImageManipulationDelegate::personPhoto(const QByteArray& data, const QString& type)
{
    QImage image;
    //For now, ENCODING is only base64 and image type PNG or JPG
    const bool ret = image.loadFromData(QByteArray::fromBase64(data),type.toLatin1());
    if (!ret)
        qDebug() << "vCard image loading failed";

    return QVariant();
}

QVariant ImageManipulationDelegate::contactPhoto(Person* c, const QSize& size, bool displayPresence) {
    return QVariant();
}

QByteArray ImageManipulationDelegate::toByteArray(const QVariant& pxm)
{
    //Preparation of our QPixmap
    QByteArray bArray;
    QBuffer buffer(&bArray);
    buffer.open(QIODevice::WriteOnly);

    //PNG ?
    (qvariant_cast<QPixmap>(pxm)).save(&buffer, "PNG");
    buffer.close();

    return bArray;
}

