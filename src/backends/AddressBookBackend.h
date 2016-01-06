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

#include <collectioninterface.h>
#include <collectioneditor.h>

class Person;
@class ABPerson;
@class NSMutableArray;
@class NSNotification;

template<typename T> class CollectionMediator;

class AddressBookBackend : public CollectionInterface
{
public:
    explicit AddressBookBackend(CollectionMediator<Person>* mediator);
    virtual ~AddressBookBackend();

    virtual bool load() override;
    virtual bool reload() override;
    virtual bool clear() override;
    virtual QString    name     () const override;
    virtual QString    category () const override;
    virtual QVariant   icon     () const override;
    virtual bool       isEnabled() const override;
    virtual QByteArray id       () const override;
    virtual FlagPack<SupportedFeatures>  supportedFeatures() const override;

    bool addNewPerson(Person *item);
    bool removePerson(NSString* uid);

private:
    CollectionMediator<Person>*  m_pMediator;
    NSMutableArray* observers;

    void handleNotification(NSNotification* ns);
    Person* abPersonToPerson(ABPerson* ab);

    void asyncLoad(int startingPoint);
};