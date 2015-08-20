/*
 *  Copyright (C) 2004-2015 Savoir-Faire Linux Inc.
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
#import "ImageManipulationDelegate.h"

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

//Qt
#import <QSize>
#import <QBuffer>
#import <QtGui/QColor>
#import <QtGui/QPainter>
#import <QtGui/QBitmap>
#import <QtWidgets/QApplication>
#import <QtGui/QImage>
#import <QtMacExtras/qmacfunctions.h>
#import <QtGui/QPalette>

//Ring
#import <person.h>
#import <contactmethod.h>

namespace Interfaces {

    ImageManipulationDelegate::ImageManipulationDelegate()
    {

    }

    QVariant ImageManipulationDelegate::contactPhoto(Person* c, const QSize& size, bool displayPresence) {
        const int radius = (size.height() > 35) ? 7 : 5;

        QPixmap pxm;
        if (c && c->photo().isValid()) {
            QPixmap contactPhoto((qvariant_cast<QPixmap>(c->photo())).scaledToWidth(size.height()-6));
            pxm = QPixmap(size);
            pxm.fill(Qt::transparent);
            QPainter painter(&pxm);

            //Clear the pixmap
            painter.setCompositionMode(QPainter::CompositionMode_Clear);
            painter.fillRect(0,0,size.width(),size.height(),QBrush(Qt::white));
            painter.setCompositionMode(QPainter::CompositionMode_SourceOver);

            //Add corner radius to the Pixmap
            QRect pxRect = contactPhoto.rect();
            QBitmap mask(pxRect.size());
            QPainter customPainter(&mask);
            customPainter.setRenderHint  (QPainter::Antialiasing, true      );
            customPainter.fillRect       (pxRect                , Qt::white );
            customPainter.setBackground  (Qt::black                         );
            customPainter.setBrush       (Qt::black                         );
            customPainter.drawRoundedRect(pxRect,radius,radius);
            contactPhoto.setMask(mask);
            painter.drawPixmap(3,3,contactPhoto);
            painter.setBrush(Qt::NoBrush);
            painter.setPen(Qt::white);
            painter.setRenderHint  (QPainter::Antialiasing, true   );
            painter.setCompositionMode(QPainter::CompositionMode_SourceIn);
            painter.drawRoundedRect(3,3,pxm.height()-6,pxm.height()-6,radius,radius);
            painter.setCompositionMode(QPainter::CompositionMode_SourceOver);

        }
        else {
            pxm = drawDefaultUserPixmap(size, false, false);
        }

        return pxm;
    }

    QVariant
    ImageManipulationDelegate::callPhoto(Call* c, const QSize& size, bool displayPresence)
    {
        return callPhoto(c->peerContactMethod(), size, displayPresence);
    }

    QVariant
    ImageManipulationDelegate::callPhoto(const ContactMethod* n, const QSize& size, bool displayPresence)
    {
        if (n->contact()) {
            return contactPhoto(n->contact(), size, displayPresence);
        } else {
            return drawDefaultUserPixmap(size, false, false);
        }
    }

    QVariant ImageManipulationDelegate::personPhoto(const QByteArray& data, const QString& type)
    {
        QImage image;
        //For now, ENCODING is only base64 and image type PNG or JPG
        const bool ret = image.loadFromData(QByteArray::fromBase64(data),type.toLatin1());
        if (!ret)
            qDebug() << "vCard image loading failed";

        return QPixmap::fromImage(image);
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

    QPixmap ImageManipulationDelegate::drawDefaultUserPixmap(const QSize& size, bool displayPresence, bool isPresent) {

        QPixmap pxm(size);
        pxm.fill(Qt::transparent);
        QPainter painter(&pxm);

        // create the image somehow, load from file, draw into it...
        auto sourceImgRef = CGImageSourceCreateWithData((CFDataRef)[[NSImage imageNamed:@"NSUser"] TIFFRepresentation], NULL);
        auto imgRef = CGImageSourceCreateImageAtIndex(sourceImgRef, 0, NULL);
        auto finalImgRef =  resizeCGImage(imgRef, size);
        painter.drawPixmap(3,3,QtMac::fromCGImageRef(finalImgRef));

        CFRelease(sourceImgRef);
        CFRelease(imgRef);
        CFRelease(finalImgRef);

        return pxm;
    }

    CGImageRef ImageManipulationDelegate::resizeCGImage(CGImageRef image, const QSize& size) {
        // create context, keeping original image properties
        CGColorSpaceRef colorspace = CGImageGetColorSpace(image);

        CGContextRef context = CGBitmapContextCreate(NULL, size.width(), size.height(),
                                                     CGImageGetBitsPerComponent(image),
                                                     size.width() * CGImageGetBitsPerComponent(image),
                                                     colorspace,
                                                     CGImageGetAlphaInfo(image));

        if(context == NULL)
            return nil;

        // draw image to context (resizing it)
        CGContextDrawImage(context, CGRectMake(0, 0, size.width(), size.height()), image);
        // extract resulting image from context
        CGImageRef imgRef = CGBitmapContextCreateImage(context);
        CGContextRelease(context);

        return imgRef;
    }

    QVariant
    ImageManipulationDelegate::numberCategoryIcon(const QVariant& p, const QSize& size, bool displayPresence, bool isPresent)
    {
        Q_UNUSED(p)
        Q_UNUSED(size)
        Q_UNUSED(displayPresence)
        Q_UNUSED(isPresent)
        return QVariant();
    }

    QVariant
    ImageManipulationDelegate::securityIssueIcon(const QModelIndex& index)
    {
        Q_UNUSED(index)
        return QVariant();
    }

    QVariant
    ImageManipulationDelegate::collectionIcon(const CollectionInterface* interface, PixmapManipulatorI::CollectionIconHint hint) const
    {
        Q_UNUSED(interface)
        Q_UNUSED(hint)
        return QVariant();
    }
    QVariant
    ImageManipulationDelegate::securityLevelIcon(const SecurityEvaluationModel::SecurityLevel level) const
    {
        Q_UNUSED(level)
        return QVariant();
    }
    QVariant
    ImageManipulationDelegate::historySortingCategoryIcon(const CategorizedHistoryModel::SortedProxy::Categories cat) const
    {
        Q_UNUSED(cat)
        return QVariant();
    }
    QVariant
    ImageManipulationDelegate::contactSortingCategoryIcon(const CategorizedContactModel::SortedProxy::Categories cat) const
    {
        Q_UNUSED(cat)
        return QVariant();
    }

    QVariant
    ImageManipulationDelegate::userActionIcon(const UserActionElement& state) const
    {
        Q_UNUSED(state)
        return QVariant();
    }
    
} // namespace Interfaces
