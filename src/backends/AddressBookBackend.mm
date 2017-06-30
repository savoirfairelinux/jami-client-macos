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
#import "AddressBookBackend.h"

//Cocoa
#import <AddressBook/AddressBook.h>

//Qt
#import <QtCore/QFile>
#import <QtCore/QDir>
#import <QtCore/QHash>
#import <QtWidgets/QApplication>
#import <QtCore/QStandardPaths>
#import <QTimer>
#import <QPixmap>
#import <QtGlobal>

//Ring
#import <Person.h>
#import <account.h>
#import <person.h>
#import <contactmethod.h>
#import <personmodel.h>

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
    virtual bool addNew     ( Person* item ) override;
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
    ::id addressBookObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kABDatabaseChangedNotification
                                     object:nil
                                     queue:[NSOperationQueue mainQueue]
                                     usingBlock:^(NSNotification *note) {
                                         handleNotification(note);
                                     }];

    ::id externalAddressBookObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kABDatabaseChangedExternallyNotification
                                                                                  object:nil
                                                                                   queue:[NSOperationQueue mainQueue]
                                                                              usingBlock:^(NSNotification *note) {
                                                                                  handleNotification(note);
                                                                              }];

    observers = [[NSArray alloc] initWithObjects:addressBookObserver, externalAddressBookObserver, nil];
}

void AddressBookBackend::handleNotification(NSNotification* ns)
{
    for (NSString* r in ns.userInfo[kABInsertedRecords]) {
        ABRecord* inserted = [[ABAddressBook sharedAddressBook] recordForUniqueId:r];
        if (inserted && [[[ABAddressBook sharedAddressBook] recordClassFromUniqueId:r] rangeOfString:@"ABPerson"].location != NSNotFound) {
            editor<Person>()->addExisting(this->abPersonToPerson(inserted));
        }
    }

    for (NSString* r in ns.userInfo[kABUpdatedRecords]) {
        if ([[[ABAddressBook sharedAddressBook] recordClassFromUniqueId:r] rangeOfString:@"ABPerson"].location != NSNotFound) {
            Person* toUpdate = PersonModel::instance().getPersonByUid([r UTF8String]);
            if (toUpdate) {
                ABPerson* updated = [[ABAddressBook sharedAddressBook] recordForUniqueId:r];
                if(updated.imageData) {
                    QPixmap p;
                    if (p.loadFromData(QByteArray::fromNSData(updated.imageData))) {
                        toUpdate->setPhoto(QVariant(p));
                    }
                }

                toUpdate->updateFromVCard(QByteArray::fromNSData(updated.vCardRepresentation));
            } else
                editor<Person>()->addExisting(this->abPersonToPerson([[ABAddressBook sharedAddressBook] recordForUniqueId:r]));
        }
    }

    for (NSString* r in ns.userInfo[kABDeletedRecords]) {
        removePerson(r);
    }
}

AddressBookBackend::~AddressBookBackend()
{
    for (::id observer in this->observers)
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
}

void AddressBookEditor::savePerson(QTextStream& stream, const Person* Person)
{
    qDebug() << "Saving Person!";
}

bool AddressBookEditor::regenFile(const Person* toIgnore)
{
    return false;
}

bool AddressBookEditor::save(const Person* person)
{
    // first get the existing person
    ABPerson* toSave = [[ABAddressBook sharedAddressBook] recordForUniqueId:[[NSString alloc] initWithUTF8String:person->uid().data()]];

    // create its new reprresentation
    ABPerson* newVCard = [[ABPerson alloc] initWithVCardRepresentation:person->toVCard().toNSData()];

    if (toSave) {
        // i.e. *all* potential properties
        for (NSString* property in [ABPerson properties]) {
            // if the property doesn't exist in the address book, value will be nil
            id value = [newVCard valueForProperty:property];
            if (value && [property isNotEqualTo:kABUIDProperty]) {
                NSError* error;
                if (![toSave setValue:value forProperty:property error:&error] || error) {
                    NSLog(@"Error saving property %@ for person %@ : %@", property, toSave, [error localizedDescription]);
                    return false;
                }
            }
        }
    }
    return [[ABAddressBook sharedAddressBook] save];
}

bool AddressBookEditor::remove(const Person* item)
{
    mediator()->removeItem(item);
    return false;
}

bool AddressBookEditor::edit( Person* item)
{
    Q_UNUSED(item)
    return false;
}

bool AddressBookEditor::addNew( Person* item)
{
    return m_pCollection->addNewPerson(item);
}

bool AddressBookEditor::addExisting(const Person* item)
{
    m_lItems << const_cast<Person*>(item);
    if(auto existingPerson =  PersonModel::instance().getPersonByUid(item->uid())) {
        return false;
    }
    mediator()->addItem(item);
    return true;
}

QVector<Person*> AddressBookEditor::items() const
{
    return m_lItems;
}

QString AddressBookBackend::name() const
{
    return QObject::tr("AddressBook backend");
}

QString AddressBookBackend::category() const
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
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // do your background tasks here
        auto book = [ABAddressBook sharedAddressBook];
        auto everyone = [book people];
        int endPoint = qMin(startingPoint + 10, (int)everyone.count);

        for (int i = startingPoint; i < endPoint; ++i) {
            ABPerson* abPerson = ((ABPerson*)[everyone objectAtIndex:i]);
            Person* person = this->abPersonToPerson(abPerson);
            person->setCollection(this);
            editor<Person>()->addExisting(person);
        }

        if(endPoint < everyone.count) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                asyncLoad(endPoint);
            });
        }
    });
}

Person* AddressBookBackend::abPersonToPerson(ABPerson* ab)
{
    if(auto existingPerson = PersonModel::instance().getPersonByUid([[ab uniqueId] UTF8String])) {
        return existingPerson;
    }
    auto person = new Person(QByteArray::fromNSData(ab.vCardRepresentation),
                                Person::Encoding::vCard,
                                this);
    if(ab.imageData) {
        QPixmap p;
        if (p.loadFromData(QByteArray::fromNSData(ab.imageData))) {
            person->setPhoto(QVariant(p));
        }
    }

    person->setUid([[ab uniqueId] UTF8String]);
    return person;
}

bool AddressBookBackend::reload()
{
    return false;
}

bool AddressBookBackend::addNewPerson(Person *item)
{
    ABAddressBook *book = [ABAddressBook sharedAddressBook];
    ABPerson* person = [[ABPerson alloc] initWithVCardRepresentation:item->toVCard().toNSData()];
    [book addRecord:person];
    return [book save];
}

bool AddressBookBackend::removePerson(NSString* uid)
{
    auto found = PersonModel::instance().getPersonByUid([uid UTF8String]);
    if (found) {
        deactivate(found);
        editor<Person>()->remove(found);
        return true;
    }
    return false;
}

FlagPack<AddressBookBackend::SupportedFeatures> AddressBookBackend::supportedFeatures() const
{
    return (FlagPack<SupportedFeatures>) (CollectionInterface::SupportedFeatures::NONE  |
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
