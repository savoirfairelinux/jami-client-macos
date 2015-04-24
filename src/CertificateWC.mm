//
//  CertificateWC.m
//  Ring
//
//  Created by Alexandre Lision on 2015-04-28.
//
//

#import "CertificateWC.h"

@implementation CertificateWC

- (void)windowDidLoad {
    [super windowDidLoad];
}

- (void) setCertificate:(Certificate*) cert
{
    NSLog(@"CertificateWC loaded");
}

- (IBAction)closePanel:(id)sender
{
    [NSApp endSheet:self.window];
    [self.window orderOut:self];
}


@end
