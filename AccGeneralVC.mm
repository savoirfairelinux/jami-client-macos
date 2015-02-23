//
//  AccGeneralVC.m
//  Ring
//
//  Created by Alexandre Lision on 2015-02-25.
//
//

#import "AccGeneralVC.h"

@interface AccGeneralVC ()

@end

@implementation AccGeneralVC
@synthesize aliasTextField;
@synthesize serverHostTextField;
@synthesize usernameTextField;
@synthesize passwordTextField;

- (void)loadView
{
    self.alias = @"lol";
    [super loadView];

    [self.aliasTextField bind:@"value" toObject:self withKeyPath:@"alias" options:nil];



    
}


- (IBAction)testButton:(id)sender {
    NSLog(@"TEST: %@", self.alias);
}
@end
