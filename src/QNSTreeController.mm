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

- (NSMutableArray*) children
{
    return children;
}

@end


@implementation QNSTreeController

- (id) initWithQModel:(QAbstractItemModel*) model
{
    self = [super init];
    self->privateQModel = model;

    NSMutableArray* nodes = [[NSMutableArray alloc] init];
    [self populate:nodes];

    [self connect];
    return [self initWithContent:nodes];
}

-(void) populate:(NSMutableArray*) nodes
{
    for (int i = 0 ; i < self->privateQModel->rowCount() ; ++i) {
        Node* n = [[Node alloc] init];
        //qDebug() << "POUPL TOP:"<< self->privateQModel->index(i, 0) ;
        [self populateChild:[n children] withParent:self->privateQModel->index(i, 0)];
        [nodes insertObject:n atIndex:i];
    }
}

- (void) populateChild:(NSMutableArray*) nodes withParent:(QModelIndex)qIdx
{
    if (!qIdx.isValid())
        return;
    for (int i = 0 ; i < self->privateQModel->rowCount(qIdx) ; ++i) {
        Node* n = [[Node alloc] init];
        [self populateChild:[n children] withParent:self->privateQModel->index(i, 0, qIdx)];
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

- (NSIndexPath*) qIdxToNSIndexPath:(QModelIndex) qIdx
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
    return [[NSIndexPath alloc] initWithIndexes:indexes length:allIndexes.count];
}

- (void) insertNodeAtQIndex:(QModelIndex) qIdx
{
    NSIndexPath* path = [self qIdxToNSIndexPath:qIdx];
    //qDebug() << "insertNodeAt" << qIdx;
    //NSLog(@"insertNodeAt index: %@", path);
    if (path.length == 1 && [path indexAtPosition:0] <= [[self arrangedObjects] count])
        [self insertObject:[[Node alloc] init] atArrangedObjectIndexPath:path];
    else if (path.length > 1)
        [self insertObject:[[Node alloc] init] atArrangedObjectIndexPath:path];
}

- (void) removeNodeAtQIndex:(QModelIndex) qIdx
{
    NSIndexPath* path = [self qIdxToNSIndexPath:qIdx];
    if ([self.arrangedObjects descendantNodeAtIndexPath:path]) {
        //NSLog(@"removeNodeAt index: %@", path);
        [self removeObjectAtArrangedObjectIndexPath:path];
    }
}

- (void) setSelectionQModelIndex:(QModelIndex) qIdx
{
    NSIndexPath* path = [self qIdxToNSIndexPath:qIdx];
    [self setSelectionIndexPath:path];
}

- (void)connect
{
    QObject::connect(self->privateQModel,
                     &QAbstractItemModel::rowsInserted,
                     [=](const QModelIndex & parent, int first, int last) {
                         for( int row = first; row <= last; ++row) {
                             //qDebug() << "INSERTING:"<< self->privateQModel->index(row, 0, parent) ;
                             if(!self->privateQModel->index(row, 0, parent).isValid())
                                 continue;

                             [self insertNodeAtQIndex:self->privateQModel->index(row, 0, parent)];
                         }
                     });

    QObject::connect(self->privateQModel,
                     &QAbstractItemModel::rowsAboutToBeMoved,
                     [=](const QModelIndex & sourceParent, int sourceStart, int sourceEnd, const QModelIndex & destinationParent, int destinationRow) {
                        //NSLog(@"rows about to be moved, start: %d, end: %d, moved to: %d", sourceStart, sourceEnd, destinationRow);
                        /* first remove the row from old location
                          * then insert them at the new location on the "rowsMoved signal */
                         for( int row = sourceStart; row <= sourceEnd; row++) {
                             //TODO
                         }
                     });

    QObject::connect(self->privateQModel,
                     &QAbstractItemModel::rowsMoved,
                     [self](const QModelIndex & sourceParent, int sourceStart, int sourceEnd, const QModelIndex & destinationParent, int destinationRow) {
                         for( int row = sourceStart; row <= sourceEnd; row++) {
                             NSIndexPath* srcPath = [self qIdxToNSIndexPath:self->privateQModel->index(row, 0, sourceParent)];
                             NSIndexPath* destPath = [self qIdxToNSIndexPath:self->privateQModel->index(destinationRow, 0, destinationParent)];

                             [self moveNode:[self.arrangedObjects descendantNodeAtIndexPath:srcPath] toIndexPath:destPath];
                         }
                     });

    QObject::connect(self->privateQModel,
                     &QAbstractItemModel::rowsAboutToBeRemoved,
                     [self](const QModelIndex & parent, int first, int last) {
                         for( int row = last; row >= first; --row) {
                             //qDebug() << "REMOVING:"<< self->privateQModel->index(row, 0, parent) ;
                             if (!self->privateQModel->index(row, 0, parent).isValid())
                                 continue;

                             [self removeNodeAtQIndex:self->privateQModel->index(row, 0, parent)];
                         }
                     });

    QObject::connect(self->privateQModel,
                     &QAbstractItemModel::rowsRemoved,
                     [self](const QModelIndex& parent, int first, int last) {

                     });

    QObject::connect(self->privateQModel,
                     &QAbstractItemModel::layoutChanged,
                     [self]() {
                         //NSLog(@"layout changed");
                         [self rearrangeObjects];
                     });

    /* No way to 'update' a row, only insert/remove/move
    QObject::connect(self->privateQModel,
                     &QAbstractItemModel::dataChanged,
                     [self](const QModelIndex &topLeft, const QModelIndex &bottomRight) {
                     });
    */
}

@end
