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
 *  shall import the source code for the parts of OpenSSL used as well
 *  as that of the covered work.
 */
#import "AddressBookBackend.h"

#import <AddressBook/AddressBook.h>

//Qt
#import <QtCore/QFile>
#import <QtCore/QDir>
#import <QtCore/QHash>
#import <QtWidgets/QApplication>
#import <QtCore/QStandardPaths>
#import <QTimer>
#import <QtGlobal>

//Ring
#import <Person.h>
#import <account.h>
#import <person.h>
#import <contactmethod.h>

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
    QTimer::singleShot(100, [=] {
        asyncLoad(0);
    });
     return false;
}

void AddressBookBackend::asyncLoad(int startingPoint)
{
    ABAddressBook *book = [ABAddressBook sharedAddressBook];
    NSArray *everyone = [book people];
    int endPoint = qMin(startingPoint + 10, (int)everyone.count);

    for (int i = startingPoint; i < endPoint; ++i) {

        Person* person = new Person(QByteArray::fromNSData(((ABPerson*)[everyone objectAtIndex:i]).vCardRepresentation),
                                    Person::Encoding::vCard,
                                    this);
        if([person->formattedName().toNSString() isEqualToString:@""]   &&
           [person->secondName().toNSString() isEqualToString:@""]     &&
           [person->firstName().toNSString() isEqualToString:@""]) {
            continue;
        }
        person->setCollection(this);

        editor<Person>()->addExisting(person);
    }

    if(endPoint < everyone.count) {
        QTimer::singleShot(100, [=] {
            asyncLoad(endPoint);
        });
    }

}


bool AddressBookBackend::reload()
{
    return false;
}

FlagPack<AddressBookBackend::SupportedFeatures> AddressBookBackend::supportedFeatures() const
{
    return (FlagPack<SupportedFeatures>) (
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
