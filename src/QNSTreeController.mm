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
#import "QNSTreeController.h"

#import <QDebug>

@interface Node : NSObject {
    NSMutableArray *children;
}
@end

@implementation Node
- (id) init
{
    if (self = [super init]) {
        children = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void) addChild:(Node*) child AtIndex:(NSUInteger) idx
{
    [children insertObject:child atIndex:idx];
}

- (NSMutableArray*) getChildrenArray
{
    return children;
}

@end


@implementation QNSTreeController

- (id) initWithQModel:(QAbstractItemModel*) model
{
    self = [super init];
    self->privateQModel = model;

    NSMutableArray* topNodes = [[NSMutableArray alloc] init];
    [self connect];

    [self populate:topNodes];

    return [self initWithContent:topNodes];
}

-(void) populate:(NSMutableArray*) nodes
{
    for (int i = 0 ; i < self->privateQModel->rowCount() ; ++i) {
        Node* n = [[Node alloc] init];
        //qDebug() << "POUPL TOP:"<< self->privateQModel->index(i, 0) ;
        [self populateChild:[n getChildrenArray] withParent:self->privateQModel->index(i, 0)];
        [nodes insertObject:n atIndex:i];
    }
}

- (void) populateChild:(NSMutableArray*) nodes withParent:(QModelIndex)qIdx
{
    for (int i = 0 ; i < self->privateQModel->rowCount(qIdx) ; ++i) {
        Node* n = [[Node alloc] init];
        //qDebug() << "POPUL CHILD:"<< self->privateQModel->index(i, 0, qIdx) ;
        [self populateChild:[n getChildrenArray] withParent:self->privateQModel->index(i, 0, qIdx)];
        [nodes insertObject:n atIndex:i];
    }
}

- (BOOL)isEditable
{
    return self->privateQModel->flags(self->privateQModel->index(0, 0)) | Qt::ItemIsEditable;
}

- (QModelIndex) indexPathtoQIdx:(NSIndexPath*) path
{
    NSUInteger myArray[[path length]];
    [path getIndexes:myArray];
    QModelIndex toReturn;

    for (int i = 0; i < path.length; ++i) {
        toReturn = self->privateQModel->index(myArray[i], 0, toReturn);
    }

    return toReturn;
}

- (QModelIndex) toQIdx:(NSTreeNode*) node
{
    return [self indexPathtoQIdx:node.indexPath];
}

- (void) insertChildAtQIndex:(QModelIndex) qIdx
{
    Node* child = [[Node alloc] init];

    QModelIndex tmp = qIdx.parent();
    NSMutableArray* allIndexes = [NSMutableArray array];
    while (tmp.isValid()) {
        [allIndexes insertObject:@(tmp.row()) atIndex:0];
        tmp = tmp.parent();
    }
    [allIndexes insertObject:@(qIdx.row()) atIndex:allIndexes.count];

    NSUInteger indexes[allIndexes.count];
    for (int i = 0 ; i < allIndexes.count ; ++i) {
        indexes[i] = [[allIndexes objectAtIndex:i] intValue];
    }
    [self insertObject:child atArrangedObjectIndexPath:[[NSIndexPath alloc] initWithIndexes:indexes length:allIndexes.count]];
}

- (void) removeChildAtQIndex:(QModelIndex) qIdx
{
    QModelIndex tmp = qIdx.parent();
    NSMutableArray* allIndexes = [NSMutableArray array];
    while (tmp.isValid()) {
        [allIndexes insertObject:@(tmp.row()) atIndex:0];
        tmp = tmp.parent();
    }
    [allIndexes insertObject:@(qIdx.row()) atIndex:allIndexes.count];

    NSUInteger indexes[allIndexes.count];
    for (int i = 0 ; i < allIndexes.count ; ++i) {
        indexes[i] = [[allIndexes objectAtIndex:i] intValue];
    }

    [self removeObjectAtArrangedObjectIndexPath:[[NSIndexPath alloc] initWithIndexes:indexes length:allIndexes.count]];
}

- (void)connect
{
    QObject::connect(self->privateQModel,
                     &QAbstractItemModel::rowsInserted,
                     [=](const QModelIndex & parent, int first, int last) {
                         for( int row = first; row <= last; ++row) {
                             //qDebug() << "INSERTING:"<< self->privateQModel->index(row, 0, parent) ;
                             if(parent.isValid() && self->privateQModel->index(row, 0, parent).isValid()) {
                                 //insert leaf
                                 [self insertChildAtQIndex:self->privateQModel->index(row, 0, parent)];
                             } else if (self->privateQModel->index(row, 0, parent).isValid()){
                                 Node* n = [[Node alloc] init];
                                 [self insertObject:n atArrangedObjectIndexPath:[[NSIndexPath alloc] initWithIndex:row]];
                             }
                         }
                     });

    QObject::connect(self->privateQModel,
                     &QAbstractItemModel::rowsAboutToBeMoved,
                     [=](const QModelIndex & sourceParent, int sourceStart, int sourceEnd, const QModelIndex & destinationParent, int destinationRow) {
                        NSLog(@"rows about to be moved, start: %d, end: %d, moved to: %d", sourceStart, sourceEnd, destinationRow);
                        /* first remove the row from old location
                          * then insert them at the new location on the "rowsMoved signal */
                         for( int row = sourceStart; row <= sourceEnd; row++) {
                             //TODO
                         }
                     });

    QObject::connect(self->privateQModel,
                     &QAbstractItemModel::rowsMoved,
                     [self](const QModelIndex & sourceParent, int sourceStart, int sourceEnd, const QModelIndex & destinationParent, int destinationRow) {
                         //NSLog(@"rows moved, start: %d, end: %d, moved to: %d", sourceStart, sourceEnd, destinationRow);
                         /* these rows should have been removed in the "rowsAboutToBeMoved" handler
                          * now insert them in the new location */
                         for( int row = sourceStart; row <= sourceEnd; row++) {

                         }
                         [self rearrangeObjects];
                     });

    QObject::connect(self->privateQModel,
                     &QAbstractItemModel::rowsAboutToBeRemoved,
                     [self](const QModelIndex & parent, int first, int last) {
                         for( int row = first; row <= last; row++) {

                         }
                     });

    QObject::connect(self->privateQModel,
                     &QAbstractItemModel::rowsRemoved,
                     [self](const QModelIndex& parent, int first, int last) {
                         //NSLog(@"rows removed");
                         //NSLog(@"first: %d", first);
                         //NSLog(@"last: %d", last);
                         for( int row = first; row <= last; row++) {
                             //qDebug() << "REMOVING:"<< self->privateQModel->index(row, 0, parent) ;
                             if (!self->privateQModel->index(row, 0, parent).isValid())
                                 continue;

                             if(parent.isValid()) {
                                 //Removing leaf
                                 [self removeChildAtQIndex:self->privateQModel->index(row, 0, parent)];
                             } else {
                                 [self removeObjectAtArrangedObjectIndexPath:[[NSIndexPath alloc] initWithIndex:row]];
                             }
                         }
                     });

    QObject::connect(self->privateQModel,
                     &QAbstractItemModel::layoutChanged,
                     [self]() {
                         NSLog(@"layout changed");
                         [self rearrangeObjects];
                     });

    QObject::connect(self->privateQModel,
                     &QAbstractItemModel::dataChanged,
                     [self](const QModelIndex &topLeft, const QModelIndex &bottomRight) {
                         for(int row = topLeft.row() ; row <= bottomRight.row() ; ++row)
                         {
                             QModelIndex tmpIdx = self->privateQModel->index(row, 0);
                             if(tmpIdx.row() >= [self.arrangedObjects count]) {
                                 Node* n = [[Node alloc] init];
                                 if(tmpIdx.isValid())
                                     [self insertObject:n atArrangedObjectIndexPath:[[NSIndexPath alloc] initWithIndex:row]];
                             }
                         }
                         [self rearrangeObjects];
                     });
}

@end
