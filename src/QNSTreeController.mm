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

- (void) addChild:(Node*) child
{
    [children addObject:child];
}

@end


@implementation QNSTreeController

- (id) initWithQModel:(QAbstractItemModel*) model
{
    self = [super init];
    self->privateQModel = model;

    topNodes = [[NSMutableArray alloc] init];
    [self connect];

    [self populate];

    return [self initWithContent:topNodes];
}

-(void) populate
{
    for (int i =0 ; i < self->privateQModel->rowCount() ; ++i){
        [topNodes insertObject:[[Node alloc] init] atIndex:i];
    }
}

- (BOOL)isEditable
{
    return self->privateQModel->flags(self->privateQModel->index(0, 0)) | Qt::ItemIsEditable;
}

- (QModelIndex) toQIdx:(NSTreeNode*) node
{
    NSIndexPath* idx = node.indexPath;
    NSUInteger myArray[[idx length]];
    [idx getIndexes:myArray];
    QModelIndex toReturn;

    for (int i = 0; i < idx.length; ++i) {
        toReturn = self->privateQModel->index(myArray[i], 0, toReturn);
    }

    return toReturn;
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

- (void)connect
{
    QObject::connect(self->privateQModel,
                     &QAbstractItemModel::rowsInserted,
                     [=](const QModelIndex & parent, int first, int last) {
                         for( int row = first; row <= last; row++) {
                             if(!parent.isValid()) {
                                 //Inserting topnode
                                 Node* n = [[Node alloc] init];
                                 [self insertObject:n atArrangedObjectIndexPath:[[NSIndexPath alloc] initWithIndex:row]];
                             } else {
                                 [self insertChildAtQIndex:self->privateQModel->index(row, 0, parent)];
                             }
                         }
                     }
                     );

    QObject::connect(self->privateQModel,
                     &QAbstractItemModel::rowsAboutToBeMoved,
                     [=](const QModelIndex & sourceParent, int sourceStart, int sourceEnd, const QModelIndex & destinationParent, int destinationRow) {
                        NSLog(@"rows about to be moved, start: %d, end: %d, moved to: %d", sourceStart, sourceEnd, destinationRow);
                        /* first remove the row from old location
                          * then insert them at the new location on the "rowsMoved signal */
                         for( int row = sourceStart; row <= sourceEnd; row++) {
                             //TODO
                         }
                     }
                     );

    QObject::connect(self->privateQModel,
                     &QAbstractItemModel::rowsMoved,
                     [=](const QModelIndex & sourceParent, int sourceStart, int sourceEnd, const QModelIndex & destinationParent, int destinationRow) {
                         //NSLog(@"rows moved, start: %d, end: %d, moved to: %d", sourceStart, sourceEnd, destinationRow);
                         /* these rows should have been removed in the "rowsAboutToBeMoved" handler
                          * now insert them in the new location */
                         for( int row = sourceStart; row <= sourceEnd; row++) {
                             //TODO
                         }
                     }
                     );

    QObject::connect(self->privateQModel,
                     &QAbstractItemModel::rowsAboutToBeRemoved,
                     [=](const QModelIndex & parent, int first, int last) {
                         NSLog(@"rows about to be removed");
                     }
                     );

    QObject::connect(self->privateQModel,
                     &QAbstractItemModel::rowsRemoved,
                     [=](const QModelIndex & parent, int first, int last) {
                         //NSLog(@"rows removed");
                         for( int row = first; row <= last; row++) {
                             if(parent.isValid())
                             {
                                 //Removing leaf
                                 NSUInteger indexes[] = { (NSUInteger)parent.row(), (NSUInteger)row};
                                 [self removeObjectAtArrangedObjectIndexPath:[[NSIndexPath alloc] initWithIndexes:indexes length:2]];
                             } else
                             {
                                 [self removeObjectAtArrangedObjectIndexPath:[[NSIndexPath alloc] initWithIndex:row]];
                             }
                         }
                     }
                     );

    QObject::connect(self->privateQModel,
                     &QAbstractItemModel::layoutChanged,
                     [=]() {
                         //NSLog(@"layout changed");
                     }
                     );

    QObject::connect(self->privateQModel,
                     &QAbstractItemModel::dataChanged,
                     [=](const QModelIndex &topLeft, const QModelIndex &bottomRight) {
                         //NSLog(@"data changed");
                         for(int row = topLeft.row() ; row <= bottomRight.row() ; ++row)
                         {
                             QModelIndex tmpIdx = self->privateQModel->index(row, 0);
                             if(tmpIdx.row() >= [self.arrangedObjects count]) {
                                 Node* n = [[Node alloc] init];
                                 if(tmpIdx.isValid())
                                     [self insertObject:n atArrangedObjectIndexPath:[[NSIndexPath alloc] initWithIndex:row]];
                             }
                         }
                     });
}

@end
