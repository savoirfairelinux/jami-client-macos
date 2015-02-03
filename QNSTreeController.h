//
//  HistoryTreeController.h
//  Ring
//
//  Created by Alexandre Lision on 2015-01-28.
//
//

#import <Cocoa/Cocoa.h>
#import <qabstractitemmodel.h>

@interface QNSTreeController : NSTreeController {

QAbstractItemModel *privateQModel;
NSMutableArray* topNodes;

}

- (void*)connect;
- (id) initWithQModel:(QAbstractItemModel*) model;

@end
