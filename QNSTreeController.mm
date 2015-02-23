/************************************************************************************
 *   Copyright (C) 2014-2015 by Savoir-Faire Linux                                  *
 *   Author : Alexandre Lision <alexandre.lision@savoirfairelinux.com>              *
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
    [super init];
    NSLog(@"init Tree...");
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
    if(idx.length == 2)
        toReturn = self->privateQModel->index(myArray[1], 0, self->privateQModel->index(myArray[0], 0));
    else
        toReturn = self->privateQModel->index(myArray[0], 0);
    return toReturn;
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
                                 Node* child = [[Node alloc] init];
                                 NSUInteger indexes[] = { (NSUInteger)parent.row(), (NSUInteger)row};
                                 [self insertObject:child atArrangedObjectIndexPath:[[NSIndexPath alloc] initWithIndexes:indexes length:2]];
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
                     &QAbstractItemModel::rowsAboutToBeRemoved,
                     [=](const QModelIndex & parent, int first, int last) {
                         NSLog(@"rows about to be removed");
//                         for( int row = first; row <= last; row++) {
//                             if(topNodes.count <= parent.row())
//                             {
//                                 NSUInteger indexes[] = { (NSUInteger)parent.row(), (NSUInteger)row};
//                                 [self removeObjectAtArrangedObjectIndexPath:[[NSIndexPath alloc] initWithIndexes:indexes length:2]];
//                             } else {
//                                 NSLog(@"Removing rows not in tree!");
//                             }
//                         }
                     }
                     );

    QObject::connect(self->privateQModel,
                     &QAbstractItemModel::rowsRemoved,
                     [=](const QModelIndex & parent, int first, int last) {
                         NSLog(@"rows removed");
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
                         NSLog(@"layout changed");
                     }
                     );

    QObject::connect(self->privateQModel,
                     &QAbstractItemModel::dataChanged,
                     [=](const QModelIndex &topLeft, const QModelIndex &bottomRight) {
                         NSLog(@"data changed");
                         for(int row = topLeft.row() ; row <= bottomRight.row() ; ++row)
                         {
                             Node* n = [[Node alloc] init];
                             [self setSelectsInsertedObjects:YES];
                             [self removeObjectAtArrangedObjectIndexPath:[[NSIndexPath alloc] initWithIndex:row]];
                             [self insertObject:n atArrangedObjectIndexPath:[[NSIndexPath alloc] initWithIndex:row]];

//                             [self moveNode:node toIndexPath:node.indexPath];
                             //[self didChange:NSKeyValueChangeReplacement valuesAtIndexes:[[NSIndexSet alloc] initWithIndex:row] forKey:@"children"];
                         }
                     }
                     );

}

@end
