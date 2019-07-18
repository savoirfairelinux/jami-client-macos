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

//LRC
#import <person.h>
#import <profilemodel.h>
#import <profile.h>
#import <contactmethod.h>
#import <api/conversation.h>
#import <api/account.h>
#import <api/contactmodel.h>
#import <api/contact.h>
#import <api/profile.h>

namespace Interfaces {

    // Colors from material.io
    const QColor ImageManipulationDelegate::avatarColors_[] = {
        {"#fff44336"}, //Red
        {"#ffe91e63"}, //Pink
        {"#ff9c27b0"}, //Purple
        {"#ff673ab7"}, //Deep Purple
        {"#ff3f51b5"}, //Indigo
        {"#ff2196f3"}, //Blue
        {"#ff00bcd4"}, //Cyan
        {"#ff009688"}, //Teal
        {"#ff4caf50"}, //Green
        {"#ff8bc34a"}, //Light Green
        {"#ff9e9e9e"}, //Grey
        {"#ffcddc39"}, //Lime
        {"#ffffc107"}, //Amber
        {"#ffff5722"}, //Deep Orange
        {"#ff795548"}, //Brown
        {"#ff607d8b"}  //Blue Grey
    };

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
            return drawDefaultUserPixmap(size,
                                         c->phoneNumbers().at(0)->uri().userinfo().at(0).toLatin1(),
                                         c->phoneNumbers().at(0)->bestName().at(0).toUpper().toLatin1());
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
            return drawDefaultUserPixmap(size,
                                         n->uri().userinfo().at(0).toLatin1(),
                                         n->bestName().at(0).toUpper().toLatin1());
        }
    }

    QVariant ImageManipulationDelegate::personPhoto(const QByteArray& data, const QString& type)
    {
        QImage image;
        //For now, ENCODING is only base64 and image type PNG or JPG
        const bool ret = image.loadFromData(QByteArray::fromBase64(data),type.toLatin1());
        if (!ret) {
            qDebug() << "vCard image loading failed";
            return QVariant();
        }

        return QPixmap::fromImage(image);
    }

    char letterForDefaultUserPixmap(const lrc::api::contact::Info& contact)
    {
        if (!contact.profileInfo.alias.empty()) {
            return std::toupper(contact.profileInfo.alias.at(0));
        } else if((contact.profileInfo.type == lrc::api::profile::Type::RING ||
                contact.profileInfo.type == lrc::api::profile::Type::PENDING) &&
                  !contact.registeredName.empty()) {
            return std::toupper(contact.registeredName.at(0));
        } else {
            return std::toupper(contact.profileInfo.uri.at(0));
        }
    }

    QVariant ImageManipulationDelegate::conversationPhoto(const lrc::api::conversation::Info& conversation,
                                                          const lrc::api::account::Info& accountInfo,
                                                          const QSize& size,
                                                          bool displayPresence)
    {
        Q_UNUSED(displayPresence)

        try {
            auto contact = accountInfo.contactModel->getContact(conversation.participants[0]);
            auto& avatar = contact.profileInfo.avatar;
            if (!avatar.empty()) {
                QPixmap pxm;
                const int radius = size.height() / 2;

                /*
                 * we could not now clear cache and image coul be outdated
                 * so do not use cache now
                // Check cache
                auto index = QStringLiteral("%1%2%3").arg(size.width())
                .arg(size.height())
                .arg(QString::fromStdString(conversation.uid));

                if (convPixmCache.contains(index)) {
                    return convPixmCache.value(index);
                }
                */

                auto contactPhoto = qvariant_cast<QPixmap>(personPhoto(QByteArray::fromStdString(avatar)));
                contactPhoto = contactPhoto.scaled(size, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation);

                QPixmap finalImg;
                // We crop the avatar if picture is not squared as scaled() keep ratio of original picture
                if (contactPhoto.size() != size) {
                    finalImg = crop(contactPhoto, size);
                } else
                    finalImg = contactPhoto;

                // Creating clean QPixmap
                pxm = QPixmap(size);
                pxm.fill(Qt::transparent);

                //Add corner radius to the Pixmap
                QPainter painter(&pxm);
                painter.setRenderHints(QPainter::Antialiasing | QPainter::SmoothPixmapTransform);
                painter.setCompositionMode(QPainter::CompositionMode_SourceOver);
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
                painter.setPen               (Qt::transparent                   );
                painter.setCompositionMode   (QPainter::CompositionMode_SourceIn);
                painter.drawRoundedRect(0,0,pxm.height(),pxm.height(),radius,radius);

                // Save in cache
                //convPixmCache.insert(index, pxm);

                return pxm;
            } else {
                char color = contact.profileInfo.uri.at(0);
                contact.profileInfo.alias.erase(std::remove(contact.profileInfo.alias.begin(), contact.profileInfo.alias.end(), '\n'), contact.profileInfo.alias.end());
                contact.profileInfo.alias.erase(std::remove(contact.profileInfo.alias.begin(), contact.profileInfo.alias.end(), ' '), contact.profileInfo.alias.end());
                contact.profileInfo.alias.erase(std::remove(contact.profileInfo.alias.begin(), contact.profileInfo.alias.end(), '\r'), contact.profileInfo.alias.end());

                if (!contact.profileInfo.alias.empty()) {
                    return drawDefaultUserPixmap(size, color, std::toupper(contact.profileInfo.alias.at(0)));
                } else if((contact.profileInfo.type == lrc::api::profile::Type::RING ||
                           contact.profileInfo.type == lrc::api::profile::Type::PENDING) &&
                          !contact.registeredName.empty()) {
                    contact.registeredName.erase(std::remove(contact.registeredName.begin(), contact.registeredName.end(), '\n'), contact.registeredName.end());
                    contact.registeredName.erase(std::remove(contact.registeredName.begin(), contact.registeredName.end(), ' '), contact.registeredName.end());
                    contact.registeredName.erase(std::remove(contact.registeredName.begin(), contact.registeredName.end(), '\r'), contact.registeredName.end());
                    if(!contact.registeredName.empty()) {
                        return drawDefaultUserPixmap(size, color, std::toupper(contact.registeredName.at(0)));
                    } else {
                        return drawDefaultUserPixmapUriOnly(size, color);
                    }
                } else {
                    return drawDefaultUserPixmapUriOnly(size, color);
                }
            }
        } catch (const std::out_of_range& e) {
            return QVariant();
        }
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

    QPixmap ImageManipulationDelegate::drawDefaultUserPixmap(const QSize& size,  const char color, const char letter) {
        // We start with a transparent avatar
        QPixmap avatar(size);
        avatar.fill(Qt::transparent);

        // We pick a color based on the passed character
        QColor avColor = ImageManipulationDelegate::avatarColors_[color % 16];

        // We draw a circle with this color
        QPainter painter(&avatar);
        painter.setRenderHints(QPainter::Antialiasing|QPainter::SmoothPixmapTransform);
        painter.setPen(Qt::transparent);
        painter.setBrush(avColor);
        painter.drawEllipse(avatar.rect());

        // Then we paint a letter in the circle
        auto font = painter.font();
        font.setPointSize(avatar.height()/2);
        painter.setFont(font);
        painter.setPen(Qt::white);
        QRect textRect = avatar.rect();
        painter.drawText(textRect, QString(letter), QTextOption(Qt::AlignCenter));

        return avatar;
    }

    QPixmap ImageManipulationDelegate::drawDefaultUserPixmapUriOnly(const QSize& size,  const char color) {
        // We start with a transparent avatar
        QPixmap avatar(size);
        avatar.fill(Qt::transparent);

        // We pick a color based on the passed character
        QColor avColor = ImageManipulationDelegate::avatarColors_[color % 16];

        // We draw a circle with this color
        QPainter painter(&avatar);
        painter.setRenderHints(QPainter::Antialiasing|QPainter::SmoothPixmapTransform);
        painter.setPen(Qt::transparent);
        painter.setBrush(avColor);
        painter.drawEllipse(avatar.rect());

        // Then we paint the avatar in the circle
        QRect textRect = avatar.rect();
        QImage defaultAvatarImage;
        QRect rect = QRect(0, 0, size.width(), size.height());
        NSURL *bundleURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
        NSString *imagePath = [bundleURL.absoluteString stringByAppendingString:@"Contents/Resources/default_avatar_overlay.png"];
        if (defaultAvatarImage.load(QString::fromNSString(imagePath).mid(7))) {
            painter.drawImage(avatar.rect(), defaultAvatarImage);
        } else {
            painter.drawText(avatar.rect(), QString('?'), QTextOption(Qt::AlignCenter));
        }

        return avatar;
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
            return drawDefaultUserPixmap(decorationSize,
                                         c->peerContactMethod()->uri().userinfo().at(0).toLatin1(),
                                         c->peerContactMethod()->bestName().at(0).toUpper().toLatin1());
    }

    QVariant ImageManipulationDelegate::decorationRole(const ContactMethod* cm)
    {
        QImage photo;
        if (cm && cm->contact() && cm->contact()->photo().isValid())
            return contactPhoto(cm->contact(), decorationSize);
        else
            return drawDefaultUserPixmap(decorationSize,
                                         cm->uri().userinfo().at(0).toLatin1(),
                                         cm->bestName().at(0).toUpper().toLatin1());
    }

    QVariant ImageManipulationDelegate::decorationRole(const Person* p)
    {
        return contactPhoto(const_cast<Person*>(p), decorationSize);
    }

    QVariant ImageManipulationDelegate::decorationRole(const Account* acc)
    {
        Q_UNUSED(acc)
        return QVariant();
    }

} // namespace Interfaces
