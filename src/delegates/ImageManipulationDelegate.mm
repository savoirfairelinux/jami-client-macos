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
#import "ImageManipulationDelegate.h"

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

//Qt
#import <QSize>
#import <QBuffer>
#import <QtGui/QColor>
#import <QtGui/QPainter>
#import <QHash>
#import <QtGui/QBitmap>
#import <QtWidgets/QApplication>
#import <QtGui/QImage>
#import <QtMacExtras/qmacfunctions.h>
#import <QtGui/QPalette>

//Ring
#import <person.h>
#import <profilemodel.h>
#import <profile.h>
#import <contactmethod.h>

namespace Interfaces {

    ImageManipulationDelegate::ImageManipulationDelegate() {}

    QVariant ImageManipulationDelegate::contactPhoto(Person* c, const QSize& size, bool displayPresence) {
        const int radius = size.height() / 2;
        QPixmap pxm;
        if (c && c->photo().isValid()) {
            // Check cache
            auto index = QStringLiteral("%1%2%3").arg(size.width())
            .arg(size.height())
            .arg(QString::fromUtf8(c->uid()));

            if (m_hContactsPixmap.contains(index)) {
                return m_hContactsPixmap.value(index).second;
            }

            QPixmap contactPhoto(qvariant_cast<QPixmap>(c->photo()).scaled(size, Qt::KeepAspectRatioByExpanding,
                                                                           Qt::SmoothTransformation));

            QPixmap finalImg;
            if (contactPhoto.size() != size) {
                finalImg = crop(contactPhoto, size);
            } else
                finalImg = contactPhoto;

            pxm = QPixmap(size);
            pxm.fill(Qt::transparent);
            QPainter painter(&pxm);

            //Clear the pixmap
            painter.setRenderHints(QPainter::Antialiasing | QPainter::SmoothPixmapTransform);
            painter.setCompositionMode(QPainter::CompositionMode_Clear);
            painter.fillRect(0,0,size.width(),size.height(),QBrush(Qt::white));
            painter.setCompositionMode(QPainter::CompositionMode_SourceOver);

            //Add corner radius to the Pixmap
            QRect pxRect = finalImg.rect();
            QBitmap mask(pxRect.size());
            QPainter customPainter(&mask);
            customPainter.setRenderHints (QPainter::Antialiasing | QPainter::SmoothPixmapTransform);
            customPainter.fillRect       (pxRect                , Qt::white );
            customPainter.setBackground  (Qt::black                         );
            customPainter.setBrush       (Qt::black                         );
            customPainter.drawRoundedRect(pxRect,radius,radius              );
            finalImg.setMask             (mask                              );
            painter.drawPixmap           (0,0,finalImg                      );
            painter.setBrush             (Qt::NoBrush                       );
            painter.setPen               (Qt::black                         );
            painter.setCompositionMode   (QPainter::CompositionMode_SourceIn);
            painter.drawRoundedRect(0,0,pxm.height(),pxm.height(),radius,radius);

            // Save in cache
            QPair<QMetaObject::Connection, QPixmap> toInsert;
            toInsert.first = QObject::connect(c,
                                              &Person::changed,
                                              [=]() {
                                                  if (c) {
                                                      auto index = QStringLiteral("%1%2%3").arg(size.width())
                                                                                            .arg(size.height())
                                                                                            .arg(QString::fromUtf8(c->uid()));
                                                      if (m_hContactsPixmap.contains(index)) {
                                                          QObject::disconnect(m_hContactsPixmap.value(index).first);
                                                          m_hContactsPixmap.remove(index);
                                                      }
                                                  }
                                              });
            toInsert.second = pxm;
            m_hContactsPixmap.insert(index, toInsert);

        } else {
            return drawDefaultUserPixmap(size);
        }

        return pxm;
    }

