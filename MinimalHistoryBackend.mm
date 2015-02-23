/************************************************************************************
 *   Copyright (C) 2014-2015 by Savoir-Faire Linux                                  *
 *   Author : Emmanuel Lepage Vallee <emmanuel.lepage@savoirfairelinux.com>         *
 *                                                                                  *
 *   This library is free software; you can redistribute it and/or                  *
 *   modify it under the terms of the GNU Lesser General Public                     *
 *   License as published by the Free Software Foundation; either                   *
 *   version 2.1 of the License, or (at your option) any later version.             *
 *                                                                                  *
 *   This library is distributed in the hope that it will be useful,                *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of                 *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU              *
 *   Lesser General Public License for more details.                                *
 *                                                                                  *
 *   You should have received a copy of the GNU Lesser General Public               *
 *   License along with this library; if not, write to the Free Software            *
 *   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA *
 ***********************************************************************************/
#include "minimalhistorybackend.h"

#import <Cocoa/Cocoa.h>

//Qt
#include <QtCore/QFile>
#include <QtCore/QHash>
#include <QtCore/qcoreapplication.h>

//Ring
#include <call.h>
#include <account.h>
#include <historymodel.h>

#import "NSFileManager+DirUtils.h"

MinimalHistoryBackend::~MinimalHistoryBackend()
{

}

bool MinimalHistoryEditor::addExisting( const Call* item)
{
    Q_UNUSED(item)
    return false;
}

bool MinimalHistoryEditor::save(const Call* item)
{
   Q_UNUSED(item)
   return false;
}

bool MinimalHistoryEditor::remove(const Call* item)
{
   Q_UNUSED(item)
   return false;
}

bool MinimalHistoryEditor::edit( Call* item)
{
   Q_UNUSED(item)
   return false;
}

bool MinimalHistoryEditor::addNew(const Call* item)
{
   Q_UNUSED(item)
   return false;
}

QVector<Call*> MinimalHistoryEditor::items() const
{
   return QVector<Call*>();
}

QString MinimalHistoryBackend::name () const
{
   return QObject::tr("Minimal history backend");
}

QString MinimalHistoryBackend::category () const
{
   return QObject::tr("History");
}

QVariant MinimalHistoryBackend::icon() const
{
   return QVariant();
}

bool MinimalHistoryBackend::isEnabled() const
{
   return true;
}

bool MinimalHistoryBackend::load()
{

   QFile file([[[[NSFileManager defaultManager] applicationSupportDirectory] stringByAppendingString:@"/history.ini"] UTF8String]);
    
   if ( file.open(QIODevice::ReadOnly | QIODevice::Text) ) {
      QMap<QString,QString> hc;
      while (!file.atEnd()) {
         QByteArray line = file.readLine().trimmed();

         //The item is complete
         if ((line.isEmpty() || !line.size()) && hc.size()) {
            Call* pastCall = Call::buildHistoryCall(hc);
            if (pastCall->peerName().isEmpty()) {
               pastCall->setPeerName(QObject::tr("Unknown"));
            }
            pastCall->setRecordingPath(hc[ Call::HistoryMapFields::RECORDING_PATH ]);
            m_pMediator->addItem(pastCall);
            hc.clear();
         }
         // Add to the current set
         else {
            const int idx = line.indexOf("=");
            if (idx >= 0)
               hc[line.left(idx)] = line.right(line.size()-idx-1);
         }
      }
      return true;
   }
   else
      qWarning() << "History doesn't exist or is not readable";
   return false;
}

bool MinimalHistoryBackend::reload()
{
   return false;
}

CollectionInterface::SupportedFeatures MinimalHistoryBackend::supportedFeatures() const
{
   return (CollectionInterface::SupportedFeatures) (
      CollectionInterface::SupportedFeatures::NONE  |
      CollectionInterface::SupportedFeatures::LOAD  |
      CollectionInterface::SupportedFeatures::CLEAR |
      CollectionInterface::SupportedFeatures::ADD   );
}

bool MinimalHistoryBackend::clear()
{
    QFile::remove([[[[NSFileManager defaultManager] applicationSupportDirectory] stringByAppendingString:@"/history.ini"] UTF8String]);
}

QByteArray MinimalHistoryBackend::id() const
{
   return "mhb";
}
