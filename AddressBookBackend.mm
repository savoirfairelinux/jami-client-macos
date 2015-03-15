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
#include "AddressBookBackend.h"

#import <AddressBook/AddressBook.h>

//Qt
#include <QtCore/QFile>
#include <QtCore/QDir>
#include <QtCore/QHash>
#include <QtWidgets/QApplication>
#include <QtCore/QStandardPaths>

//Ring
#include <Person.h>
#include <account.h>
#include <person.h>
#include <contactmethod.h>
#include <historymodel.h>
#include <vcardutils.h>

/**
 *
 *kABFirstNameProperty
 kABLastNameProperty
 kABFirstNamePhoneticProperty
 kABLastNamePhoneticProperty
 kABBirthdayProperty
 kABOrganizationProperty
 kABJobTitleProperty
 kABHomePageProperty
 kABEmailProperty
 kABAddressProperty
 kABPhoneProperty
 kABAIMInstantProperty
 kABJabberInstantProperty
 kABMSNInstantProperty
 kABYahooInstantProperty
 kABICQInstantProperty
 kABNoteProperty
 kABMiddleNameProperty
 kABMiddleNamePhoneticProperty
 kABTitleProperty
 kABSuffixProperty
 kABNicknameProperty
 kABMaidenNameProperty
 */
struct VCardMapper {

    //QHash<QByteArray, mapToProperty> m_hHash;

    VCardMapper() {
        //m_hHash[VCardUtils::Property::UID] = &VCardMapper::setUid;
       // m_hHash[VCardUtils::Property::NAME] = &VCardMapper::setNames;
        //m_hHash[VCardUtils::Property::FORMATTED_NAME] = &VCardMapper::setFormattedName;
        //m_hHash[VCardUtils::Property::EMAIL] = &VCardMapper::setEmail;
        //m_hHash[VCardUtils::Property::ORGANIZATION] = &VCardMapper::setOrganization;
    }

    void setFormattedName(Person* c, const QByteArray& fn) {
        c->setFormattedName(QString::fromUtf8(fn));
    }

    void setNames(Person* c, const QByteArray& fn) {
        QList<QByteArray> splitted = fn.split(';');
        c->setFamilyName(splitted[0].trimmed());
        c->setFirstName(splitted[1].trimmed());
    }

    void setUid(Person* c, const QByteArray& fn) {
        c->setUid(fn);
    }

    void setEmail(Person* c, const QByteArray& fn) {
        c->setPreferredEmail(fn);
    }

    void setOrganization(Person* c, const QByteArray& fn) {
        c->setOrganization(QString::fromUtf8(fn));
    }

    void setPhoto(Person* c, const QByteArray& fn) {
        qDebug() << fn;
        //QVariant photo = PixmapManipulationVisitor::instance()->profilePhoto(fn);
        //c->setPhoto(photo);
    }

    void addPhoneNumber(Person* c, const QString& key, const QByteArray& fn) {
        Q_UNUSED(c)
        Q_UNUSED(key)
        qDebug() << fn;
    }

    void addAddress(Person* c, const QString& key, const QByteArray& fn) {
        Person::Address* addr = new Person::Address();
        addr->setType(key.split(VCardUtils::Delimiter::SEPARATOR_TOKEN)[1]);
        QList<QByteArray> fields = fn.split(VCardUtils::Delimiter::SEPARATOR_TOKEN[0]);
        addr->setAddressLine(QString::fromUtf8(fields[2]));
        addr->setCity(QString::fromUtf8(fields[3]));
        addr->setState(QString::fromUtf8(fields[4]));
        addr->setZipCode(QString::fromUtf8(fields[5]));
        addr->setCountry(QString::fromUtf8(fields[6]));
        c->addAddress(addr);
    }

    bool metacall(Person* c, const QByteArray& key, const QByteArray& value) {
//        if (!m_hHash[key]) {
//            if(key.contains(VCardUtils::Property::PHOTO)) {
//                //key must contain additionnal attributes, we don't need them right now (ENCODING, TYPE...)
//                setPhoto(c, value);
//                return true;
//            }
//
//            if(key.contains(VCardUtils::Property::ADDRESS)) {
//                addAddress(c, key, value);
//                return true;
//            }
//
//            if(key.contains(VCardUtils::Property::TELEPHONE)) {
//                addPhoneNumber(c, key, value);
//                return true;
//            }
//            
//            return false;
//        }
//        (this->*(m_hHash[key]))(c,value);
        return true;
    }
};

static VCardMapper* vc_mapper = new VCardMapper;