    QPixmap
    ImageManipulationDelegate::crop(QPixmap& photo, const QSize& destSize)
    {
        auto initSize = photo.size();
        float leftDelta = 0;
        float topDelta = 0;

        if (destSize.height() == initSize.height()) {
            leftDelta = (destSize.width() - initSize.width()) / 2;
        } else {
            topDelta = (destSize.height() - initSize.height()) / 2;
        }

        float xScale = (float)destSize.width()  / initSize.width();
        float yScale = (float)destSize.height() / initSize.height();

        QRectF destRect(leftDelta, topDelta,
                            initSize.width() - leftDelta, initSize.height() - topDelta);

        destRect.setLeft(leftDelta * xScale);
        destRect.setTop(topDelta * yScale);

        destRect.setWidth((initSize.width() - leftDelta) * xScale);
        destRect.setHeight((initSize.height() - topDelta) * yScale);

        return photo.copy(destRect.toRect());
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
            return drawDefaultUserPixmap(size);
        }
    }

    QVariant ImageManipulationDelegate::personPhoto(const QByteArray& data, const QString& type)
    {
        QImage image;
        //For now, ENCODING is only base64 and image type PNG or JPG
        const bool ret = image.loadFromData(QByteArray::fromBase64(data),type.toLatin1());
        if (!ret) {
            qDebug() << "vCard image loading failed";
            return drawDefaultUserPixmap(decorationSize);
        }

        return QPixmap::fromImage(image);
    }

    QByteArray ImageManipulationDelegate::toByteArray(const QVariant& pxm)
    {
        //Preparation of our QPixmap
        QByteArray bArray;
        QBuffer buffer(&bArray);
        buffer.open(QIODevice::WriteOnly);

        //PNG ?
        (qvariant_cast<QPixmap>(pxm)).scaled({100,100}).save(&buffer, "PNG");
        buffer.close();

        return bArray;
    }

    QPixmap ImageManipulationDelegate::drawDefaultUserPixmap(const QSize& size, bool displayPresence, bool isPresent) {

        auto index = QStringLiteral("%1%2").arg(size.width()).arg(size.height());
        if (m_hDefaultUserPixmap.contains(index)) {
            return m_hDefaultUserPixmap.value(index);
        }

        // create the image somehow, load from file, draw into it...
        auto sourceImgRef = CGImageSourceCreateWithData((__bridge CFDataRef)[[NSImage imageNamed:@"default_user_icon"] TIFFRepresentation], NULL);
        auto imgRef = CGImageSourceCreateImageAtIndex(sourceImgRef, 0, NULL);
        auto finalpxm =  QtMac::fromCGImageRef(resizeCGImage(imgRef, size));
        CFRelease(sourceImgRef);
        CFRelease(imgRef);

        m_hDefaultUserPixmap.insert(index, finalpxm);

        return finalpxm;
    }

    CGImageRef ImageManipulationDelegate::resizeCGImage(CGImageRef image, const QSize& size) {
        // create context, keeping original image properties
        CGContextRef context = CGBitmapContextCreate(NULL, size.width(), size.height(),
                                                     CGImageGetBitsPerComponent(image),
                                                     CGImageGetBytesPerRow(image),
                                                     CGImageGetColorSpace(image),
                                                     kCGImageAlphaPremultipliedLast);

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

    QVariant ImageManipulationDelegate::decorationRole(const QModelIndex& index)
    {
        Q_UNUSED(index)
        return QVariant();
    }

    QVariant ImageManipulationDelegate::decorationRole(const Call* c)
    {
        if (c && c->peerContactMethod()
            && c->peerContactMethod()->contact()) {
               return contactPhoto(c->peerContactMethod()->contact(), decorationSize);
        } else
            return drawDefaultUserPixmap(decorationSize);
    }

    QVariant ImageManipulationDelegate::decorationRole(const ContactMethod* cm)
    {
        QImage photo;
        if (cm && cm->contact() && cm->contact()->photo().isValid())
            return contactPhoto(cm->contact(), decorationSize);
        else
            return drawDefaultUserPixmap(decorationSize);
    }

    QVariant ImageManipulationDelegate::decorationRole(const Person* p)
    {
        return contactPhoto(const_cast<Person*>(p), decorationSize);
    }

    QVariant ImageManipulationDelegate::decorationRole(const Account* acc)
    {
        Q_UNUSED(acc)
        if (auto pro = ProfileModel::instance().selectedProfile())
            return contactPhoto(pro->person(), decorationSize);
        return drawDefaultUserPixmap(decorationSize);
    }

} // namespace Interfaces
