//
//  AccGeneralVC.h
//  Ring
//
//  Created by Alexandre Lision on 2015-02-25.
//
//

#import <Cocoa/Cocoa.h>

@interface AccGeneralVC : NSViewController {
    NSTextField *aliasTextField;
    NSTextField *serverHostTextField;
    NSTextField *usernameTextField;
    NSSecureTextField *passwordTextField;
}

@property (assign) IBOutlet NSTextField *aliasTextField;
@property (assign) IBOutlet NSTextField *serverHostTextField;
@property (assign) IBOutlet NSTextField *usernameTextField;
@property (assign) IBOutlet NSSecureTextField *passwordTextField;
- (IBAction)testButton:(id)sender;

@property (assign) NSString* alias;

@end
