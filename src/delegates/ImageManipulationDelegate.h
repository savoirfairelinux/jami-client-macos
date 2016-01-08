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

#import <interfaces/pixmapmanipulatori.h>
#import <call.h>

class Person;
class QPixmap;

namespace Interfaces {

    class ImageManipulationDelegate : public PixmapManipulatorI {

    public:
        ImageManipulationDelegate();
        QVariant contactPhoto(Person* c, const QSize& size, bool displayPresence = true) override;
        virtual QByteArray toByteArray(const QVariant& pxm) override;
        virtual QVariant personPhoto(const QByteArray& data, const QString& type = "PNG") override;

        QVariant callPhoto(Call* c, const QSize& size, bool displayPresence = true) override;
        QVariant callPhoto(const ContactMethod* n, const QSize& size, bool displayPresence = true) override;

        /* TODO: the following methods return an empty QVariant/QByteArray */
        QVariant   numberCategoryIcon(const QVariant& p, const QSize& size, bool displayPresence = false, bool isPresent = false) override;
        QVariant   securityIssueIcon(const QModelIndex& index) override;
        QVariant   collectionIcon(const CollectionInterface* interface, PixmapManipulatorI::CollectionIconHint hint = PixmapManipulatorI::CollectionIconHint::NONE) const override;
        QVariant   securityLevelIcon(const SecurityEvaluationModel::SecurityLevel level) const override;
        QVariant   historySortingCategoryIcon(const CategorizedHistoryModel::SortedProxy::Categories cat) const override;
        QVariant   contactSortingCategoryIcon(const CategorizedContactModel::SortedProxy::Categories cat) const override;
        QVariant   userActionIcon(const UserActionElement& state) const override;
        QVariant   decorationRole(const QModelIndex& index) override;
        QVariant   decorationRole(const Call* c) override;
        QVariant   decorationRole(const ContactMethod* cm) override;
        QVariant   decorationRole(const Person* p) override;

    private:
        //Helper
        QPixmap drawDefaultUserPixmap(const QSize& size, bool displayPresence, bool isPresent);
        CGImageRef resizeCGImage(CGImageRef image, const QSize& size);
    };

} // namespace Interfaces