class AddressBookEditor : public CollectionEditor<Person>
{
public:
    AddressBookEditor(CollectionMediator<Person>* m, AddressBookBackend* parent);
    virtual bool save       ( const Person* item ) override;
    virtual bool remove     ( const Person* item ) override;
    virtual bool edit       ( Person*       item ) override;
    virtual bool addNew     ( const Person* item ) override;
    virtual bool addExisting( const Person* item ) override;

private:
    virtual QVector<Person*> items() const override;

    //Helpers
    void savePerson(QTextStream& stream, const Person* Person);
    bool regenFile(const Person* toIgnore);

    //Attributes
    QVector<Person*> m_lItems;
    AddressBookBackend* m_pCollection;
};

AddressBookEditor::AddressBookEditor(CollectionMediator<Person>* m, AddressBookBackend* parent) :
CollectionEditor<Person>(m),m_pCollection(parent)
{

}

AddressBookBackend::AddressBookBackend(CollectionMediator<Person>* mediator) :
CollectionInterface(new AddressBookEditor(mediator,this)),m_pMediator(mediator)
{

}

AddressBookBackend::~AddressBookBackend()
{

}

void AddressBookEditor::savePerson(QTextStream& stream, const Person* Person)
{

    qDebug() << "Saving Person!";
}

bool AddressBookEditor::regenFile(const Person* toIgnore)
{
    QDir dir(QString('/'));
    dir.mkpath(QStandardPaths::writableLocation(QStandardPaths::DataLocation) + QLatin1Char('/') + QString());


    return false;
}

bool AddressBookEditor::save(const Person* Person)
{
    //if (Person->collection()->editor<Person>() != this)
    //    return addNew(Person);

    return regenFile(nullptr);
}

bool AddressBookEditor::remove(const Person* item)
{
    return regenFile(item);
}

bool AddressBookEditor::edit( Person* item)
{
    Q_UNUSED(item)
    return false;
}

bool AddressBookEditor::addNew(const Person* Person)
{
    QDir dir(QString('/'));
    dir.mkpath(QStandardPaths::writableLocation(QStandardPaths::DataLocation) + QLatin1Char('/') + QString());

    return false;
}

bool AddressBookEditor::addExisting(const Person* item)
{
    m_lItems << const_cast<Person*>(item);
    mediator()->addItem(item);
    return true;
}

QVector<Person*> AddressBookEditor::items() const
{
    return m_lItems;
}

QString AddressBookBackend::name () const
{
    return QObject::tr("AddressBook backend");
}

QString AddressBookBackend::category () const
{
    return QObject::tr("Persons");
}

QVariant AddressBookBackend::icon() const
{
    return QVariant();
}

bool AddressBookBackend::isEnabled() const
{
    return true;
}

bool AddressBookBackend::load()
{
    ABAddressBook *book = [ABAddressBook sharedAddressBook];

    NSArray *everyone = [book people];
    //NSArray *everygroup = [book groups];

    //NSLog( [everyone description] );
    //NSLog( [everygroup description] );
    for(ABPerson* p in everyone)
    {
        Person* person = new Person(this);

        QList<QByteArray> splittedProperties = QByteArray::fromNSData(
                                            p.vCardRepresentation).split('\n');

        bool propertyInserted;
        for (QByteArray property : splittedProperties){
            qDebug() << "property: " << property;
            QList<QByteArray> splitted = property.split(':');
            if(splitted.size() < 2){
                qDebug() << "Property malformed!";
                continue;
            }
            propertyInserted = vc_mapper->metacall(person,splitted[0],splitted[1].trimmed());
            if(!propertyInserted)
                qDebug() << "Could not extract: " << splitted[0];

            //Link with accounts
            //if(splitted.at(0) == VCardUtils::Property::X_RINGACCOUNT) {
            //    Account* acc = AccountListModel::instance()->getAccountById(splitted.at(1).trimmed());
            //    if(!acc) {
            //       qDebug() << "Could not find account: " << splitted.at(1).trimmed();
            //       continue;
            //    }
            //}
        }
    }
     return false;
}


bool AddressBookBackend::reload()
{
    return false;
}

CollectionInterface::SupportedFeatures AddressBookBackend::supportedFeatures() const
{
    return (CollectionInterface::SupportedFeatures) (
                                                     CollectionInterface::SupportedFeatures::NONE  |
                                                     CollectionInterface::SupportedFeatures::LOAD  |
                                                     CollectionInterface::SupportedFeatures::CLEAR |
                                                     CollectionInterface::SupportedFeatures::REMOVE|
                                                     CollectionInterface::SupportedFeatures::ADD   );
}

bool AddressBookBackend::clear()
{
    /* TODO: insert confirm dialog? */
    return true;
}

QByteArray AddressBookBackend::id() const
{
    return "abb";
}
