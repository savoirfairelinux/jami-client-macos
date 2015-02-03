//
//  RingWindowController.m
//  Ring
//
//  Created by Alexandre Lision on 2015-01-27.
//
//

#import "RingWindowController.h"

#import <historymodel.h>
#import <accountmodel.h>
#import <callmodel.h>
#import <account.h>
#include <call.h>

@interface RingWindowController ()


@end

@implementation RingWindowController
@synthesize callUriTextField;

- (void)windowDidLoad {
    [super windowDidLoad];
    
    Account* acc = AccountModel::instance()->currentAccount();
    
    NSLog(@"Current account is:%@", acc->alias().toNSString());
    
    [self connectSlots];
    
        
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    
}


- (void) connectSlots
{
    CallModel* callModel_ = CallModel::instance();
    QObject::connect(callModel_, &CallModel::callStateChanged, [](Call*, Call::State) {
        NSLog(@"callStateChanged");
    });
    
    QObject::connect(callModel_, &CallModel::incomingCall, [] (Call*) {
        NSLog(@"incomingCall");
    });
    
}

- (IBAction)placeCall:(NSButton *)sender {
    Call* mainCall_ = CallModel::instance()->dialingCall();
    mainCall_->setDialNumber(QString::fromNSString([self.callUriTextField stringValue]));
    mainCall_->performAction(Call::Action::ACCEPT);
}
@end
