//
//  AddSIPAccountVC.m
//  Ring
//
//  Created by Kateryna Kostiuk on 2018-07-26.
//

#import "AddSIPAccountVC.h"

@interface AddSIPAccountVC ()

@end

@implementation AddSIPAccountVC

@synthesize accountModel;

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setAutoresizingMask: NSViewHeightSizable];
}

-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil accountmodel:(lrc::api::NewAccountModel*) accountModel {
    if (self =  [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.accountModel = accountModel;
    }
    return self;
}

-(void) show {
    
}

- (IBAction)cancel:(id)sender
{
    [self.delegate done];
}

- (IBAction)done:(id)sender
{
//    accountModel->createNewAccount(lrc::api::profile::Type::SIP, [displayNameField.stringValue UTF8String],"",[passwordField.stringValue UTF8String]);
}

@end
